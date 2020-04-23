//
//  MovingAverageFilter.swift
//  PoseEstimation-CoreML
//
//  Created by Doyoung Gwak on 26/06/2019.
//  Copyright © 2019 tucan9389. All rights reserved.
//

import UIKit

class MovingAverageFilter {
    var elements: [PredictedPoint?] = []
    private var limit: Int
    
    init(limit: Int) {
        guard limit > 0 else { fatalError("limit should be uppered than 0 in MovingAverageFilter init(limit:)") }
        self.elements = []
        self.limit = limit
    }
    
    func add(element: PredictedPoint?) {
        elements.append(element)
        while self.elements.count > self.limit {
            self.elements.removeFirst()
        }
    }
    
    func averagedValue() -> PredictedPoint? {
        let nonoptionalPoints: [CGPoint] = elements.compactMap{ $0?.maxPoint }
        let nonoptionalConfidences: [Double] = elements.compactMap{ $0?.maxConfidence }
        guard !nonoptionalPoints.isEmpty && !nonoptionalConfidences.isEmpty else { return nil }
        let sumPoint = nonoptionalPoints.reduce( CGPoint.zero ) { $0 + $1 }
        let sumConfidence = nonoptionalConfidences.reduce( 0.0 ) { $0 + $1 }
        return PredictedPoint(maxPoint: sumPoint / CGFloat(nonoptionalPoints.count), maxConfidence: sumConfidence)
    }
}
