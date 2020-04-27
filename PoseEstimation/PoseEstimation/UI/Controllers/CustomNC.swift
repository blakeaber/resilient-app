//
//  CustomNC.swift
//  PoseEstimation
//
//  Created by Lazar Djordjevic on 24/04/2020.
//  Copyright © 2020 Lazar Djordjevic. All rights reserved.
//

import UIKit

class CustomNC: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let launchedBefore = UserDefaults.standard.bool(forKey: "launchedBefore")
        if launchedBefore && !Config.alwaysShowOnboarding {
            let vc = UIStoryboard.init(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "VideoVC")
            self.setViewControllers([vc], animated: false)
        } else {
            let vc = UIStoryboard.init(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "OnboardingVC")
            self.setViewControllers([vc], animated: false)
            UserDefaults.standard.set(true, forKey: "launchedBefore")
        }
    }
}
