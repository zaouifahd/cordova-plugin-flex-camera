import Foundation
import UIKit
import MobileCoreServices
import AVFoundation
import AssetsLibrary

protocol cameraDelegate{ func cameraFinished(controller: HappieCameraViewController, JSON: String) }

@objc(HappieCameraViewController) class HappieCameraViewController : UIViewController, AVCaptureFileOutputRecordingDelegate  {
    
    //MARK: Class Variables
    let captureSession = AVCaptureSession() //provides a UI context for capturing media
    var backCameraDevice: AVCaptureDevice? //represents the camera
    var stillImageInput: AVCaptureDeviceInput? //registers an input port for communicating with the connection
    var stillImageOutput: AVCaptureStillImageOutput? //output
    
    let filemgr = NSFileManager.defaultManager()
    var mediaDir: String = "";
    var thumbDir: String = "";
    
    var flashState = 2; //0 = off, 1 = On, 2 = Auto
    var quadState = 0; //0 = UL , 1 = UR, 2 = LL, 3 = LR
    var badgeCounter = 0;
    
    var delegate:cameraDelegate! = nil  //send data back to the plugin class
    var jsonGen = HappieCameraJSON();
    var thumbGen = HappieCameraThumb();
    
    //MARK: State Functions
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?){
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil);
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("NSCoding not supported") }
    
    override func viewDidLoad(){
        super.viewDidLoad()
        var error: NSError?
        quadState = 0;

        //create documents/media folder to contain captured images
        let dirPaths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let docsDir = dirPaths[0]
        mediaDir = docsDir + "/media"
        do {
            try filemgr.createDirectoryAtPath(mediaDir, withIntermediateDirectories: true, attributes: nil)
        } catch let error1 as NSError {
            error = error1
            print("Failed to create media dir: \(error!.localizedDescription)")
        }
        //create documents/media/thumb to contain thumbnails of captured images
        thumbDir = mediaDir + "/thumb";
        do {
            try filemgr.createDirectoryAtPath(thumbDir, withIntermediateDirectories: true, attributes: nil)
        } catch let error1 as NSError {
            error = error1
            print("Failed to create thumb dir: \(error!.localizedDescription)")
        }

        let enumerator:NSDirectoryEnumerator = filemgr.enumeratorAtPath(mediaDir)!
        while let element = enumerator.nextObject() as? String {
            if (element.hasSuffix("jpeg") &&
                (element as NSString).containsString("thumb") &&
                element != "thumb"){
                let path = mediaDir + "/" + element
                if(badgeCounter == 0){
                    ULuii.image = UIImage(contentsOfFile: path)
                    self.badgeCounter++
                    self.quadState = 1
                }
                else if(badgeCounter == 1){
                    URuii.image = UIImage(contentsOfFile: path)
                    self.badgeCounter++
                    self.quadState = 2
                }
                else if(badgeCounter == 2){
                    LLuii.image = UIImage(contentsOfFile: path);
                    self.badgeCounter++
                    self.quadState = 3
                }
                else if(badgeCounter == 3){
                    LRuii.image = UIImage(contentsOfFile: path);
                    self.badgeCounter++
                    self.quadState = 0
                }
            }
        }

        badgeCount.text = String(self.badgeCounter)

        _ = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)

        let devices = AVCaptureDevice.devices()

        // Loop through all the capture devices on this phone
        for device in devices {
            // Make sure this particular device supports video
            if (device.hasMediaType(AVMediaTypeVideo)) {
                // Finally check the position and confirm we've got the back camera
                if(device.position == AVCaptureDevicePosition.Back) {
                    backCameraDevice = device as? AVCaptureDevice
                }
            }
        }

        let possibleCameraInput: AnyObject?
        do {
            possibleCameraInput = try AVCaptureDeviceInput(device: backCameraDevice)
        } catch let error1 as NSError {
            error = error1
            possibleCameraInput = nil
        }
        let backCameraInput = possibleCameraInput as? AVCaptureDeviceInput
        if captureSession.canAddInput(backCameraInput) {
            captureSession.addInput(backCameraInput)
        }

        stillImageOutput = AVCaptureStillImageOutput()
        if captureSession.canAddOutput(stillImageOutput) {
            stillImageOutput?.highResolutionStillImageOutputEnabled = true;
            stillImageOutput?.outputSettings = [AVVideoCodecKey : AVVideoCodecJPEG];
            captureSession.addOutput(stillImageOutput)
        }
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        setFlashModeToAuto(backCameraDevice!)
        beginSession()
    }

    override func viewDidDisappear(animated: Bool){
        captureSession.stopRunning();
    }
    override func viewDidAppear(animated: Bool){
        captureSession.startRunning()
    }

    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask { return UIInterfaceOrientationMask.All }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prefersStatusBarHidden() -> Bool {
        return true
    }

    override func shouldAutorotate() -> Bool {
        return false
    }

    override func willRotateToInterfaceOrientation(newOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        (camPreview.layer as! AVCaptureVideoPreviewLayer).connection.videoOrientation = AVCaptureVideoOrientation(rawValue: newOrientation.rawValue)!

        if(newOrientation == UIInterfaceOrientation.LandscapeLeft || newOrientation == UIInterfaceOrientation.LandscapeRight){
            (camPreview.layer as! AVCaptureVideoPreviewLayer).videoGravity = AVLayerVideoGravityResizeAspect
        }
        else{
            (camPreview.layer as! AVCaptureVideoPreviewLayer).videoGravity = AVLayerVideoGravityResizeAspectFill
        }

        //TODO implement asset rotation something like this let PortraitImage  : UIImage = UIImage(CGImage: LandscapeImage.CGImage ,
         //scale: 1.0 ,
         //orientation: UIImageOrientation.Right)
    }

    //MARK: AVFoundation Implementation
    func beginSession(){
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)

        let orientation: AVCaptureVideoOrientation =  AVCaptureVideoOrientation(rawValue: self.interfaceOrientation.rawValue)!
        previewLayer.connection.videoOrientation = orientation;
        camPreview.layer.addSublayer(previewLayer)

        previewLayer.frame = CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, UIScreen.mainScreen().bounds.size.height)
        previewLayer.bounds = CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, UIScreen.mainScreen().bounds.size.height)
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        captureSession.startRunning()
    }

    //MARK: IB Outlets and Actions
    @IBOutlet weak var camPreview: UIView!
    @IBOutlet weak var flashUIButton: UIButton!
    @IBOutlet weak var ULuii: UIImageView!
    @IBOutlet weak var URuii: UIImageView!
    @IBOutlet weak var LLuii: UIImageView!
    @IBOutlet weak var LRuii: UIImageView!
    @IBOutlet weak var badgeBg: UIImageView!
    @IBOutlet weak var badgeCount: UILabel!

    @IBAction func flashToggle(sender: UIButton) {
        toggleFlashMode(backCameraDevice!)
    }

    @IBAction func cancelSession(sender: AnyObject) {
        resetThumbImages()
        let pathJSON = jsonGen.getFinalJSON(dest: "cancel", save: false)
        setFlashModeToAuto(backCameraDevice!)
        delegate.cameraFinished(self, JSON: pathJSON)
    }

    @IBAction func cameraFinishToQueue(sender: UIButton) {
        resetThumbImages()
        let pathJSON = jsonGen.getFinalJSON(dest: "queue", save: true)
        setFlashModeToAuto(backCameraDevice!)
        delegate.cameraFinished(self, JSON: pathJSON)
    }

    func resetThumbImages(){
        ULuii.image = UIImage(named:"gray.png")
        URuii.image = UIImage(named:"gray.png")
        LLuii.image = UIImage(named:"gray.png")
        LRuii.image = UIImage(named:"gray.png")
    }

    @IBAction func captureImage(sender: UIButton){
        let connection = stillImageOutput?.connectionWithMediaType(AVMediaTypeVideo)
        stillImageOutput?.captureStillImageAsynchronouslyFromConnection(connection, completionHandler:
            { (imageBuffer: CMSampleBufferRef!, error: NSError!) -> Void in
                if((imageBuffer) != nil){
                    let imageData: NSData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageBuffer)
                    self.badgeCounter += 1;
                    let fileName = self.generateFileName()
                    let path = self.mediaDir + "/" + fileName
                    let thumbPath = self.thumbDir + "/" + fileName
                    if self.filemgr.createFileAtPath(path, contents: imageData, attributes: nil) {
                        let thumbData = self.thumbGen.createThumbOfImage(thumbPath, data: imageData)
                        self.badgeCount.text = String(self.badgeCounter)
                        if(self.quadState == 0) {self.ULuii.image = UIImage(data: thumbData, scale: 1); self.quadState = 1}
                        else if(self.quadState == 1) {self.URuii.image = UIImage(data: thumbData, scale: 1); self.quadState = 2}
                        else if(self.quadState == 2) {self.LLuii.image = UIImage(data: thumbData, scale: 1); self.quadState = 3}
                        else if(self.quadState == 3) {self.LRuii.image = UIImage(data: thumbData, scale: 1); self.quadState = 0}
                        let pathResults: [String] = [path, thumbPath]
                        self.jsonGen.addToPathArray(pathResults)
                    }else{
                        print("failed to write image to path: " + path)
                    }

                    //let image = UIImage.init(data: imageData)!
                    //let imageRotation = ALAssetOrientation(rawValue: image.imageOrientation.rawValue)
                    //ALAssetsLibrary().writeImageToSavedPhotosAlbum(image.CGImage!, orientation: imageRotation!,
                    //    completionBlock: {(imagePath: NSURL!, Error: NSError!) -> Void in
                    //        //do stuff after image is saved to the camera roll
                    //    })
                }
        })
    }

    // MARK: AVCaptureFileOutputRecordingDelegate Delegate Conformance
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
    }

    //MARK: Utility Functions
    func deviceWithMediaType(mediaType: NSString, preferringPosition: AVCaptureDevicePosition) -> AVCaptureDevice{
        let devices: NSArray = AVCaptureDevice.devicesWithMediaType(mediaType as String)
        var captureDevice: AVCaptureDevice = devices.firstObject as! AVCaptureDevice

        for device in devices{
            if(device.position == preferringPosition){
                captureDevice = device as! AVCaptureDevice
                break
            }
        }
        return captureDevice
    }

    func setFlashModeToAuto(device: AVCaptureDevice){
        do{
            try device.lockForConfiguration();
            if(backCameraDevice!.hasFlash){
                if(backCameraDevice!.isFlashModeSupported(AVCaptureFlashMode.Auto)){
                    device.flashMode = AVCaptureFlashMode.Auto;
                    let image = UIImage(named: "camera_flash_auto.png") as UIImage!
                    flashUIButton.setImage(image, forState: .Normal)
                }
                if(backCameraDevice!.isTorchModeSupported(AVCaptureTorchMode.Off)){
                    device.torchMode = AVCaptureTorchMode.Off;
                }
            }else{
                let image = UIImage(named: "camera_flash_off.png") as UIImage!
                flashUIButton.setImage(image, forState: .Normal)
                flashUIButton.hidden = true;
            }
            flashState = 2


            device.unlockForConfiguration()
        }catch{
            //TODO write error handling code at some point
        }
    }

    func toggleFlashMode(device:AVCaptureDevice){
        do{
            if(backCameraDevice!.hasFlash){
                try device.lockForConfiguration();

                if(flashState == 0){
                    if(backCameraDevice!.isFlashModeSupported(AVCaptureFlashMode.Off)){
                        device.flashMode = AVCaptureFlashMode.Off;
                        let image = UIImage(named: "camera_flash_off.png") as UIImage!
                        flashUIButton.setImage(image, forState: .Normal)
                    }
                    if(backCameraDevice!.isTorchModeSupported(AVCaptureTorchMode.Off)){
                        device.torchMode = AVCaptureTorchMode.Off;
                    }
                    flashState = 1;
                }

                else if(flashState == 1){
                    if(backCameraDevice!.isFlashModeSupported(AVCaptureFlashMode.Auto)){
                        device.flashMode = AVCaptureFlashMode.Auto;
                        let image = UIImage(named: "camera_flash_auto.png") as UIImage!
                        flashUIButton.setImage(image, forState: .Normal)
                    }
                    if(backCameraDevice!.isTorchModeSupported(AVCaptureTorchMode.Off)){
                        device.torchMode = AVCaptureTorchMode.Off;
                    }
                    flashState = 2
                }
                else if(flashState == 2){
                    if(backCameraDevice!.isFlashModeSupported(AVCaptureFlashMode.Off)){
                        device.flashMode = AVCaptureFlashMode.Off;
                        let image = UIImage(named: "camera_flash_on.png") as UIImage!
                        flashUIButton.setImage(image, forState: .Normal)
                    }
                    if(backCameraDevice!.isTorchModeSupported(AVCaptureTorchMode.On)){
                        device.torchMode = AVCaptureTorchMode.On;
                    }

                    flashState = 0;
                }
                device.unlockForConfiguration()
            }

        }catch{
            //TODO write error handling code at some point
        }
    }
    
    func generateFileName() -> String {
        let date = NSDate()
        let format = NSDateFormatter()
        format.dateFormat = "yyyyMMdd_HHmmss"
        let stringDate = format.stringFromDate(date)
        return stringDate + "photo" + String(badgeCounter) + ".jpeg"
    }
}