//
//  Importer.swift
//  Potatso
//
//  Created by LEI on 4/15/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Async
import PotatsoModel
import PotatsoLibrary

struct Importer {
    
    weak var viewController: UIViewController?
    
    init(vc: UIViewController) {
        self.viewController = vc
    }
    
    func importConfigFromUrl() {
        var urlTextField: UITextField?
        let alert = UIAlertController(title: "Import Config From URL".localized(), message: nil, preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.placeholder = "Input URL".localized()
            urlTextField = textField
        }
        alert.addAction(UIAlertAction(title: "OK".localized(), style: .default, handler: { (action) in
            if let input = urlTextField?.text {
                self.onImportInput(input.trimmingCharacters(in: CharacterSet.whitespaces))
            }
        }))
        alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .cancel, handler: nil))
        viewController?.present(alert, animated: true, completion: nil)
    }
    
    func importConfigFromQRCode() {
        guard let vc = QRCodeScannerVC() else {
            return
        }
        vc.resultBlock = { [weak vc] result in
            vc?.navigationController?.popViewController(animated: true)
            if let result = result {
                self.onImportInput(result)
            }
        }
        vc.errorBlock = { [weak vc] error in
            vc?.navigationController?.popViewController(animated: true)
            self.viewController?.showTextHUD("\(error)", dismissAfterDelay: 1.5)
        }
        viewController?.navigationController?.pushViewController(vc, animated: true)
    }
    
    func onImportInput(_ result: String) {
        if Proxy.uriIsProxy(result) {
            importSS(source: result)
        } else {
            importConfig(result, isURL: true)
        }
    }
    
    func importSS(source: String) {
        do {
            let proxy = try Proxy(uri: source)
            do {
                try proxy.validate()
                try DBUtils.add(proxy)
                NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: kProxyServiceAdded), object: nil)
                self.onConfigSaveCallback(true, error: nil)
            } catch {
                self.onConfigSaveCallback(false, error: error)
            }
        } catch {
            self.onConfigSaveCallback(false, error: error)
        }
    }
    
    func importConfig(_ source: String, isURL: Bool) {
        viewController?.showProgreeHUD("Importing Config...".localized())
        Async.background(after: 1) {
            let config = Config()
            do {
                if isURL, let url = URL(string: source), (url.scheme == "https" || url.scheme == "http") {
                    API.getImportData(url: url, callback: { data, error in
                        if let error = error {
                            self.onConfigSaveCallback(false, error: error)
                            return
                        }
                        do {
                            if let result = String(data: data, encoding: .ascii) {
                                if Proxy.uriIsProxy(result) {
                                    self.importSS(source: result)
                                    return
                                }
                                try config.setup(string: result)
                                try config.save()
                                self.onConfigSaveCallback(true, error: nil)
                                return
                            }
                        } catch {
                        }
                        self.onConfigSaveCallback(false, error: error)
                    })
                } else {
                    try config.setup(string: source)
                    try config.save()
                    self.onConfigSaveCallback(true, error: nil)
                }
            } catch {
                self.onConfigSaveCallback(false, error: error)
            }
        }
    }
    
    func onConfigSaveCallback(_ success: Bool, error: Error?) {
        Async.main(after: 0.5) {
            self.viewController?.hideHUD()
            if !success {
                var errorDesc = ""
                if let error = error {
                    errorDesc = "(\(error))"
                }
                if let vc = self.viewController {
                    Alert.show(vc, message: "\("Fail to save config.".localized()) \(errorDesc)")
                }
            }else {
                self.viewController?.showTextHUD("Import Success".localized(), dismissAfterDelay: 1.5)
                let keyWindow = UIApplication.shared.keyWindow
                let tabBarVC:UITabBarController = (keyWindow?.rootViewController) as! UITabBarController
                tabBarVC.selectedIndex = 0
            }
        }
    }

}
