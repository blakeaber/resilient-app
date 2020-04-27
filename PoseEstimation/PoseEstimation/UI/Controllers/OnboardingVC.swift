//
//  OnboardingVC.swift
//  PoseEstimation
//
//  Created by Lazar Djordjevic on 23/04/2020.
//  Copyright © 2020 Lazar Djordjevic. All rights reserved.
//

import UIKit

struct OnboardingPage {
    let image: String
    let title: String
    let info: String
}

extension UINavigationController {
    
    override open var shouldAutorotate: Bool {
        get {
            if let visibleVC = visibleViewController {
                return visibleVC.shouldAutorotate
            }
            return super.shouldAutorotate
        }
    }
    
    override open var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation{
        get {
            if let visibleVC = visibleViewController {
                return visibleVC.preferredInterfaceOrientationForPresentation
            }
            return super.preferredInterfaceOrientationForPresentation
        }
    }
    
    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask{
        get {
            if let visibleVC = visibleViewController {
                return visibleVC.supportedInterfaceOrientations
            }
            return super.supportedInterfaceOrientations
        }
    }}

class OnboardingVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var pageC: UIPageControl!
    @IBOutlet weak var skipButton: UIButton!
    var currentInfoPage = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.dataSource = self
        collectionView.delegate = self
        
        collectionView.register(UINib(nibName: "OnboardingCVC", bundle: nil), forCellWithReuseIdentifier: "OnboardingCVC")
        collectionView.isPagingEnabled = true
        
        
        let flow = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        flow.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var shouldAutorotate: Bool {
        return UIDevice.current.orientation == .portrait
    }

    @IBAction func skipPressed(_ sender: Any) {
        let vc = UIStoryboard.init(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "VideoVC")
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    // MARK: - collection view
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return Config.onboardingPages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "OnboardingCVC", for: indexPath) as! OnboardingCVC

        let page:OnboardingPage = Config.onboardingPages[indexPath.row]
        
        cell.setupCell(image: page.image, title: page.title, info: page.info)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        return CGSize(width:collectionView.frame.width, height: collectionView.frame.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    // MARK: - UIScrollView delegates

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        setPager()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        setPager()
    }
    
    // MARK: - Helpers
    func setPager()
    {
        let pageWidth: Float = Float(collectionView.frame.size.width)
        let curr: Float = Float(collectionView.contentOffset.x) / pageWidth
        
        if 0.0 != fmodf(curr, 1.0) {
            pageC.currentPage = Int(curr) + 1
        } else {
            currentInfoPage = Int(curr)
            pageC.currentPage = Int(curr)
        }
        if Int(curr) == Config.onboardingPages.count - 1
        {
            skipButton.setTitle("Start", for: .normal)
        } else {
            skipButton.setTitle("Skip", for: .normal)
        }
    }
}
