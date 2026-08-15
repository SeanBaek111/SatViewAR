import ARKit
import CoreML
import UIKit

/// 모델 출력을 기존 파이프라인이 기대하는 형태의 UIImage 로 바꾼다.
///
/// DataManager 는 위성의 화면 좌표에서 결과 이미지의 빨강 채널을 읽어 LOS 를 판정한다.
/// 그 규약(하늘이면 빨강이 낮고, 막혔으면 높다)을 그대로 지키면
/// DataManager 와 isLOS 는 한 줄도 고칠 필요가 없다.
enum SkyMaskRenderer {

    /// 예전 parseOutputBinary 가 쓰던 색을 그대로 유지한다.
    /// isLOS 의 임계값(빨강 > 100 이면 막힘)이 이 값들에 의존한다.
    private static let skyPixel: UInt32 = 0xFF_E6_E6_06      // ABGR little endian, R=6
    private static let blockedPixel: UInt32 = 0xFF_DC_F5_F5  // R=245

    /// 마스크를 화면 좌표계의 이미지로 만든다.
    ///
    /// 카메라 버퍼와 화면은 좌표계가 다르다. ARSCNView 는 카메라 영상을 aspect-fill 로
    /// 잘라서 보여주므로 가장자리가 화면 밖으로 나간다. 예전에는 렌더된 화면을 스크린샷으로
    /// 찍었기 때문에 이 차이가 없었다. 이제 원본 버퍼를 쓰므로 ARKit 의 displayTransform 으로
    /// 정확히 맞춰 준다. 이걸 빼먹으면 위성 판정이 화면 가장자리에서 어긋난다.
    /// - Parameter viewportSize: 화면 크기(포인트). displayTransform 이 포인트 기준을 쓴다.
    /// - Parameter scale: 화면 배율. 결과 이미지는 픽셀 해상도로 만든다.
    ///   DataManager 가 넘기는 위성 좌표가 포인트에 배율을 곱한 픽셀 값이라 여기에 맞춰야 한다.
    ///   예전 경로는 결과를 포인트 크기로 만들어서 화면 대부분의 위성이 범위 밖으로 빠졌다.
    static func viewSpaceImage(
        mask: MLMultiArray,
        frame: ARFrame,
        viewportSize: CGSize,
        scale: CGFloat,
        orientation: UIInterfaceOrientation,
        threshold: Double = 0.5
    ) -> UIImage? {
        let shape = mask.shape.map { $0.intValue }
        guard shape.count >= 2 else {
            return nil
        }

        let maskHeight = shape[shape.count - 2]
        let maskWidth = shape[shape.count - 1]
        guard maskWidth > 0, maskHeight > 0 else {
            return nil
        }

        guard let sky = skyFlags(mask: mask, count: maskWidth * maskHeight, threshold: threshold) else {
            return nil
        }

        let width = Int(viewportSize.width * scale)
        let height = Int(viewportSize.height * scale)
        guard width > 0, height > 0 else {
            return nil
        }

        // 화면 좌표를 정규화한 뒤 카메라 이미지 좌표로 되돌리는 변환.
        let displayTransform = frame.displayTransform(
            for: orientation, viewportSize: viewportSize
        ).inverted()

        var pixels = [UInt32](repeating: blockedPixel, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let normalized = CGPoint(
                    x: CGFloat(x) / CGFloat(width),
                    y: CGFloat(y) / CGFloat(height)
                )
                let inImage = normalized.applying(displayTransform)

                // 화면에 보이는 영역이 카메라 이미지 밖으로 나가는 경우는 막힌 것으로 둔다.
                guard inImage.x >= 0, inImage.x < 1, inImage.y >= 0, inImage.y < 1 else {
                    continue
                }

                let maskX = min(Int(inImage.x * CGFloat(maskWidth)), maskWidth - 1)
                let maskY = min(Int(inImage.y * CGFloat(maskHeight)), maskHeight - 1)

                if sky[maskY * maskWidth + maskX] {
                    pixels[y * width + x] = skyPixel
                }
            }
        }

        return makeImage(pixels: pixels, width: width, height: height)
    }

    // MARK: - 보조

    private static func skyFlags(mask: MLMultiArray, count: Int, threshold: Double) -> [Bool]? {
        guard mask.count >= count else {
            return nil
        }

        var flags = [Bool](repeating: false, count: count)

        switch mask.dataType {
        case .float16:
            let pointer = mask.dataPointer.bindMemory(to: UInt16.self, capacity: count)
            for index in 0..<count {
                flags[index] = Double(Float(Float16(bitPattern: pointer[index]))) > threshold
            }
        case .float32:
            let pointer = mask.dataPointer.bindMemory(to: Float.self, capacity: count)
            for index in 0..<count {
                flags[index] = Double(pointer[index]) > threshold
            }
        case .double:
            let pointer = mask.dataPointer.bindMemory(to: Double.self, capacity: count)
            for index in 0..<count {
                flags[index] = pointer[index] > threshold
            }
        default:
            return nil
        }

        return flags
    }

    private static func makeImage(pixels: [UInt32], width: Int, height: Int) -> UIImage? {
        var buffer = pixels
        let bytesPerRow = width * MemoryLayout<UInt32>.size

        return buffer.withUnsafeMutableBytes { raw -> UIImage? in
            guard
                let base = raw.baseAddress,
                let context = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                        | CGBitmapInfo.byteOrder32Little.rawValue
                ),
                let cgImage = context.makeImage()
            else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        }
    }
}
