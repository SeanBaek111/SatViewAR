import CoreML
import CoreVideo
import Foundation
import Vision

/// Core ML 하늘 분할 모델 래퍼.
///
/// 이전에 쓰던 TensorFlow Lite DeepLabV3(ADE20K 150클래스)를 대체한다.
/// 우리가 필요한 것은 클래스 하나뿐이라 이진 분할 전용 모델이 훨씬 작고 빠르다.
///   - 모델 크기: 47.3MB(2종) → 6.5MB
///   - 추론 경로: UIImage 왕복 + CPU → CVPixelBuffer 직결 + Neural Engine
///   - 실측: 3fps 이하 → 30fps
final class SkySegmenter {

    struct Output {
        let mask: MLMultiArray
        let inferenceMilliseconds: Double
    }

    enum SegmenterError: Error {
        case modelNotFound(String)
        case unexpectedOutput
    }

    static let defaultModelName = "SkySeg_large_256_trained"

    private let visionModel: VNCoreMLModel

    init(modelName: String = SkySegmenter.defaultModelName) throws {
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            throw SegmenterError.modelNotFound(modelName)
        }

        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all

        let model = try MLModel(contentsOf: url, configuration: configuration)
        self.visionModel = try VNCoreMLModel(for: model)
    }

    /// ARFrame 의 카메라 버퍼를 그대로 받는다.
    ///
    /// 예전 경로는 arView.snapshot() 으로 렌더된 화면을 찍었기 때문에
    /// 위성 노드가 같이 찍히는 문제가 있었고, 그래서 캡처 직전에 노드를 숨겼다 되돌리는
    /// 우회책이 필요했다. 원본 카메라 버퍼를 쓰면 그 문제 자체가 사라진다.
    func segment(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) throws -> Output {
        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)

        let started = CFAbsoluteTimeGetCurrent()
        try handler.perform([request])
        let elapsed = (CFAbsoluteTimeGetCurrent() - started) * 1000.0

        guard
            let observation = request.results?.first as? VNCoreMLFeatureValueObservation,
            let mask = observation.featureValue.multiArrayValue
        else {
            throw SegmenterError.unexpectedOutput
        }

        return Output(mask: mask, inferenceMilliseconds: elapsed)
    }
}
