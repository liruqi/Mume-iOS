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
            for dic in response {
                if let proxy = Proxy.proxy(dictionary: dic) {
                    let proxies = DBUtils.allNotDeleted(Proxy.self, sorted: "createAt").map({ $0 })
                    for ep in proxies {
                        if ep.host == proxy.host,
                            ep.port == proxy.port {
                            print ("Proxy exists: " + dic.description)
                            return
                        }
                    }
                    DataInitializer.cloudProxies.append(proxy)
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
