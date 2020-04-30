//
//  VideoVC.swift
//  PoseEstimation
//
//  Created by Lazar Djordjevic on 22/04/2020.
//  Copyright © 2020 Lazar Djordjevic. All rights reserved.
//

import UIKit
import CircleProgressView
import AVKit
import Vision
import os.signpost
import Photos

class VideoVC: UIViewController
{
    @IBOutlet weak var previewIV: UIImageView!
    
    @IBOutlet weak var videoPlayerV: UIView!
    @IBOutlet weak var videoPV: CircleProgressView!
    
    @IBOutlet weak var countdownL: UILabel!
    @IBOutlet weak var cameraPreviewV: UIView!
    
    @IBOutlet weak var audioIconIV: UIImageView!
    @IBOutlet weak var videoIconIV: UIImageView!
    @IBOutlet weak var cameraVWidthConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var jointView: DrawingJointView!
    @IBOutlet weak var cameraPlaceholderIV: UIImageView!
    @IBOutlet weak var actionB: UIButton!
    
    @IBOutlet weak var jointVWidthC: NSLayoutConstraint!
    @IBOutlet weak var jointVHeightC: NSLayoutConstraint!
    var sessionIsActive = false
    var timer:Timer!
    var sendDataTimer:Timer!
    
    var startupTime = Config.videoStartupTime
    
    var player:AVPlayer!
    var playerLayer:AVPlayerLayer!
    
    var request: VNCoreMLRequest!
    var visionModel: VNCoreMLModel!
    var videoCapture: VideoCapture!
    
    var allPredictedPoints:[[PredictedPoint?]] = [[PredictedPoint?]]()
    var videoWriteManager : VideoWriteManager?
    var isRecording = false
    
    private let 👨‍🔧 = 📏()
    var isInferencing = false
    
    let refreshLog = OSLog(subsystem: "com.lazar89nis.PoseEstimation", category: "InferenceOperations")
    var postProcessor: HeatmapPostProcessor = HeatmapPostProcessor()
    var mvfilters: [MovingAverageFilter] = []
    
    // MARK: - view controller functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        countdownL.alpha = 0
        actionB.isEnabled = false
        
        previewIV.isHidden = true
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videoURL = documentsURL.appendingPathComponent("downloadedVideo.mp4")
        
        if FileManager.default.fileExists(atPath:  videoURL.path) {
            self.actionB.isEnabled = true
            self.videoPV.isHidden = true
            
            self.setVideoPlayer(url: videoURL)
        } else {
            HTTPService.shared.downloadVideo(videoUrl:Config.videoUrl, success: { (data) in
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let videoURL = documentsURL.appendingPathComponent("downloadedVideo.mp4")
                do {
                    try data.write(to: videoURL)
                } catch {
                    print("Something went wrong!")
                }
                print(videoURL)
                
                self.actionB.isEnabled = true
                self.videoPV.isHidden = true
                
                self.setVideoPlayer(url: videoURL)
            }, failure: { (error, statusCode) in
                print(statusCode)
            }, inProgress: { (progress) in
                self.videoPV.setProgress(progress/100.0, animated: true)
            })
        }
        
