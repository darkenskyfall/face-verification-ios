//
//  HomeController.swift
//  xeno-face-recognition
//
//  Created by MacOS on 24/02/23.
//

import UIKit
import Vision
import TensorFlowLite

class HomeController: UIViewController {
    
    
    @IBOutlet weak var img1: UIImageView!
    @IBOutlet weak var img2: UIImageView!
    @IBOutlet weak var img3: UIImageView!
    @IBOutlet weak var img4: UIImageView!
    @IBOutlet weak var img5: UIImageView!
    
    
    var allFaces: [Face] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        showModel()
    }
    
    @IBAction func deleteSampleDidTap(_ sender: Any) {
        
        if checkFile(){
            let alert = UIAlertController(title: "Attention", message: "Are you sure to delete this sample?", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Not Yet", style: .cancel, handler: { act in
                ///
            }))

            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { act in
                self.dismiss(animated: true)
                self.deleteSample()
            }))

            present(alert, animated: true)
        }else{
            let alert = UIAlertController(title: "Sorry", message: "This sample actually empty!", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { act in
                ///
            }))
            present(alert, animated: true)
        }
        
    }
    
    @IBAction func scanBtnDidTap(_ sender: Any) {
        if (checkFile()){
            showScanFace()
        }else{
            showSaveFace()
        }
    }
    
    private func deleteSample(){

        let examples: [String] = ["example1", "example2", "example3"]
        
        var i = 1
        
        for example in examples{
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsURL.appendingPathComponent("\(example).jpg")
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("Success deleting image:", example)
                i += 1
                if i == 3{
                    let alert = UIAlertController(title: "Success", message: "Sample removed successfully!", preferredStyle: .actionSheet)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { act in
                        self.showModel()
                    }))
                    present(alert, animated: true)
                }
            } catch {
                print("Error deleting image:", error)
            }
        }
    }
    
    private func checkFile()->Bool{
        return getImage(fileName: "example1") && getImage(fileName: "example2") && getImage(fileName: "example3")
    }
    
    private func getImage(fileName: String)->Bool{
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("\(fileName).jpg")
        if let _ = UIImage(contentsOfFile: fileURL.path) {
            return true
        } else {
            return false
        }
    }
    
    private func showSaveFace(){
        let alert = UIAlertController(title: "Hmm", message: "You should scan your face firstly!", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Let's Go", style: .default, handler: { act in
            self.toScan()
        }))
        
        alert.addAction(UIAlertAction(title: "Not Yet", style: .cancel, handler: { act in
            //
        }))
        
        present(alert, animated: true)
    }
    
    private func showScanFace(){
        let alert = UIAlertController(title: "Hello", message: "Are you ready to verify your face?", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Yes, I'am Ready!", style: .default, handler: { act in
            self.identifySampleImage()
        }))
        
        alert.addAction(UIAlertAction(title: "Not Yet", style: .cancel, handler: { act in
            //
        }))
        present(alert, animated: true)
    }
    
    func toFace(){
        if allFaces.count == 3{
            let vc = FaceClassificationController()
            vc.allFaces = allFaces
            vc.tekkenPhotoHandler = {
                let alert = UIAlertController(title: "Success", message: "Your face verified!", preferredStyle: .actionSheet)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { act in
                    
                }))
                
                self.present(alert, animated: true)
            }
            self.present(vc, animated: true)
        }
    }
    
    private func identifySampleImage(){
        let img1 = getImage(fileName: "example1.jpg")!
        let img2 = getImage(fileName: "example2.jpg")!
        let img3 = getImage(fileName: "example3.jpg")!
        
        allFaces = []
        
        let images = [img1, img2, img3]
        var num = 1
        for image in images{
            FaceIdService.shared.identify(image: image) { faceFeatures in
                
                guard let faceFeatures = faceFeatures else {
                    return
                }
                let newFace = Face(photo: "example\(num)", features: faceFeatures)
                if num == 1{
                    self.allFaces = [newFace]
                }else{
                    self.allFaces.append(newFace)
                }
                num += 1
                
                DispatchQueue.main.async {
                    self.toFace()
                }
            }
        }
        
    }
    
    private func showModel(){
        if checkFile(){
            self.img1.image = getImage(fileName: "example1.jpg")!
            self.img2.image = getImage(fileName: "example2.jpg")!
            self.img3.image = getImage(fileName: "example3.jpg")!
        }else{
            self.img1.image = nil
            self.img2.image = nil
            self.img3.image = nil
        }
    }
    
    private func getImage(fileName: String)->UIImage?{
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("\(fileName).jpg")
        if let image = UIImage(contentsOfFile: fileURL.path) {
            return image
        } else {
            return nil
        }
    }
    
    private func toScan(){
        let vc = ScanFaceController()
        vc.tekkenPhotoHandler = { 
            
            let alert = UIAlertController(title: "Success", message: "Sample saved successfully!", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { act in
                self.showModel()
            }))
            
            self.present(alert, animated: true)
        }
        self.present(vc, animated: true)
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
