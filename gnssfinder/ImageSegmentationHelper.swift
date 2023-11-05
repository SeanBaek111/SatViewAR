// Copyright 2022 The TensorFlow Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// Copyright 2022 The TensorFlow Authors. All Rights Reserved.
import TensorFlowLiteTaskVision
import UIKit

// MARK: - Image Segmentation Helper Class
class ImageSegmentationHelper {

    // MARK: - Private Properties
    private var segmenter: ImageSegmenter
    private let tfLiteQueue: DispatchQueue

    // MARK: - Initializers
    init(tfLiteQueue: DispatchQueue, segmenter: ImageSegmenter) {
        self.segmenter = segmenter
        self.tfLiteQueue = tfLiteQueue
    }

    // MARK: - Public Methods
    static func newInstance(completionHandler: @escaping ((Result<ImageSegmentationHelper, InitializationError>) -> Void)) {
        // Create a dispatch queue to ensure all operations on the TFLite `ImageSegmenter` will run serially.
        let tfLiteQueue = DispatchQueue(label: "org.tensorflow.examples.lite.image_segmentation")

        // Run initialization in background thread to avoid UI freeze.
        tfLiteQueue.async {
            guard let modelPath = Bundle.main.path(forResource: Constants.modelFileName, ofType: Constants.modelFileExtension) else {
                print("Failed to load the model file with name: \(Constants.modelFileName).\(Constants.modelFileExtension)")
                DispatchQueue.main.async {
                    completionHandler(.failure(.invalidModel("\(Constants.modelFileName).\(Constants.modelFileExtension)")))
                }
                return
            }

            let options = ImageSegmenterOptions(modelPath: modelPath)
            do {
                let segmenter = try ImageSegmenter.segmenter(options: options)
                let segmentationHelper = ImageSegmentationHelper(tfLiteQueue: tfLiteQueue, segmenter: segmenter)
                DispatchQueue.main.async {
                    completionHandler(.success(segmentationHelper))
                }
            } catch let error {
                print("Failed to create the interpreter with error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completionHandler(.failure(.internalError(error)))
                }
            }
        }
    }
  // MARK: - Image Segmentation

  /// Run segmentation on a given image.
  ///
  /// - Parameters:
  ///   - image: the target image.
  ///   - completion: the callback to receive segmentation result.
  func runSegmentation(
    _ image: UIImage,
    completion: @escaping ((Result<ImageSegmentationResult, SegmentationError>) -> Void)
  ) {
    tfLiteQueue.async {
      [weak self] in
      guard let strongSelf = self else {
        print("The app is in an invalid state.")
        DispatchQueue.main.async {
          completion(.failure(SegmentationError.invalidState))
        }
        return
      }
      let segmentationResult: SegmentationResult
      var inferenceTime: TimeInterval = 0
      var postprocessingTime: TimeInterval = 0

      do {
        // Preprocessing: Convert the input UIImage to MLImage.
        let startTime = Date()
        guard let mlImage = MLImage(image: image) else {
          print("The input image is invalid.")
          DispatchQueue.main.async {
            completion(.failure(SegmentationError.invalidImage))
          }
          return
        }

        // Run segmentation
        segmentationResult = try strongSelf.segmenter.segment(mlImage: mlImage)

        // Calculate segmentation time.
        inferenceTime = Date().timeIntervalSince(startTime)
      } catch let error {
        print("Failed to invoke TFLite with error: \(error.localizedDescription)")
        DispatchQueue.main.async {
          completion(.failure(SegmentationError.internalError(error)))
        }
        return
      }

      /// Postprocessing: Visualize the `SegmentationResult` object.
      let startTime = Date()

      guard
        let (resultImage, colorLegend) = strongSelf.parseOutputBinary(
          segmentationResult: segmentationResult)
      else {
        print("Failed to parse model output.")
        DispatchQueue.main.async {
          completion(.failure(SegmentationError.postProcessingError))
        }
        return
      }
      // Calculate postprocessing time.
      // Note: You may find postprocessing slow when running the sample app with the Debug build.
      // You will see significant speed up if you switch to using Release build, or change
      // Optimization Level in the project's Build Settings to the same value as the Release build.
      postprocessingTime = Date().timeIntervalSince(startTime)

      // Create a representative object that contains the segmentation result.
      let result = ImageSegmentationResult(
        resultImage: resultImage,
        colorLegend: colorLegend,
        inferenceTime: inferenceTime,
        postProcessingTime: postprocessingTime
      )

      // Return the segmentation result.
      DispatchQueue.main.async {
        completion(.success(result))
      }
    }
  }

