//
//  FaceClassificationController.swift
//  xeno-face-recognition
//
//  Created by MacOS on 27/02/23.
//

import Vision
import CoreImage
import AVFoundation
import TensorFlowLite
import Accelerate

class FaceClassificationController: UIViewController {
    
    @IBOutlet weak var placeHolder: UIView!
    @IBOutlet weak var overlayView: UIView!
    
    @IBOutlet weak var valView: UIView!
    @IBOutlet weak var valLbl: UILabel!
    
    @IBOutlet weak var percentVal: UILabel!
    
    // Video objects.
    fileprivate lazy var session: AVCaptureSession! = {
        $0.sessionPreset = .hd1280x720
        return $0
    }(AVCaptureSession())

    fileprivate var videoDataOutput:AVCaptureVideoDataOutput?
    fileprivate var videoDataOutputQueue: DispatchQueue!

    fileprivate var previewLayer: AVCaptureVideoPreviewLayer!
    fileprivate var lastKnownDeviceOrientation: UIDeviceOrientation! {
        get{
            let current = UIDevice.current.orientation
            switch current {
            case .unknown,.faceUp,.faceDown:
                return .faceUp
            default:
                return current
            }
        }
    }

    // Detector.
    fileprivate let OPEN_THRESHOLD: CGFloat = 0.85
    fileprivate let CLOSE_THRESHOLD: CGFloat = 0.15
    fileprivate var state: Int = 0

    var tekkenPhotoHandler: (()->Void)?
    
    fileprivate lazy var faceDetector = CIDetector(
                                            ofType: CIDetectorTypeFace,
                                            context: nil,
                                            options: [
                                                 CIDetectorAccuracy: CIDetectorAccuracyHigh,
                                                 CIDetectorSmile: true,
                                                 CIDetectorTracking: true,
                                                 CIDetectorEyeBlink: true,
                                            ])!
   
    var isMatch: Bool = false
    
    var flag: Bool = false
    
    var allFaces = [FaceIdService.Face]()
    
    var selectedFaceFeatures: FaceIdService.FaceFeatures?
    
    init() {
        super.init(nibName: "FaceClassificationController", bundle: nil)
        videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // Set up default camera settings.
        self.updateCameraSelection()

        // Setup video processing pipeline.
        self.setupVideoProcessing()

        // Setup camera preview.
        self.setupCameraPreview()
        
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.layer.bounds
        self.previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
    }

    deinit {
        self.cleanupCaptureSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.session.startRunning()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.session.stopRunning()
    }

    override func willAnimateRotation(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        // Camera rotation needs to be manually set when rotation changes.
        switch toInterfaceOrientation {
        case .portrait:
            self.previewLayer.connection?.videoOrientation = .portrait
            break
        case .portraitUpsideDown:
            self.previewLayer.connection?.videoOrientation = .portraitUpsideDown
            break
        case .landscapeLeft:
            self.previewLayer.connection?.videoOrientation = .landscapeLeft
            break
        case .landscapeRight:
            self.previewLayer.connection?.videoOrientation = .landscapeRight
            break
        default:
            break
        }
    }
    
    private func shoot(){
        self.session.stopRunning()
    }

    //MARK: Camera Setup
    private func cleanupVideoProcessing(){
        if let data = self.videoDataOutput {
            self.session.removeOutput(data)
        }

        self.videoDataOutput = nil
    }

    private func cleanupCaptureSession(){
        self.session.stopRunning()
        self.cleanupVideoProcessing()
        self.previewLayer.removeFromSuperlayer()
    }

    private func setupVideoProcessing(){
        self.videoDataOutput = AVCaptureVideoDataOutput()
        self.videoDataOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]

