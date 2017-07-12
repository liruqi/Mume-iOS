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
    static var cloudProxies: [CloudProxy] = []
    static var serverConfigurations = NSMutableDictionary()
    static let reachabilityManager = NetworkReachabilityManager(host:"mumevpn.com")
    static var vpnStatus: VPNStatus = .off
    static var selectedProxy: String? = nil
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let _ = Manager.shared
        
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
        _ = try? Manager.shared.regenerateConfigFiles()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("applicationWillTerminate")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        Appirater.appEnteredForeground(true)
    }
    
    func updateMumeServers() {
        guard DataInitializer.vpnStatus == .off else {
            return
        }
        let cloudProxies = DBUtils.all(CloudProxy.self, sorted: "createAt").map({ $0 })
        for cp in cloudProxies {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy.MM.dd"
            if let due = cp.due, let date = dateFormatter.date(from: due) {
                if (date.timeIntervalSinceNow > 0) {
                    Proxy.delete(proxy: cp)
                    DBUtils.hardDelete(cp.uuid, type: cloudProxy.self)
                }
            }
        }
        
        API.getProxySets() { (response) in
            do {
                for dic in response {
                    if let dict = dic as? [String : String], let proxy = Proxy.proxy(dictionary: dict) {
                        try DBUtils.hardDelete(proxy.uuid, type: Proxy.self)
                        Proxy.insertOrUpdate(proxy: proxy)
                        NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: kProxyServiceAdded), object: nil)
                    } else if let dict = dic as? NSDictionary, let mdict = dict.mutableCopy() as? NSMutableDictionary {
                        #if DEBUG
                            mdict.setValue("true", forKey: "ip")
                        #endif
                        if let cps = mdict["cloud"] as? NSArray {
                            var upstreamCloudProxies : [CloudProxy] = []
                            mdict.removeObject(forKey: "cloud")
                            for cp in cps {
                                if let cpdict = cp as? NSDictionary, let proxy = CloudProxy.cloudProxy(dictionary: cpdict) {
                                    if let ud = Mume.sharedUserDefaults(), "delete" == ud.string(forKey: proxy.description) {
                                        continue
                                    }
                                    upstreamCloudProxies.append(proxy)
                                }
                            }
                            if upstreamCloudProxies.count >= DataInitializer.cloudProxies.count {
                                DataInitializer.cloudProxies = upstreamCloudProxies
                            }
                        }

                        DataInitializer.serverConfigurations = mdict
                        NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: kProxyServerConfigurationUpdated), object: dic)
                    }
                }
            } catch {
            }
        }
    }
}
