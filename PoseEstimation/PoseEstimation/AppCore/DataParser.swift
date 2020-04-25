//
//  DataParser.swift
//  PoseEstimation
//
//  Created by Lazar Djordjevic on 25/04/2020.
//  Copyright © 2020 Lazar Djordjevic. All rights reserved.
//

import UIKit
import SwiftyJSON
import LDHTTPService

struct KeypointsResponse {
    var detectionFailingFlag: Bool
    var textToSpeech: String
}

class DataParser : JSONParser {
    
    static func parseKeypointsResponse(_ JSONData: Data?) -> KeypointsResponse
    {
        let json:JSON = getJSONFromData(JSONData)

        let feedback = json["feedback"]
        
        let system = feedback["system"]
        let detectionFailingFlag = system["detection-failing-flag"].boolValue
        
        let user = feedback["user"]
        let textToSpeech = user["text-to-speech"].stringValue

        return KeypointsResponse(detectionFailingFlag: detectionFailingFlag, textToSpeech: textToSpeech)
    }
}
