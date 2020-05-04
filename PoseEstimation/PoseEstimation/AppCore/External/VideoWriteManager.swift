//
//  VideoWriteManager.swift
//  ZHCamera
//
//  Created by xuzhenhao on 2018/11/8.
//  Copyright © 2018年 xuzhenhao. All rights reserved.
//

import UIKit
import AVFoundation

class VideoWriteManager: NSObject {
    var videoSettings: [String:Any]
    let fileType: AVFileType
    let assetWriter: AVAssetWriter
    let videoInput: AVAssetWriterInput
    let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    let processQueue = DispatchQueue(label: "com.lazar89nis.vieoWriteQueue")
    
    let ciContext: CIContext = {
        let eaglContext = EAGLContext.init(api: .openGLES2)!
        //Because the image needs to be processed in real time, the CIContext object is generated through the EAGL context. At this time, the rendered object is saved in the GPU and will not be copied to the CPU memory.
        return CIContext.init(eaglContext: eaglContext, options: [CIContextOption.workingColorSpace: NSNull()])
        
    }()
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    //Is writing
    var isWriting = false
    //Mark the next received data as the first frame of data
    var firstSampleFlag = true
    var finishWriteCallback: ((URL) -> Void)?
    
    init(videoSetting: [String:Any],audioSetting: [String:Any],fileType: AVFileType) {
    
        self.videoSettings = videoSetting
        self.fileType = fileType
        //If you want to modify the width and height of the output video, you can modify the AVVideoHeightKey and AVVideoWidthKey in the videoInput configuration
        self.videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: self.videoSettings)
        //Optimized for real-time
        self.videoInput.expectsMediaDataInRealTime = true
        //The mobile phone defaults to shooting with the head to the left, which needs to be rotated and adjusted
        self.videoInput.transform = VideoWriteManager.fixTransform(deviceOrientation: UIDevice.current.orientation)
        //Each AssetWriterInput expects to receive data in CMSampelBufferRef format. If it is CVPixelBuffer format data, it needs to be formatted by adapter before writing
        let attributes = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                          kCVPixelBufferWidthKey: videoSetting[AVVideoWidthKey]!,
                          kCVPixelBufferHeightKey: videoSetting[AVVideoHeightKey]!,
                          kCVPixelFormatOpenGLCompatibility: true] as [String : Any]
        self.pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.videoInput, sourcePixelBufferAttributes: attributes )
        
        let outputURL = VideoWriteManager.createTemplateFileURL()
        do {
           self.assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
            if self.assetWriter.canAdd(videoInput) {
                self.assetWriter.add(videoInput)
            }
        } catch {
            fatalError()
        }
        
        super.init()
    }
    
    //MARK: - Operation
    public func startWriting() {
        processQueue.async {
            self.isWriting = true
        }
    }
    
    public func stopWriting() {
        isWriting = false
        processQueue.async {
            self.assetWriter.finishWriting(completionHandler: {
                if self.assetWriter.status.rawValue == 2 {
                    DispatchQueue.main.async {
                        guard let callback = self.finishWriteCallback else {
                            return
                        }
                        callback(self.assetWriter.outputURL)
                    }
                }
            })
        }
    }
    
    public func processImageData(CIImage image: CIImage,atTime time: CMTime) {
        guard isWriting != false else { return  }
        
        if firstSampleFlag {
            //Receive the first frame of video data and start writing
            let result = assetWriter.startWriting()
            guard result != false else {
                print("Failed to start recording")
                return
            }
            assetWriter.startSession(atSourceTime: time)
            firstSampleFlag = false
        }
        
        var outputRenderBuffer: CVPixelBuffer?
        guard let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool else {
            return
        }

        let result = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &outputRenderBuffer)
        if result != kCVReturnSuccess {
            return
        }

        let width:CGFloat = self.videoSettings[AVVideoWidthKey]! as! CGFloat
        let height:CGFloat = self.videoSettings[AVVideoHeightKey]! as! CGFloat
        
        let centered = image.transformed(by: CGAffineTransform(translationX: (width - image.extent.width) / 2, y: (height - image.extent.height) / 2))
        let background = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: CGSize(width: width, height: height)))
        let preparedImage = centered.composited(over: background)

        ciContext.render(preparedImage, to: outputRenderBuffer!, bounds: preparedImage.extent, colorSpace: colorSpace)

        if videoInput.isReadyForMoreMediaData && isWriting {
            
           let result = pixelBufferAdaptor.append(outputRenderBuffer!, withPresentationTime: time)
            if !result {
                print("Failed to stitch video data")
            }
        } else {
            print("Video Input not ready")
        }
        
    }
    
    //MARK: - utils
    private class func createTemplateFileURL() -> URL {
        
        NSHomeDirectory()
        let path = NSTemporaryDirectory() + "writeTemp.mp4"
        let fileURL = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do { try FileManager.default.removeItem(at: fileURL) } catch {
                
            }
        }
        return fileURL
    }
    
    private class func fixTransform(deviceOrientation: UIDeviceOrientation) -> CGAffineTransform {
        let orientation = deviceOrientation == .unknown ? .portrait : deviceOrientation
        var result: CGAffineTransform
        
        switch orientation {
        case .landscapeRight:
            result = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
        case .portraitUpsideDown:
            result = CGAffineTransform(rotationAngle: CGFloat(Double.pi / 2 * 3))
        case .portrait,.faceUp,.faceDown:
            result = CGAffineTransform(rotationAngle: 0)
        default:
            result = CGAffineTransform.identity
        }
        return result;
    }
}
