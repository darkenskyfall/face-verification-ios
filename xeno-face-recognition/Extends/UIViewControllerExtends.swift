//
//  UIViewControllerExtends.swift
//  xeno-face-recognition
//
//  Created by MacOS on 02/03/23.
//

import UIKit
import Accelerate
import Vision
import CoreImage

extension UIViewController{
    
    func estimateDistance(for observation: VNFaceObservation) -> CGFloat? {
        
        let imageHeight: CGFloat = 480
        
        // Assuming the camera has a fixed focal length
        let focalLength: CGFloat = 5.5 // in mm
        
        // Calculate the approximate real-world height of the face
        let faceHeight: CGFloat = observation.boundingBox.height * imageHeight
        
        // Calculate the distance using the formula: distance = focalLength * realHeight / imageHeight
        let distance = focalLength * faceHeight / observation.boundingBox.height
        
        print("face distance: \(distance)")
        
        return distance
    }
    
    func isTurnRight(face: VNFaceObservation)->Bool{
        if let yaw = face.yaw as? Double{
            return yaw >= 0.7
        }
        return false
    }
    
    func isTurnLeft(face: VNFaceObservation)->Bool{
        if let yaw = face.yaw as? Double{
            return yaw <= -0.7
        }
        return false
    }
    
    func isBlink(face: VNFaceObservation)->Bool{
        guard let leftEye = face.landmarks?.leftEye,
              let rightEye = face.landmarks?.rightEye else {
            return false
        }

        // calculate the aspect ratio of the eyes
        let leftEyeAspectRatio = self.calculateEyeAspectRatio(leftEye)
        let rightEyeAspectRatio = self.calculateEyeAspectRatio(rightEye)

        // check if the person has blinked
        return leftEyeAspectRatio < 0.2 && rightEyeAspectRatio < 0.2
    }
    
    func isSmile(_ imageBuffer: CVPixelBuffer)->Bool{
        
        let ciimage = CIImage(cvPixelBuffer: imageBuffer).oriented(.right)
        
        let options: [String: Any] = [
            CIDetectorAccuracy: CIDetectorAccuracyHigh,
            CIDetectorSmile: true,
            CIDetectorEyeBlink: true
        ]
        
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: options)!

        let faces = faceDetector.features(in: ciimage, options: options)
        
        for face in faces {
            if (face as! CIFaceFeature).hasSmile{
                return true
            }
        }
        return false
    }
    
    func calculateEyeAspectRatio(_ eyeLandmark: VNFaceLandmarkRegion2D) -> CGFloat {
        // calculate the horizontal and vertical distances between the eye landmarks
        let horizontalDistance = eyeLandmark.normalizedPoints[5].x - eyeLandmark.normalizedPoints[0].x
        let verticalDistance1 = eyeLandmark.normalizedPoints[1].y - eyeLandmark.normalizedPoints[4].y
        let verticalDistance2 = eyeLandmark.normalizedPoints[2].y - eyeLandmark.normalizedPoints[3].y

        // calculate the aspect ratio
        let aspectRatio = (verticalDistance1 + verticalDistance2) / (2 * horizontalDistance)

        return aspectRatio
    }
    
}

extension UIViewController{
    