        setUpModel()
        setUpCamera()
        👨‍🔧.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(speechSynthesizerDidStart), name: .speechSynthesizerDidStart, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(speechSynthesizerDidFinish), name: .speechSynthesizerDidFinish, object: nil)
        
        sendDataTimer = Timer.scheduledTimer(timeInterval: Config.sendingDataToServerInterval, target: self, selector: #selector(sendDataToServer), userInfo: nil, repeats: true)
        
        S3Manager.shared.setupAWS()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoCapture.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.videoCapture.stop()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if self.playerLayer != nil
        {
            self.playerLayer.frame = self.videoPlayerV.bounds
        }
        resizePreviewLayer()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { (context) in
        }) { (context) in
            if self.playerLayer != nil
            {
                self.playerLayer.frame = self.videoPlayerV.bounds
            }
        }
        if let orientation = AVCaptureVideoOrientation(orientation: UIDevice.current.orientation) {
            self.videoCapture.avPreviewLayer.connection?.videoOrientation = orientation
            self.videoCapture.videoOutput.connection(with: AVMediaType.video)?.videoOrientation = orientation
        }
    }
    
    // MARK: - notifications
    @objc func speechSynthesizerDidStart() {
        audioIconIV.image = UIImage(named: "audioActive")
    }
    
    @objc func speechSynthesizerDidFinish() {
        audioIconIV.image = UIImage(named: "audio")
    }
    
    @objc func playerItemDidPlayToEndTime() {
        self.perform(#selector(stopRecordingVideoEnded), with: nil, afterDelay: Config.secondsToContinueRecordingAfterVideoEnds)
    }
    
    // MARK: - Helpers
    func saveToAlbum(atURL url: URL,complete: @escaping ((Bool) -> Void)){
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }, completionHandler: { (success, error) in
            complete(success)
        })
    }
    
    func stopRecording()
    {
        if isRecording {
            //Recording, stop recording
            videoWriteManager?.stopWriting()
            isRecording = false
        }
    }
    
    func startRecording()
    {
        if !isRecording {
            //When shooting multiple segments in succession, an instance needs to be regenerated each time. The previous writer will not be able to use it again because it has finished writing
            setupMoiveWriter()
            videoWriteManager?.startWriting()
            isRecording = true
        }
    }
    
    func setVideoPlayer(url: URL)
    {
        let playerItem = AVPlayerItem(asset: AVURLAsset(url: url))
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerItemDidPlayToEndTime), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        self.player = AVPlayer(playerItem: playerItem)
        
        DispatchQueue.main.async {
            if self.playerLayer != nil
            {
                self.playerLayer.removeFromSuperlayer()
            }
            self.playerLayer = AVPlayerLayer(player: self.player)
            self.playerLayer.frame = self.videoPlayerV.bounds
            self.playerLayer.videoGravity = .resizeAspect
            self.videoPlayerV.layer.addSublayer(self.playerLayer)
            
            self.actionB.isHidden = false
        }
    }
    
    func resizePreviewLayer() {
        DispatchQueue.main.async {
            self.videoCapture.previewLayer?.frame = self.cameraPreviewV.bounds
        }
    }
    
    /*func countVisiblePoints()
     {
     if allPredictedPoints.count == 0
     {
     return
     }
     let pontsArr = allPredictedPoints.last!
     var found = 0
     for point in pontsArr
     {
     if point != nil
     {
     if point!.maxConfidence > DrawingJointView.threshold
     {
     found += 1
     }
     }
     }
     DispatchQueue.main.sync {
     if found < 8
     {
     videoIconIV.image = UIImage(named: "video")
     } else {
     videoIconIV.image = UIImage(named: "videoActive")
     }
     }
     }*/
    func setVideoImage(active: Bool)
    {
        if active
        {
            videoIconIV.image = UIImage(named: "videoActive")
        } else {
            videoIconIV.image = UIImage(named: "video")
        }
    }
    
    func startSession()
    {
        timer.invalidate()
        self.player.play()
        startRecording()
    }
    
    func setActionButton()
    {
        if sessionIsActive
        {
            self.actionB.setBackgroundImage(UIImage(named: "close"), for: .normal)
        } else {
            self.actionB.setBackgroundImage(UIImage(named: "play"), for: .normal)
        }
    }
    
    @objc func stopRecordingVideoEnded() {
        if self.isRecording
        {
            self.actionPressed(self.actionB!)
        }
    }
    
    // MARK: - IBActions
    @IBAction func actionPressed(_ sender: Any) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(stopRecordingVideoEnded), object: nil)
        
        sessionIsActive = !sessionIsActive
        
        if sessionIsActive
        {
            player.seek(to: CMTime.zero)
            startTimer()
        } else {
            stopRecording()
            
            player.pause()
            player.seek(to: CMTime.zero)
            
            self.countdownL.alpha = 0
            timer.invalidate()
        }
        
        setActionButton()
    }
    
    // MARK: - Video capture and ML
    func setUpModel() {
        if let visionModel = try? VNCoreMLModel(for: Config.EstimationModel().model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFill
        } else {
            fatalError("cannot load the ml model")
        }
    }
    
    func setupJoinSize(width: CGFloat, height: CGFloat)
    {
        var newWidth:CGFloat = 0.0
        var newHeight:CGFloat = 0.0
        
        if width > height
        {
            newWidth = self.cameraPreviewV.frame.size.width > width ? width : self.cameraPreviewV.frame.size.width
            newHeight = height/width*newWidth
        } else {
            newHeight = self.cameraPreviewV.frame.size.height > height ? height : self.cameraPreviewV.frame.size.height
            newWidth = width/height*newHeight
        }
        
        if self.jointVWidthC.constant != newWidth || self.jointVHeightC.constant != newHeight
        {
            self.jointVWidthC.constant = newWidth
            self.jointVHeightC.constant = newHeight
        }
    }
    
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = Config.cameraFPS
        videoCapture.setUp(sessionPreset: Config.cameraResolution) { success in
            if success {
                if let previewLayer = self.videoCapture.previewLayer {
                    DispatchQueue.main.async {
                        self.cameraPreviewV.layer.addSublayer(previewLayer)
                    }
                    self.resizePreviewLayer()
                    
                    if let orientation = AVCaptureVideoOrientation(orientation: UIDevice.current.orientation)
                    {
                        self.videoCapture.avPreviewLayer?.connection?.videoOrientation = orientation
                        self.videoCapture.videoOutput.connection(with: AVMediaType.video)?.videoOrientation = orientation
                    }
                    DispatchQueue.main.sync {
                        
                        self.cameraPlaceholderIV.isHidden = true
                    }
                }
                self.videoCapture.start()
            }
        }
        
        videoCapture.videoDataCallback = { [weak self] (sampleBuffer) in
            guard let strongSelf = self,let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            var ciImage = CIImage.init(cvImageBuffer: imageBuffer)
            
            ciImage = ciImage.oriented(.upMirrored)
            
            let image = UIImage.init(ciImage: ciImage)
            
            DispatchQueue.main.async {
                //strongSelf.previewIV.image = image
                
                strongSelf.setupJoinSize(width: image.size.width, height: image.size.height)
            }
            strongSelf.videoWriteManager?.processImageData(CIImage: ciImage, atTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        }
    }
    
    func setupMoiveWriter() {
        //Output video parameter settings, if you want to customize the video resolution, set here. Otherwise, the recommended parameters in the corresponding format can be used
        guard let videoSettings = self.videoCapture.recommendedVideoSettingsForAssetWriter(writingTo: .mp4)
            else{
                return
        }
        videoWriteManager = VideoWriteManager(videoSetting: videoSettings, audioSetting: [:], fileType: .mp4)
        //Record success callback
        videoWriteManager?.finishWriteCallback = { [weak self] url in
            print(url)
            
            S3Manager.shared.uploadFile(videoUrl: url)
            
            /*guard let strongSelf = self else {return}
             strongSelf.saveToAlbum(atURL: url, complete: { (success) in
             self?.setVideoPlayer(url: url)
             })*/
        }
    }
    
    // MARK: - Timer
    func startTimer()
    {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(timerTick), userInfo: nil, repeats: true)
        countdownL.alpha = 1
        startupTime = Config.videoStartupTime + 1
        timerTick()
    }
    
    @objc func timerTick()
    {
        startupTime -= 1
        countdownL.text = "\(startupTime)"
        
        if startupTime == 0
        {
            countdownL.text = "GO"
            UIView.animate(withDuration: 0.25, animations: {
                self.countdownL.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }) { (state) in
                UIView.animate(withDuration: 0.25, animations: {
                    self.countdownL.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
                    self.countdownL.alpha = 0
                })
            }
            
            startSession()
        } else {
            UIView.animate(withDuration: 0.25, animations: {
                self.countdownL.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }) { (state) in
                UIView.animate(withDuration: 0.25, animations: {
                    self.countdownL.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                })
            }
        }
        if Config.isTTSEnabledForStartupTime
        {
            TTSManager.shared.speak(countdownL.text!)
        }
    }
    
    @objc func sendDataToServer()
    {
        if isRecording && allPredictedPoints.count > 0
        {
            HTTPService.shared.sendKeyPoints(predictedPoints: allPredictedPoints, success: { (data) in
                self.allPredictedPoints.removeAll()
                let response = DataParser.parseKeypointsResponse(data as! Data)
                
                if response.textToSpeech != ""
                {
                    TTSManager.shared.speak(response.textToSpeech)
                }
                
                self.setVideoImage(active: response.detectionFailingFlag)
            }) { (error, statusCode) in
                print(statusCode)
            }
        }
    }
}

