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
        
        if Proxy.schemeIsProxy(scheme) {
            do {
            if let proxy = try? Proxy(url: url), Proxy.insertOrUpdate(proxy: proxy) {
                return true
            }
            
            if let str = url.absoluteString.removingPercentEncoding {
                let parts = str.components(separatedBy: CharacterSet(charactersIn: " ,*"))
                var cnt = 0
                
                for part in parts {
                    if let purl = URL(string: part),
                        Proxy.schemeIsProxy(purl.scheme ?? "") {
                        let proxy = try Proxy(url: purl)
                        if Proxy.insertOrUpdate(proxy: proxy) {
                            cnt += 1
                        }
                    }
                }
                if cnt > 0 {
                    return true
                }
            }
            } catch {
                
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
            let str = content.removingPercentEncoding,
            str.characters.count > 3 {
            if Proxy.uriIsProxy(str) {
                if let proxy = try? Proxy(string: str), Proxy.insertOrUpdate(proxy: proxy) {
                    return
                }
                
                let parts = str.components(separatedBy: CharacterSet(charactersIn: " ,*"))
                var cnt = 0
                
                for part in parts {
                    if let purl = URL(string: part),
                        Proxy.schemeIsProxy(purl.scheme ?? "") {
                        if let proxy = try? Proxy(url: purl), Proxy.insertOrUpdate(proxy: proxy) {
                            cnt += 1
                        }
                    }
                }
                if cnt > 0 {
                    print("Imported " + cnt.description)
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
            Manager.shared.startVPN({ (manager, error) in
                if error == nil {
                    self.autoClose(parameters)
                }
                completion?(error)
            })
        case .OFF:
            Manager.shared.stopVPN()
            autoClose(parameters)
            completion?(nil)
        case .SWITCH:
            Manager.shared.switchVPN({ (manager, error) in
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