    // Convert CIImage to UIImage
    func convert(cmage: CIImage) -> UIImage {
         let context = CIContext(options: nil)
         let cgImage = context.createCGImage(cmage, from: cmage.extent)!
         let image = UIImage(cgImage: cgImage)
         return image
    }
    
//    func adjustBrightness(image: UIImage, brightness: Float) -> UIImage? {
//        // Convert UIImage to CIImage
//        guard let ciImage = CIImage(image: image) else {
//            return nil
//        }
//
//        // Apply brightness filter
//        let parameters = [
//            kCIInputBrightnessKey: brightness
//        ]
//        guard let brightnessFilter = CIFilter(name: "CIColorControls", parameters: parameters) else {
//            return nil
//        }
//        brightnessFilter.setValue(ciImage, forKey: kCIInputImageKey)
//        guard let outputImage = brightnessFilter.outputImage else {
//            return nil
//        }
//
//        // Convert CIImage to UIImage
//        let context = CIContext(options: nil)
//        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
//            return nil
//        }
//        let outputUIImage = UIImage(cgImage: cgImage)
//
//        return outputUIImage
//    }
//
//    func runModel(_ pixelBuffer: CVPixelBuffer,_ interpreter: Interpreter)->[Float]{
//        let batchSize = 1
//        let inputChannels = 3
//        let inputWidth = 224
//        let inputHeight = 224
//
//        // Change Orientation to Portrait
//        var buffer = pixelBuffer
//        let ciimage = CIImage(cvPixelBuffer: buffer).oriented(.right)
//        var image = self.convert(cmage: ciimage)
//        image = cropImage(image)!
//        buffer = image.normalized()!
//
//        let sourcePixelFormat = CVPixelBufferGetPixelFormatType(buffer)
//        assert(sourcePixelFormat == kCVPixelFormatType_32ARGB ||
//               sourcePixelFormat == kCVPixelFormatType_32BGRA ||
//               sourcePixelFormat == kCVPixelFormatType_32RGBA)
//        let imageChannels = 4
//        assert(imageChannels >= inputChannels)
//        let scaledSize = CGSize(width: inputWidth, height: inputHeight)
//        guard let thumbnailPixelBuffer = buffer.centerThumbnail(ofSize: scaledSize) else {
//            return []
//        }
//
//        let outputTensor: Tensor
//        do {
//            try interpreter.allocateTensors()
//
//            let inputTensor = try interpreter.input(at: 0)
//
//            guard let rgbData = rgbDataFromBuffer(
//                thumbnailPixelBuffer,
//                byteCount: batchSize * inputWidth * inputHeight * inputChannels,
//                isModelQuantized: inputTensor.dataType == .uInt8
//            ) else { print("Failed to convert the image buffer to RGB data."); return [] }
//
//            try interpreter.copy(rgbData, toInputAt: 0)
//
//            try interpreter.invoke()
//
//            outputTensor = try interpreter.output(at: 0)
//        } catch let error {
//            print("Failed to invoke the interpreter with error: \(error.localizedDescription)") ;return []
//        }
//        let vector: [Float]
//        switch outputTensor.dataType {
//        case .uInt8:
//            guard let quantization = outputTensor.quantizationParameters else {
//                print("No results returned because the quantization values for the output tensor are nil.")
//                return []
//            }
//            let quantizedResults = [UInt8](outputTensor.data)
//            vector = quantizedResults.map {
//                quantization.scale * Float(Int($0) - quantization.zeroPoint)
//            }
//        case .float32:
//            vector = [Float32](unsafeData: outputTensor.data) ?? []
//        default:
//            print("Output tensor data type \(outputTensor.dataType) is unsupported for this example app.")
//            return []
//        }
//        return vector
//    }
//
//
//    func rgbDataFromBuffer(
//        _ buffer: CVPixelBuffer,
//        byteCount: Int,
//        isModelQuantized: Bool
//    ) -> Data? {
//        CVPixelBufferLockBaseAddress(buffer, .readOnly)
//        defer {
//            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
//        }
//        guard let sourceData = CVPixelBufferGetBaseAddress(buffer) else {
//            return nil
//        }
//
//        let width = CVPixelBufferGetWidth(buffer)
//        let height = CVPixelBufferGetHeight(buffer)
//        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
//        let destinationChannelCount = 3
//        let destinationBytesPerRow = destinationChannelCount * width
//
//        var sourceBuffer = vImage_Buffer(data: sourceData,
//                                         height: vImagePixelCount(height),
//                                         width: vImagePixelCount(width),
//                                         rowBytes: sourceBytesPerRow)
//
//        guard let destinationData = malloc(height * destinationBytesPerRow) else {
//            print("Error: out of memory")
//            return nil
//        }
//
//        defer {
//            free(destinationData)
//        }
//
//        var destinationBuffer = vImage_Buffer(data: destinationData,
//                                              height: vImagePixelCount(height),
//                                              width: vImagePixelCount(width),
//                                              rowBytes: destinationBytesPerRow)
//
//        let pixelBufferFormat = CVPixelBufferGetPixelFormatType(buffer)
//
//        switch (pixelBufferFormat) {
//        case kCVPixelFormatType_32BGRA:
//            vImageConvert_BGRA8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
//        case kCVPixelFormatType_32ARGB:
//            vImageConvert_ARGB8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
//        case kCVPixelFormatType_32RGBA:
//            vImageConvert_RGBA8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
//        default:
//            // Unknown pixel format.
//            return nil
//        }
//
//        let byteData = Data(bytes: destinationBuffer.data, count: destinationBuffer.rowBytes * height)
//        if isModelQuantized {
//            return byteData
//        }
//
//        // Not quantized, convert to floats
//        let bytes = Array<UInt8>(unsafeData: byteData)!
//        var floats = [Float]()
//        for i in 0..<bytes.count {
//            floats.append(Float(bytes[i]) / 255.0)
//        }
//        return Data(copyingBufferOf: floats)
//    }
    
    
}
