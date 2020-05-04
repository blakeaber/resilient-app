//
//  VideoCapture.swift
//  PoseEstimation-CoreML
//
//  Created by Eugene Bokhan on 3/13/18.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//  Updated by tucan9389 on 3/15/20.

import UIKit
import AVFoundation
import CoreVideo

public protocol VideoCaptureDelegate: class {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame: CVPixelBuffer, timestamp: CMTime)
}

public class VideoCapture: NSObject {
    public var previewLayer: CALayer?
    public weak var delegate: VideoCaptureDelegate?
    public var fps = 30
    public var avPreviewLayer:AVCaptureVideoPreviewLayer!
    
    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.lazar89nis.sessionQueue")
    
    var lastTimestamp = CMTime()
    
    var videoDataCallback: ((CMSampleBuffer) -> Void)?
    
    public func setUp(sessionPreset: AVCaptureSession.Preset = .vga640x480,
                      cameraPosition: AVCaptureDevice.Position = .front,
                      completion: @escaping (Bool) -> Void) {
        sessionQueue.async {
            self.setUpCamera(sessionPreset: sessionPreset,
                             cameraPosition: cameraPosition,
                             completion: { success in
                                completion(success)
            })
        }
    }
    
    func setUpCamera(sessionPreset: AVCaptureSession.Preset, cameraPosition: AVCaptureDevice.Position, completion: @escaping (_ success: Bool) -> Void) {
        
        
        
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            //fatalError("Error: no video devices available")
            completion(false)
            return
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            completion(false)
            return
            //fatalError("Error: could not create AVCaptureDeviceInput")
        }
        captureSession.beginConfiguration()
        captureSession.sessionPreset = sessionPreset
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        avPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        avPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        avPreviewLayer.connection?.videoOrientation = .portrait
        self.previewLayer = avPreviewLayer
        
        let settings: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
        ]
        
        videoOutput.videoSettings = settings
        videoOutput.alwaysDiscardsLateVideoFrames = false
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // We want the buffers to be in portrait orientation otherwise they are
        // rotated by 90 degrees. Need to set this _after_ addOutput()!
        videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
        
        captureSession.commitConfiguration()
        
        completion(true)
    }
    
    public func start() {
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    public func stop() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
    
    public func recommendedVideoSettingsForAssetWriter(writingTo outputFileType: AVFileType) -> [String: Any]? {
        return videoOutput.recommendedVideoSettingsForAssetWriter(writingTo: outputFileType)
    }
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == videoOutput {
            guard let callback = videoDataCallback else {
                return;
            }
            callback(sampleBuffer)
        }
        
        // Because lowering the capture device's FPS looks ugly in the preview,
        // we capture at full speed but only call the delegate at its desired
        // framerate.
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let deltaTime = timestamp - lastTimestamp
        if deltaTime >= CMTimeMake(value: 1, timescale: Int32(fps)) {
            lastTimestamp = timestamp
        }
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            delegate?.videoCapture(self, didCaptureVideoFrame: imageBuffer, timestamp: timestamp)
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //print("dropped frame")
    }
}

