//
//  OnboardingCVC.swift
//  PoseEstimation
//
//  Created by Lazar Djordjevic on 23/04/2020.
//  Copyright © 2020 Lazar Djordjevic. All rights reserved.
//

import UIKit

class OnboardingCVC: UICollectionViewCell {
    
    @IBOutlet weak var onboardingIV: UIImageView!
    @IBOutlet weak var titleL: UILabel!
    @IBOutlet weak var infoL: UILabel!
    
    func setupCell(image: String, title: String, info: String)
    {
        onboardingIV.image = UIImage(named: image)
        titleL.text = title
        infoL.text = info
    }
    
}
