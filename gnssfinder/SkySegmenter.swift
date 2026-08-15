import CoreML
import CoreVideo
import Foundation
import Vision

/// Wrapper around the Core ML sky segmentation model.
///
/// Replaces the TensorFlow Lite DeepLabV3 segmenter (ADE20K, 150 classes) that was used
/// before. Only one of those classes was ever read, and a model trained for that single
/// binary question is both smaller and far faster.
///   - Model size: 47.3 MB across two files, down to 6.5 MB
///   - Inference path: UIImage round trip on the CPU, replaced by a CVPixelBuffer handed
///     straight to the Neural Engine
///   - Measured: under 3 fps, up to 30 fps
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

    /// Segments a camera buffer taken straight from an `ARFrame`.
    ///
    /// The previous path captured the rendered AR view with `arView.snapshot()`, which meant
    /// the satellite markers were part of the image being segmented. Hiding every node before
    /// the capture and restoring it afterwards worked around that. Reading the raw camera
    /// buffer removes the problem instead of working around it.
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
