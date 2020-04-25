//
//  HTTPService.swift
//  PoseEstimation
//
//  Created by Lazar Djordjevic on 22/04/2020.
//  Copyright © 2020 Lazar Djordjevic. All rights reserved.
//

import Foundation
import LDHTTPService
import Alamofire

class HTTPService {
    
    //MARK: - Shared Instance
    private var service : LDService!
    
    static let shared: HTTPService = {
        
        let instance = HTTPService()
        
        instance.service = LDService(timeoutIntervalRequest: 30, timeoutIntervalResource: 30, contentType: "application/json")
        
        return instance
    }()
    
    func downloadVideo(videoUrl: String, success:@escaping(Data) -> Void, failure:@escaping (Any?, Int) -> Void, inProgress:@escaping(Double) -> Void)
    {
        var progressValue = -1
        AF.download(videoUrl)
            .downloadProgress(queue: .main, closure: { progress in
                let newProgressValue = Int(progress.fractionCompleted * 100)
                if progressValue != newProgressValue
                {
                    progressValue = newProgressValue
                    //print("Download Progress: \(progressValue*10)%")
                    inProgress(Double(progressValue))
                }
            })
            .responseData { responseObject in
                
                switch responseObject.result {
                    case .success(_):
                        if responseObject.response?.statusCode == 200 {
                            success(responseObject.value!)
                    }
                    case let .failure(error):
                        print(error.localizedDescription)
                        failure(nil,0)
                }
        }
    }
    
    func sendKeyPoints(predictedPoints:[[PredictedPoint?]], success:@escaping(Any) -> Void, failure:@escaping (Any?, Int) -> Void)
    {
        var poseEstimatesArr = [[String: Any]]()

        for poseEstimate in predictedPoints
        {
            var keypointsArr = [[String: Any]]()

            var keyPointRow = 0
            for predictedPoint in poseEstimate
            {
                var positionDict = [String: Any]()
                var maxConfidence: Double?

                if predictedPoint != nil {
                    positionDict["x"] = predictedPoint!.maxPoint.x
                    positionDict["y"] = predictedPoint!.maxPoint.y

                    maxConfidence = predictedPoint!.maxConfidence
                }
                let poseName = PoseEstimationForMobileConstant.pointLabels[keyPointRow]
                
                var keyPointDict = [String: Any]()
                keyPointDict["score"] = maxConfidence
                keyPointDict["position"] = predictedPoint == nil ? nil : positionDict
                keyPointDict["part"] = poseName

                keypointsArr.append(keyPointDict)
                keyPointRow += 1
            }
            var poseEstimateDict = [String: Any]()
            poseEstimateDict["keypoints"] = keypointsArr

            poseEstimatesArr.append(poseEstimateDict)
        }
        
        service.requestWithURL("https://uociov56j5.execute-api.us-east-1.amazonaws.com/default/feedback", path: "", methodType: .post, params: ["poseEstimates":poseEstimatesArr as AnyObject,"UDID" : UIDevice.current.identifierForVendor!.uuidString as AnyObject], header: nil, encoding: JSONEncoding.default, success: success, failure: failure)
    }
    
}