        guard let output = self.videoDataOutput,
            self.session.canAddOutput(output) else {
                self.cleanupCaptureSession()
                print("Failed to setup video output")
                return }

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)
        self.session.addOutput(output)

    }

    private func setupCameraPreview(){
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        self.previewLayer.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        self.previewLayer.videoGravity = .resizeAspectFill
        self.placeHolder.layer.insertSublayer(self.previewLayer, at: 0)
    }

    func camera(for desiredPosition: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: desiredPosition) else {return nil}
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus){
                device.focusMode = .continuousAutoFocus
            }

            if device.isExposureModeSupported(.continuousAutoExposure){
                device.exposureMode = .continuousAutoExposure
            }

            device.unlockForConfiguration()

        } catch  {
            print(error.localizedDescription)
            return nil
        }

        var deviceInput: AVCaptureDeviceInput? = nil

        do {
            deviceInput = try AVCaptureDeviceInput(device: device)
        } catch {
            print(error.localizedDescription)
        }
        if let input = deviceInput {
            if session.canAddInput(input) {
                return input
            }
        }
        return nil
    }

    private func updateCameraSelection(){
        self.session.beginConfiguration()
        // Remove old inputs
        let oldInputs = self.session.inputs
        for oldInput in oldInputs {
            self.session.removeInput(oldInput)
        }

        if let input: AVCaptureDeviceInput = camera(for: .front){
            // Succeeded, set input and update connection states
            self.session.addInput(input)
        }else{
            // Failed, restore old inputs
            for oldInput in oldInputs  {
                self.session.addInput(oldInput)
            }
        }

        self.session.commitConfiguration()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension FaceClassificationController: AVCaptureVideoDataOutputSampleBufferDelegate{
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
        
        if !flag {
            
            guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                debugPrint("unable to get image from sample buffer")
                return
            }
            
            self.detectFace(in: frame)
            
        }
        
    }
    
    private func detectFace(in image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                
//                if let faceRectangles = request.results as? [VNFaceObservation], faceRectangles.count > 0 {
//
//                    if self.isMatch{
//                        for face in faceRectangles{
//                            if self.isBlink(face: face){
//                                DispatchQueue.main.async {
//                                    self.dismiss(animated: true) {
//                                        self.tekkenPhotoHandler?()
//                                    }
//                                }
//                            }
//                        }
//                        return
//                    }
//
//                    self.compareImage(buffer: image)
//                } else {
//                    self.setStatus(status: "face-not-found")
//                    self.isMatch = false
//                }
                
                self.compareImage(buffer: image)
                
            }
        })
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageRequestHandler.perform([faceDetectionRequest])
    }
    
    private func compareImage(buffer: CVPixelBuffer){
        
        flag = true
        
        let ciimage = CIImage(cvPixelBuffer: buffer).oriented(.right)
        let uiimage = convert(cmage: ciimage)
        
        FaceIdService.shared.identify(image: uiimage) { faceFeatures in
            DispatchQueue.main.async {
                
                self.selectedFaceFeatures = faceFeatures
                
                if let selectedFaceFeatures = self.selectedFaceFeatures{
                    
                    let a = FaceIdService.shared.isFace(self.allFaces[0], hasCloseFeaturesWith: selectedFaceFeatures)
                    let b = FaceIdService.shared.isFace(self.allFaces[1], hasCloseFeaturesWith: selectedFaceFeatures)
                    let c = FaceIdService.shared.isFace(self.allFaces[2], hasCloseFeaturesWith: selectedFaceFeatures)
                    
                    print("a", a)
                    print("b", b)
                    print("c", c)
                    
                    let match = [a, b ,c]
                    
                    if !match.contains(false){
//                        self.isMatch = true
                        self.setStatus(status: "face-match")
                    }else{
                        self.setStatus(status: "face-not-match")
                    }
                    
                }
                
                self.flag = false
                
            }
        }
        
        
    }
    
    private func setStatus(status: String){
        DispatchQueue.main.async {
            switch status{
            case "face-not-found":
                self.valView.backgroundColor = #colorLiteral(red: 0.9058823529, green: 0.2980392157, blue: 0.2352941176, alpha: 1)
                self.valLbl.text = "Wajah tidak ditemukan!"
                break
            case "face-not-match":
                self.valView.backgroundColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
                self.valLbl.text = "Wajah tidak sama!"
                break
            case "face-match":
                self.valView.backgroundColor = #colorLiteral(red: 0.0862745098, green: 0.6274509804, blue: 0.5215686275, alpha: 1)
                self.valLbl.text = "Wajah sama, Kedipkan mata!"
                break
            default:
                break
            }
        }
    }
    
    
}
