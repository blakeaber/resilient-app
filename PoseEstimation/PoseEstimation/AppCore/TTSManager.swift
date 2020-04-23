//
//  TTSManager.swift
//  PoseEstimation
//
//  Created by Lazar Djordjevic on 22/04/2020.
//  Copyright © 2020 Lazar Djordjevic. All rights reserved.
//

import Foundation
import AVFoundation

class TTSManager: NSObject, AVSpeechSynthesizerDelegate {
    
    let speechSynthesizer = AVSpeechSynthesizer()
    
    static let shared: TTSManager = {
        let instance = TTSManager()
        
        instance.speechSynthesizer.delegate = instance
        
        return instance
    }()
    
    func speak(_ text: String)
    {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice  = AVSpeechSynthesisVoice(language: "en-US")
        speechUtterance.rate = 0.5
        
        speechSynthesizer.speak(speechUtterance)
    }
    
    func stopSpeak()
    {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        NotificationCenter.default.post(name: .speechSynthesizerDidStart, object: nil)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        NotificationCenter.default.post(name: .speechSynthesizerDidFinish, object: nil)
    }
}
