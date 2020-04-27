//
//  Config.swift
//  PoseEstimation
//
//  Created by Lazar Djordjevic on 27/04/2020.
//  Copyright © 2020 Lazar Djordjevic. All rights reserved.
//

import Foundation
import AVKit

enum Config {
    static let cameraResolution: AVCaptureSession.Preset = .vga640x480
    static let cameraFPS = 30
    
    static let alwaysShowOnboarding = false
    
    static let serverBaseURL = "https://uociov56j5.execute-api.us-east-1.amazonaws.com"
    static let serverTimeoutIntervalRequest = 30.0
    static let serverTimeoutIntervalResource = 30.0
    
    static let videoUrl = "http://www.hypercubes1.com/testVideo.mp4"
    
    static let sendingDataToServerInterval = 1.0

    static let videoStartupTime = 10
    static let secondsToContinueRecordingAfterVideoEnds = 15.0
    
    static let isTTSEnabledForStartupTime = true
    
    static let movingAverageFilterLimit = 3
    
    static let onboardingPages:[OnboardingPage] = [OnboardingPage(image: "onboarding1", title: "Welcome to Resilient.ai", info: "Take control of body pain anywhere, on your schedule, instantly"),
                                            OnboardingPage(image: "onboarding2", title: "Get Moving", info: "Perform physical therapy and receive real-time feedback from the comfort of your home"),
                                            OnboardingPage(image: "onboarding3", title: "Feel Better", info: "Experience less pain in 5 days or be armed with the evidence you need for a medical consultation")]
    
    typealias EstimationModel = model_cpm
}


