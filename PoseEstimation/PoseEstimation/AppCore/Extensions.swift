//
//  Extensions.swift
//  PoseEstimation
//
//  Created by Lazar Djordjevic on 23/04/2020.
//  Copyright © 2020 Lazar Djordjevic. All rights reserved.
//

import Foundation
import UIKit
import AVKit

extension Notification.Name {
    static let speechSynthesizerDidFinish = Notification.Name("speechSynthesizerDidFinish")
    static let speechSynthesizerDidStart = Notification.Name("speechSynthesizerDidStart")    
}

extension CGPoint {
    func angle(with p1: CGPoint, and p2: CGPoint) -> CGFloat {
        let center = self
        let transformedP1 = CGPoint(x: p1.x - center.x, y: p1.y - center.y)
        let transformedP2 = CGPoint(x: p2.x - center.x, y: p2.y - center.y)
        
        let angleToP1 = atan2(transformedP1.y, transformedP1.x)
        let angleToP2 = atan2(transformedP2.y, transformedP2.x)
        
        return normaliseToInteriorAngle(with: angleToP2 - angleToP1)
    }
    
    func normaliseToInteriorAngle(with angle: CGFloat) -> CGFloat {
        var angle = angle
        if (angle < 0) { angle += (2*CGFloat.pi) }
        if (angle > CGFloat.pi) { angle = 2*CGFloat.pi - angle }
        return angle
    }
}

extension CGPoint {
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func /(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        guard rhs != 0.0 else { return lhs }
        return CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }
}

extension AVCaptureVideoOrientation {
    var uiInterfaceOrientation: UIInterfaceOrientation {
        get {
            switch self {
                case .landscapeLeft:        return .landscapeLeft
                case .landscapeRight:       return .landscapeRight
                case .portrait:             return .portrait
                case .portraitUpsideDown:   return .portraitUpsideDown
            }
        }
    }
    
    init(ui:UIInterfaceOrientation) {
        switch ui {
            case .landscapeRight:       self = .landscapeRight
            case .landscapeLeft:        self = .landscapeLeft
            case .portrait:             self = .portrait
            case .portraitUpsideDown:   self = .portraitUpsideDown
            default:                    self = .portrait
        }
    }
    
    init?(orientation:UIDeviceOrientation) {
        switch orientation {
            case .landscapeRight:       self = .landscapeLeft
            case .landscapeLeft:        self = .landscapeRight
            case .portrait:             self = .portrait
            case .portraitUpsideDown:   self = .portraitUpsideDown
            default:
                return nil
        }
    }
}

