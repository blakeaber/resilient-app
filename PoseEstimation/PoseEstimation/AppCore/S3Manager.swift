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
        
        /*let request = AWSS3TransferManagerUploadRequest()!
         request.bucket = Config.bucketName
         request.key = Config.folderToUpload+fileName
         request.body = videoUrl*/
        
        /*let transferManager = AWSS3TransferManager.default()
         transferManager.upload(request).continueWith(executor: AWSExecutor.mainThread()) { (task) -> Any? in
         if let error = task.error {
         print(error)
         }
         if task.result != nil {
         //print("Uploaded \(key)")
         //let contentUrl = self.s3Url.appendingPathComponent(self.bucketName).appendingPathComponent(key)
         //self.contentUrl = contentUrl
         }
         return nil
         }*/
    }
    
    func makeFileName() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateStr = formatter.string(from: date)
        
        let fileName = UIDevice.current.identifierForVendor!.uuidString+dateStr+".mp4"
        
        return fileName
    }
}
