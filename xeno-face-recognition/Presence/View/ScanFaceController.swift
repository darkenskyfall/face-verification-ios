//
//  FaceClassificationController.swift
//  xeno-face-recognition
//
//  Created by MacOS on 27/02/23.
//

import UIKit
import AVFoundation
import Accelerate
//import TensorFlowLite
import Vision

class ScanFaceController: UIViewController {
    
    @IBOutlet weak var placeHolder: UIView!
    @IBOutlet weak var overlayView: UIView!
    
    @IBOutlet weak var valView: UIView!
    @IBOutlet weak var valLbl: UILabel!
    
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
    
    var status: Int = 0
    
    var flag: Bool = false
    
    init() {
        super.init(nibName: "ScanFaceController", bundle: nil)
        videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.changeStatus(status: self.status)
        
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

        let metadataOutput = AVCaptureMetadataOutput()
        let metaQueue = DispatchQueue(label: "MetaDataSession")
        metadataOutput.setMetadataObjectsDelegate(self, queue: metaQueue)
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
        } else {
            print("Meta data output can not be added.")
        }

        metadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.face]
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

extension ScanFaceController: AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate{
   
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
        
        if (!flag) {
            
            guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                debugPrint("unable to get image from sample buffer")
                return
            }
            
            self.detectFace(in: frame)
            
        }
        
    }
    
    private func runStatus(in image: CVPixelBuffer, face: VNFaceObservation){
        
        switch status{
        case 0:
            if self.isTurnRight(face: face){
                self.saveJPG(image, "example1")
                self.changeStatus(status: 1)
            }
            break
        case 1:
            if self.isTurnLeft(face: face){
                self.saveJPG(image, "example2")
                self.changeStatus(status: 2)
            }
            break
        case 2:
            if self.isBlink(face: face){
                self.saveJPG(image, "example3")
                self.changeStatus(status: 3)
            }
            break
        default:
            break
        }
        
    }
    
    private func detectFace(in image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                if let faceRectangles = request.results as? [VNFaceObservation], faceRectangles.count > 0 {
                    
                    self.setDetect(isDetected: true)
                    
                    for face in faceRectangles{
                        self.runStatus(in: image, face: face)
                    }
                    
                } else {
                    
                    self.setDetect(isDetected: false)
                    
                }
            }
        })
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageRequestHandler.perform([faceDetectionRequest])
    }
    
    private func setDetect(isDetected: Bool){
        if isDetected{
            self.valView.backgroundColor = #colorLiteral(red: 0.2039215686, green: 0.5960784314, blue: 0.8588235294, alpha: 1)
            self.changeStatus(status: self.status)
        }else{
            self.valView.backgroundColor = #colorLiteral(red: 1, green: 0.231372549, blue: 0.1882352941, alpha: 1)
            self.valLbl.text = "Wajah tidak ditemukan"
        }
    }
    
    private func changeStatus(status: Int){
        
        self.status = status
        
        switch self.status{
        case 0:
            self.valLbl.text = "Toleh Kanan"
            break
        case 1:
            self.valLbl.text = "Toleh Kiri"
            break
        case 2:
            self.valLbl.text = "Kedipkan Mata"
            break
        default:
            self.valLbl.text = "Selesai"
            self.shoot()
            break
        }
        
    }
    
    private func saveJPG(_ buffer: CVPixelBuffer,_ fileName: String){
        
        flag = true
        
        let ciimage = CIImage(cvPixelBuffer: buffer).oriented(.right)
        let uiimage = convert(cmage: ciimage)
        if let imageData = uiimage.jpegData(compressionQuality: 1.0) {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsURL.appendingPathComponent("\(fileName).jpg")
            do {
                try imageData.write(to: fileURL)
                print("Success saving image:", fileName)
            } catch {
                print("Error saving image:", error)
            }
        }
        
        flag = false
    }
    
    private func shoot(){
        self.session.stopRunning()
        DispatchQueue.main.async {
            self.dismiss(animated: true) {
                self.tekkenPhotoHandler?()
            }
        }
    }
    
    
}
