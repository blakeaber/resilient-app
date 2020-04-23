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

    @IBOutlet weak var visiblePointsL: UILabel!
    @IBOutlet weak var videoPlayerV: UIView!
    @IBOutlet weak var playB: UIButton!
    @IBOutlet weak var videoPV: CircleProgressView!
    
    @IBOutlet weak var countdownL: UILabel!
    @IBOutlet weak var cameraPreviewV: UIView!
    
    @IBOutlet weak var audioIconIV: UIImageView!
    @IBOutlet weak var videoIconIV: UIImageView!
    @IBOutlet weak var closeB: UIButton!
    @IBOutlet weak var cameraVWidthConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var jointView: DrawingJointView!
    
    var timer:Timer!
    var startupTime = 10
    
    var player:AVPlayer!
    var playerLayer:AVPlayerLayer!
    
    typealias EstimationModel = model_cpm
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
        playB.isEnabled = false
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videoURL = documentsURL.appendingPathComponent("downloadedVideo.mp4")
        
        if FileManager.default.fileExists(atPath:  videoURL.path) {
            self.playB.isEnabled = true
            self.videoPV.isHidden = true
            
            self.setVideoPlayer(url: videoURL)
        } else {
            HTTPService.shared.downloadVideo(videoUrl:"http://www.hypercubes1.com/testVideo.mp4", success: { (data) in
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let videoURL = documentsURL.appendingPathComponent("downloadedVideo.mp4")
                do {
                    try data.write(to: videoURL)
                } catch {
                    print("Something went wrong!")
                }
                print(videoURL)
                
                self.playB.isEnabled = true
                self.videoPV.isHidden = true
                
                self.setVideoPlayer(url: videoURL)
            }, failure: { (error, statusCode) in
                print(statusCode)
            }, inProgress: { (progress) in
                self.videoPV.setProgress(progress/100.0, animated: true)
            })
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        jointView.addGestureRecognizer(tap)
        
        setUpModel()
        setUpCamera()
        👨‍🔧.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(speechSynthesizerDidStart), name: .speechSynthesizerDidStart, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(speechSynthesizerDidFinish), name: .speechSynthesizerDidFinish, object: nil)
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
        self.playB.isHidden = false
    }
    
    // MARK: - Helpers
    func saveToAlbum(atURL url: URL,complete: @escaping ((Bool) -> Void)){
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }, completionHandler: { (success, error) in
            complete(success)
        })
    }
    
    func startStop() {
        //Did not start recording, start recording
        if !isRecording {
            //When shooting multiple segments in succession, an instance needs to be regenerated each time. The previous writer will not be able to use it again because it has finished writing
            setupMoiveWriter()
            videoWriteManager?.startWriting()
            isRecording = true
        }else {
            //Recording, stop recording
            videoWriteManager?.stopWriting()
            isRecording = false
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
            self.videoPlayerV.bringSubviewToFront(self.playB)
            
            self.playB.isHidden = false
        }
    }
    
    func resizePreviewLayer() {
        DispatchQueue.main.async {
            self.videoCapture.previewLayer?.frame = self.cameraPreviewV.bounds
        }
    }
    
    func countVisiblePoints()
    {
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
            visiblePointsL.text = "\(found)"
        }
    }
    
    // MARK: - IBActions
    @IBAction func closePressed(_ sender: Any) {
        TTSManager.shared.speak("some test to say")
        startStop()
    }
    
    @IBAction func playPressed(_ sender: Any) {
        player.seek(to: CMTime.zero)
        player.play()
        self.playB.isHidden = true
        startTimer()
    }
    
    // MARK: - Gesture Recognizers
    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        if cameraVWidthConstraint.constant == 0
        {
            cameraVWidthConstraint.constant = UIScreen.main.bounds.width*0.6
        } else {
            cameraVWidthConstraint.constant = 0
        }
    }
    
    // MARK: - Video capture and ML
    func setUpModel() {
        if let visionModel = try? VNCoreMLModel(for: EstimationModel().model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFill
        } else {
            fatalError("cannot load the ml model")
        }
    }
    
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .vga640x480) { success in
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
                strongSelf.previewIV.image = image
            }
            strongSelf.videoWriteManager?.processImageData(CIImage: ciImage, atTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        }
    }
    
    func setupMoiveWriter() {
        //Output video parameter settings, if you want to customize the video resolution, set here. Otherwise, the recommended parameters in the corresponding format can be used
        guard let videoSetings = self.videoCapture.recommendedVideoSettingsForAssetWriter(writingTo: .mp4)
            else{
                return
        }
        videoWriteManager = VideoWriteManager(videoSetting: videoSetings, audioSetting: [:], fileType: .mp4)
        //Record success callback
        videoWriteManager?.finishWriteCallback = { [weak self] url in
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
        startupTime = 11
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
            
            timer.invalidate()
        } else {
            UIView.animate(withDuration: 0.25, animations: {
                self.countdownL.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }) { (state) in
                UIView.animate(withDuration: 0.25, animations: {
                    self.countdownL.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                })
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
                mvfilters = predictedPoints.map { _ in MovingAverageFilter(limit: 3) }
            }
            for (predictedPoint, filter) in zip(predictedPoints, mvfilters) {
                filter.add(element: predictedPoint)
            }
            predictedPoints = mvfilters.map { $0.averagedValue() }
            
            self.allPredictedPoints.append(predictedPoints)
            countVisiblePoints()
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
