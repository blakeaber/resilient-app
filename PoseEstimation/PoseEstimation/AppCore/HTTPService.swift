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
        AF.download(videoUrl)//"http://mirrors.standaloneinstaller.com/video-sample/TRA3106.mp4")
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
    
}
