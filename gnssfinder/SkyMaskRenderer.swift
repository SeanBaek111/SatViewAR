import ARKit
import CoreML
import UIKit

/// Turns the model output into the image shape the rest of the pipeline already expects.
///
/// DataManager decides LOS by reading the red channel of the result image at each
/// satellite's screen position. Honouring that contract, sky means a low red value and
/// blocked means a high one, keeps DataManager and isLOS untouched.
enum SkyMaskRenderer {

    /// The same colours the old parseOutputBinary produced. The isLOS threshold, red above
    /// 100 means blocked, depends on these values.
    private static let skyPixel: UInt32 = 0xFF_E6_E6_06      // ABGR little endian, R = 6
    private static let blockedPixel: UInt32 = 0xFF_DC_F5_F5  // R = 245

    /// Renders the mask into view coordinates.
    ///
    /// The camera buffer and the screen do not share a coordinate space. ARSCNView crops the
    /// feed to aspect-fill, so parts of it fall outside the view. The old code sidestepped
    /// this by screenshotting the rendered view. Now that the raw buffer is used, ARKit's
    /// displayTransform does the mapping. Skipping it makes classification drift at the
    /// edges of the screen.
    ///
    /// - Parameter viewportSize: view size in points, which is what displayTransform expects.
    /// - Parameter scale: screen scale. The result is rendered at pixel resolution because
    ///   the satellite positions DataManager passes in are points multiplied by that scale.
    ///   The earlier code produced a point-sized image, so most satellites on screen fell
    ///   outside its bounds and were never classified.
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

        // Maps a normalised screen point back into normalised camera image space.
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

                // Anything that maps outside the camera image is treated as blocked.
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

    // MARK: - Helpers

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
