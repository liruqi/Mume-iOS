//
//  DBInitializer.swift
//  Potatso
//
//  Created by LEI on 3/8/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import UIKit
import Alamofire
import ICSMainFramework
import NetworkExtension
import CloudKit
import Async
import RealmSwift
import Realm

class DataInitializer: NSObject, AppLifeCycleProtocol {
    static var cloudProxies: [Proxy] = []
    static var serverConfigurations = NSMutableDictionary()
    static let reachabilityManager = NetworkReachabilityManager(host:"mumevpn.com")
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Async.background {
            Manager.sharedManager.setup()
        }
        self.updateMumeServers()
        API.getRuleSets() { (result) in
            guard result.count > 0 else {
                return
            }
            let data = result.filter({ $0.name.characters.count > 0})
            for i in 0..<data.count {
                do {
                    try RuleSet.addRemoteObject(data[i])
                } catch {
                    NSLog("Fail to subscribe".localized())
                }
            }
        }
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        self.updateMumeServers()
        _ = try? Manager.sharedManager.regenerateConfigFiles()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("applicationWillTerminate")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }
    
    func updateMumeServers() {
        API.getProxySets() { (response) in
            do {
                for dic in response {
                    if let dict = dic as? [String : String], let proxy = Proxy.proxy(dictionary: dict) {
                        /*
                        let proxies = DBUtils.all(Proxy.self, sorted: "createAt").map({ $0 })
                        for ep in proxies {
                            if ep.host == proxy.host,
                                ep.port == proxy.port {
                                print ("Proxy exists: " + dic.description)
                            }
                        }*/
                        try DBUtils.add(proxy) // can do modification with same key
                        NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: kProxyServiceAdded), object: nil)
                    } else if let dict = dic as? NSDictionary, let mdict = dict.mutableCopy() as? NSMutableDictionary {
                        #if DEBUG
                            mdict.setValue("true", forKey: "ip")
                        #endif
                        DataInitializer.serverConfigurations = mdict
                        NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: kProxyServerConfigurationUpdated), object: dic)
                    }
                }
            } catch {
            }
        }
    }
}
