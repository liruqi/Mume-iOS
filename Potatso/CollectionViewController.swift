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
        ProxyListViewController(),
        RuleSetListViewController(existing: []),
    ]

    override func pageViewControllersForSegmentPageVC() -> [UIViewController] {
        return pageVCs
    }

    override func segmentsForSegmentPageVC() -> [String] {
        return ["Proxy".localized(), "Rule Set".localized()]
    }

    override func showPage(_ index: Int) {
        if index < 2 {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add))
        }else {
            navigationItem.rightBarButtonItem = nil
        }
        super.showPage(index)
    }

    func add() {
        switch segmentedControl.selectedSegmentIndex {
        case 1:
            let vc = RuleSetConfigurationViewController(ruleSet: nil)
            navigationController?.pushViewController(vc, animated: true)
        case 0:
            let alert = UIAlertController(title: "Add Proxy".localized(), message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Import From QRCode".localized(), style: .default, handler: { (action) in
                let importer = Importer(vc: self)
                importer.importConfigFromQRCode()
            }))
            alert.addAction(UIAlertAction(title: "Manual Settings".localized(), style: .default, handler: { (action) in
                let vc = ProxyConfigurationViewController()
                self.navigationController?.pushViewController(vc, animated: true)
            }))
            alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .cancel, handler: nil))
            if let presenter = alert.popoverPresentationController {
                if let rightBtn : View = navigationItem.rightBarButtonItem?.value(forKey: "view") as? View {
                    presenter.sourceView = rightBtn
                    presenter.sourceRect = rightBtn.bounds
                } else {
                    presenter.sourceView = segmentedControl
                    presenter.sourceRect = segmentedControl.bounds
                }
            }
            self.present(alert, animated: true, completion: nil)
        default:
            break
        }
    }
    
}

