//
//  DBInitializer.swift
//  Potatso
//
//  Created by LEI on 3/8/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import UIKit
import ICSMainFramework
import NetworkExtension
import CloudKit
import Async
import RealmSwift
import Realm

class DataInitializer: NSObject, AppLifeCycleProtocol {
    static var cloudProxies: [Proxy] = []

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Manager.sharedManager.setup()
        sync()
        API.getProxySets() { (response) in
            do {
            for dic in response {
                if let proxy = Proxy.proxy(dictionary: dic) {
                    let proxies = DBUtils.all(Proxy.self, sorted: "createAt").map({ $0 })
                    for ep in proxies {
                        if ep.host == proxy.host,
                            ep.port == proxy.port {
                            print ("Proxy exists: " + dic.description)
                            return
                        }
                    }
                    try DBUtils.add(proxy)
                }
            }
            } catch {
            }
        }
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
        _ = try? Manager.sharedManager.regenerateConfigFiles()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("applicationWillTerminate")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

}
