//
//  ProxyConfigurationViewController.swift
//  Potatso
//
//  Created by Ruqi on 7/10/17.
//  Copyright © 2017 Ruqi Li. All rights reserved.
//

import UIKit
import Eureka
import PotatsoLibrary
import PotatsoModel

private let kProxyFormDue = "due"
private let kProxyFormProvider = "provider"

class CloudProxyDetailViewController: ProxyConfigurationViewController {
    var cloudProxy: CloudProxy
    
    convenience init(cloudProxy: CloudProxy) {
        self.init(upstreamProxy: cloudProxy)
        self.cloudProxy = CloudProxy(value: cloudProxy)
    }

    override init(upstreamProxy: Proxy?) {
        self.cloudProxy = CloudProxy()
        super.init(upstreamProxy: upstreamProxy)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "Add Proxy".localized()
        guard let section = form.allSections.last else {
            return
        }
        if let due = self.cloudProxy.due, due.characters.count > 0 {
            section <<< TextRow(kProxyFormDue) {
                $0.title = "Due".localized()
                $0.value = due
                $0.disabled = Condition.function([], { _ in
                    return true
                })
                }.cellSetup { cell, row in
                    cell.textField.keyboardType = .URL
                    cell.textField.autocorrectionType = .no
                    cell.textField.autocapitalizationType = .none
            }
        }
        if let provider = self.cloudProxy.provider, provider.characters.count > 0 {
            section <<< TextRow(kProxyFormProvider) {
                $0.title = "Provider".localized()
                $0.value = provider
                $0.disabled = Condition.function([], { _ in
                    return true
                })
                }.cellSetup { cell, row in
                    cell.textField.keyboardType = .URL
                    cell.textField.autocorrectionType = .no
                    cell.textField.autocapitalizationType = .none
            }
        }
    }
    
}
