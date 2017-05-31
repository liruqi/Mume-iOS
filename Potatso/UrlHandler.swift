//
//  UrlHandler.swift
//  Potatso
//
//  Created by LEI on 4/13/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import ICSMainFramework
import PotatsoLibrary
import Async
import CallbackURLKit

public let kProxyServiceAdded = "kProxyServiceAdded"

class UrlHandler: NSObject, AppLifeCycleProtocol {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let manager = CallbackURLKit.Manager.shared
        manager.callbackURLScheme = CallbackURLKit.Manager.urlSchemes?.first
        for action in [URLAction.ON, URLAction.OFF, URLAction.SWITCH] {
            manager[action.rawValue] = { parameters, success, failure, _ in
                action.perform(nil, parameters: parameters) { error in
                    Async.main(after: 1, {
                        if let error = error {
                            failure(error as NSError)
                        } else {
                            success(nil)
                        }
                    })
                    return
                }
            }
        }
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        
        if scheme == "ss" || scheme == "shadowsocks" {
            if let proxy = try? Proxy(uri: url.absoluteString) {
                do {
                    try proxy.validate()
                    let proxies = DBUtils.allNotDeleted(Proxy.self, sorted: "createAt").map({ $0 })
                    for ep in proxies {
                        if ep.host == proxy.host,
                            ep.port == proxy.port {
                            print ("Proxy existings: " + url.absoluteString)
                            return true
                        }
                    }
                    try DBUtils.add(proxy)
                    NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: kProxyServiceAdded), object: nil)
                    return true
                } catch {
                    let errorDesc = "(\(error))"
                    print ("\("Fail to save config.".localized()) \(errorDesc)")
                }
            }
            return false
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var parameters: Parameters = [:]
        components?.queryItems?.forEach {
            guard let _ = $0.value else {
                return
            }
            parameters[$0.name] = $0.value
        }
        if let host = url.host {
            return dispatchAction(url, actionString: host, parameters: parameters)
        }
        return false
    }
    
    func dispatchAction(_ url: URL?, actionString: String, parameters: Parameters) -> Bool {
        guard let action = URLAction(rawValue: actionString) else {
            return false
        }
        return action.perform(url, parameters: parameters)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        let pasteBoard = UIPasteboard.general
        if let content = pasteBoard.string?.trimmingCharacters(in: CharacterSet.whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: " !@#$%^&*")),
            content.characters.count > 3 {
            if Proxy.uriIsShadowsocks(content) {
                do {
                    let proxy = try Proxy(uri: content)
                    try proxy.validate()
                    let proxies = DBUtils.allNotDeleted(Proxy.self, sorted: "createAt").map({ $0 })
                    for ep in proxies {
                        if ep.host == proxy.host,
                            ep.port == proxy.port {
                            print ("Proxy existings: " + content)
                            return
                        }
                    }
                    try DBUtils.add(proxy)
                    pasteBoard.string = ""
                    NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: kProxyServiceAdded), object: nil)
                    return
                } catch {
                }
            }
        }
    }
}

enum URLAction: String {

    case ON = "on"
    case OFF = "off"
    case SWITCH = "switch"
    case XCALLBACK = "x-callback-url"

    func perform(_ url: URL?, parameters: Parameters, completion: ((Error?) -> Void)? = nil) -> Bool {
        switch self {
        case .ON:
            Manager.sharedManager.startVPN({ (manager, error) in
                if error == nil {
                    self.autoClose(parameters)
                }
                completion?(error)
            })
        case .OFF:
            Manager.sharedManager.stopVPN()
            autoClose(parameters)
            completion?(nil)
        case .SWITCH:
            Manager.sharedManager.switchVPN({ (manager, error) in
                if error == nil {
                    self.autoClose(parameters)
                }
                completion?(error)
            })
        case .XCALLBACK:
            if let url = url {
                return CallbackURLKit.Manager.shared.handleOpen(url: url)
            }
        }
        return true
    }

    func autoClose(_ parameters: Parameters) {
        var autoclose = false
        if let value = parameters["autoclose"], value.lowercased() == "true" || value.lowercased() == "1" {
            autoclose = true
        }
        if autoclose {
            Async.main(after: 1, {
                UIControl().sendAction("suspend", to: UIApplication.shared, for: nil)
            })
        }
    }

}
