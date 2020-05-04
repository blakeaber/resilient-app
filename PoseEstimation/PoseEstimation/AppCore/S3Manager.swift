//
//  S3Manager.swift
//  PoseEstimation
//
//  Created by Lazar Djordjevic on 30/04/2020.
//  Copyright © 2020 Lazar Djordjevic. All rights reserved.
//

import UIKit
import AWSCognito
import AWSS3

class S3Manager: NSObject {
    
    var cognitoId: String = UIDevice.current.identifierForVendor!.uuidString
    
    //MARK: - Shared Instance
    static let shared: S3Manager = {
        
        let instance = S3Manager()
        
        return instance
    }()
    
    func setupAWS()
    {
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:Config.regionType, identityPoolId:Config.poolId)
        let configuration = AWSServiceConfiguration(region:Config.regionType, credentialsProvider:credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        credentialsProvider.getIdentityId().continueWith(block: { (task) -> AnyObject? in
            if (task.error != nil) {
                print("Error: " + task.error!.localizedDescription)
            }
            else {
                // the task result will contain the identity id
                self.cognitoId = task.result! as String
                print("Cognito id: \(self.cognitoId)")
            }
            return task;
        })
    }
    
    func uploadFile(videoUrl: URL) {
        let fileName = makeFileName()
        
        let expression:AWSS3TransferUtilityUploadExpression = AWSS3TransferUtilityUploadExpression()
        
        AWSS3TransferUtility.default().uploadFile(videoUrl, bucket: Config.bucketName, key: Config.folderToUpload+fileName, contentType: "video/mp4", expression: expression) { (task, error) in
            if let error = error {
                print(error)
            } else {
                print("video uploaded to s3")
            }
        }
    }
    
    func makeFileName() -> String {
        let timestamp:Int = Int(NSDate().timeIntervalSince1970)
        let fileName = cognitoId+"@\(timestamp)"+".mp4"
        
        return fileName
    }
}
