//
//  CollectionViewController.swift
//  Potatso
//
//  Created by LEI on 5/31/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography

private let rowHeight: CGFloat = 135

class CollectionViewController: SegmentPageVC {

    let pageVCs = [
        RuleSetListViewController(),
        ProxyListViewController(),
    ]

    override func pageViewControllersForSegmentPageVC() -> [UIViewController] {
        return pageVCs
    }

    override func segmentsForSegmentPageVC() -> [String] {
        return ["Rule Set".localized(), "Proxy".localized()]
    }

    override func showPage(index: Int) {
        if index < 2 {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(add))
        }else {
            navigationItem.rightBarButtonItem = nil
        }
        super.showPage(index)
    }

    func add() {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            let vc = RuleSetConfigurationViewController(ruleSet: nil)
            navigationController?.pushViewController(vc, animated: true)
        case 1:
            let alert = UIAlertController(title: "Add Proxy".localized(), message: nil, preferredStyle: .ActionSheet)
            alert.addAction(UIAlertAction(title: "Import From QRCode".localized(), style: .Default, handler: { (action) in
                let importer = Importer(vc: self)
                importer.importConfigFromQRCode()
            }))
            alert.addAction(UIAlertAction(title: "Manual Settings".localized(), style: .Default, handler: { (action) in
                let vc = ProxyConfigurationViewController()
                self.navigationController?.pushViewController(vc, animated: true)
            }))
            alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .Cancel, handler: nil))
            if let presenter = alert.popoverPresentationController {
                if let rightBtn : View = navigationItem.rightBarButtonItem?.valueForKey("view") as? View {
                    presenter.sourceView = rightBtn
                    presenter.sourceRect = rightBtn.bounds
                } else {
                    presenter.sourceView = segmentedControl
                    presenter.sourceRect = segmentedControl.bounds
                }
            }
            self.presentViewController(alert, animated: true, completion: nil)
        default:
            break
        }
    }
    
}