  // MARK: - Image Segmentation Parse

  /// Run segmentation map and color for each pixel, if can't get `categoryMask` -> return nil.
  /// - Parameter segmentationResult: The result received from image segmentation process
  private func parseOutput(segmentationResult: SegmentationResult) -> (UIImage, [String: UIColor])?
  {
    guard let segmentation = segmentationResult.segmentations.first,
      let categoryMask = segmentation.categoryMask
    else { return nil }
    let mask = categoryMask.mask
    let results = [UInt8](
      UnsafeMutableBufferPointer(
        start: mask,
        count: categoryMask.width * categoryMask.height))

    // Create a visualization of the segmentation image.
    let alphaChannel: UInt32 = 255
    let classColorsUInt32: [UInt32] = segmentation.coloredLabels.map({
      let colorAsUInt32 =
        alphaChannel << 24  // alpha channel
        + UInt32($0.r) << 16 + UInt32($0.g) << 8 + UInt32($0.b)
      return colorAsUInt32
    })
    let segmentationImagePixels: [UInt32] = results.map({ classColorsUInt32[Int($0)] })
    guard
      let resultImage = UIImage.fromSRGBColorArray(
        pixels: segmentationImagePixels,
        size: CGSize(width: categoryMask.width, height: categoryMask.height)
      )
    else { return nil }

    // Calculate the list of classes found in the image and its visualization color.
    let classFoundInImageList = IndexSet(Set(results).map({ Int($0) }))
    let filteredColorLabels = classFoundInImageList.map({ segmentation.coloredLabels[$0] })
    let colorLegend = [String: UIColor](
      uniqueKeysWithValues: filteredColorLabels.map { colorLabel in
        let color = UIColor(
          red: CGFloat(colorLabel.r) / 255.0,
          green: CGFloat(colorLabel.g) / 255.0,
          blue: CGFloat(colorLabel.b) / 255.0,
          alpha: CGFloat(alphaChannel) / 255.0)
        return (colorLabel.label, color)
      })

    return (resultImage, colorLegend)
  }
    
    private func parseOutputBinary(segmentationResult: SegmentationResult) -> (UIImage, [String: UIColor])? {
        guard let segmentation = segmentationResult.segmentations.first,
              let categoryMask = segmentation.categoryMask
        else { return nil }
        let mask = categoryMask.mask
        let results = [UInt8](
            UnsafeMutableBufferPointer(
                start: mask,
                count: categoryMask.width * categoryMask.height))

        // Create a visualization of the segmentation image.
        let alphaChannel: UInt32 = 255
        let targetColor: UInt32 =
            alphaChannel << 24 +
            UInt32(6) << 16 +
            UInt32(230) << 8 +
            UInt32(230)
        
        let otherColor: UInt32 =
            alphaChannel << 24 + // alpha channel
            UInt32(245) << 16 + // You can adjust this to a less prominent red color
            UInt32(245) << 8 +  // Adjust this for green
            UInt32(220)         // Adjust this for blue

        let segmentationImagePixels: [UInt32] = results.map { $0 == 3 ? targetColor : otherColor }
        guard
            let resultImage = UIImage.fromSRGBColorArray(
                pixels: segmentationImagePixels,
                size: CGSize(width: categoryMask.width, height: categoryMask.height)
            )
        else { return nil }

        // Calculate the list of classes found in the image and its visualization color.
        let targetUIColor = UIColor(red: 6/255.0, green: 230/255.0, blue: 230/255.0, alpha: 1.0)
        let otherUIColor = UIColor(red: 20/255.0, green: 20/255.0, blue: 20/255.0, alpha: 0.5)
        let colorLegend: [String: UIColor] = [
            "Target Label": targetUIColor,
            "Other Labels": otherUIColor
        ]

        return (resultImage, colorLegend)
    }

}


// MARK: - Supporting Types
struct ImageSegmentationResult {
    let resultImage: UIImage
    let colorLegend: [String: UIColor]
    let inferenceTime: TimeInterval
    let postProcessingTime: TimeInterval
}

enum InitializationError: Error {
    case invalidState
    case invalidModel(String)
    case internalError(Error)
}

enum SegmentationError: Error {
    case invalidState
    case invalidImage
    case internalError(Error)
    case postProcessingError
    case resultVisualizationError
}

private enum Constants {
    static let modelFileName = "lite-model_deeplabv3-mobilenetv2-ade20k_1_default_2"
 //  static let modelFileName = "sky_model_meta"
    static let modelFileExtension = "tflite"
}