// MARK: - VideoCaptureDelegate
extension VideoVC: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        // the captured image from camera is contained on pixelBuffer
        DispatchQueue.global(qos: .background).async {
            if !self.isInferencing {
                
                self.isInferencing = true
                
                // start of measure
                self.👨‍🔧.🎬👏()
                
                // predict!
                self.predictUsingVision(pixelBuffer: pixelBuffer)
            }
        }
    }
}

extension VideoVC {
    // MARK: - Inferencing
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = request else { fatalError() }
        // vision framework configures the input size of image following our model's input configuration automatically
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        
        if #available(iOS 12.0, *) {
            os_signpost(.begin, log: refreshLog, name: "PoseEstimation")
        }
        try? handler.perform([request])
    }
    
    // MARK: - Postprocessing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if #available(iOS 12.0, *) {
            os_signpost(.event, log: refreshLog, name: "PoseEstimation")
        }
        self.👨‍🔧.🏷(with: "endInference")
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmaps = observations.first?.featureValue.multiArrayValue {
            
            /* =================================================================== */
            /* ========================= post-processing ========================= */
            
            /* ------------------ convert heatmap to point array ----------------- */
            var predictedPoints = postProcessor.convertToPredictedPoints(from: heatmaps, isFlipped: true)
            
            /* --------------------- moving average filter ----------------------- */
            if predictedPoints.count != mvfilters.count {
                mvfilters = predictedPoints.map { _ in MovingAverageFilter(limit: Config.movingAverageFilterLimit) }
            }
            for (predictedPoint, filter) in zip(predictedPoints, mvfilters) {
                filter.add(element: predictedPoint)
            }
            predictedPoints = mvfilters.map { $0.averagedValue() }
            
            if isRecording
            {
                self.allPredictedPoints.append(predictedPoints)
            }
            //countVisiblePoints()
            /* =================================================================== */
            
            /* =================================================================== */
            /* ======================= display the results ======================= */
            DispatchQueue.main.sync {
                // draw line
                self.jointView.bodyPoints = predictedPoints
                
                // end of measure
                self.👨‍🔧.🎬🤚()
                self.isInferencing = false
                
                if #available(iOS 12.0, *) {
                    os_signpost(.end, log: refreshLog, name: "PoseEstimation")
                }
            }
            /* =================================================================== */
        } else {
            // end of measure
            self.👨‍🔧.🎬🤚()
            self.isInferencing = false
            
            if #available(iOS 12.0, *) {
                os_signpost(.end, log: refreshLog, name: "PoseEstimation")
            }
        }
    }
}

// MARK: - 📏(Performance Measurement) Delegate
extension VideoVC: 📏Delegate {
    func updateMeasure(inferenceTime: Double, executionTime: Double, fps: Int) {
        /*let inferenceStr  = "inference: \(Int(inferenceTime*1000.0)) ms"
         let executionStr = "execution: \(Int(executionTime*1000.0)) ms"
         let fpsStr = "fps: \(fps)"*/
    }
}
