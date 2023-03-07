//
//  FaceIdService.swift
//  face-id
//
//  Created by Pavel Zhuravlev on 12/23/18.
//  Copyright © 2018 Pavel Zhuravlev. All rights reserved.
//

import UIKit
import CoreML
import Vision

struct Face {
    let photo: String
    var features: FaceIdService.FaceFeatures
}

class FaceIdService {

    typealias FaceFeatures = MLMultiArray

    static var shared = FaceIdService()

    private init() {
    }

    func identify(image: UIImage, withCompletion completion: @escaping (_ faceFeatures: FaceFeatures?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = image.cgImage else {
                completion(nil)
                return
            }
            guard let faceIdmodel = try? VNCoreMLModel(for: FaceId_resnet50_quantized(configuration: MLModelConfiguration()).model) else {
                completion(nil)
                return
            }

            let handler = VNImageRequestHandler(ciImage: CIImage(cgImage: cgImage))
            let faceIdRequest = VNCoreMLRequest(model: faceIdmodel) { request, error in
                guard let observations = request.results as? [VNCoreMLFeatureValueObservation],
                    let faceFeatures = observations.first?.featureValue.multiArrayValue else {
                        completion(nil)
                        return
                }
                completion(faceFeatures)
            }

            do {
                try handler.perform([faceIdRequest])
            }
            catch {
                completion(nil)
            }
        }
    }
    
}
