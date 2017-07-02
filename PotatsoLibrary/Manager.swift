//
//  Manager.swift
//  Potatso
//
//  Created by LEI on 4/7/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import PotatsoBase
import PotatsoModel
import RealmSwift
import NetworkExtension
import ICSMainFramework
import MMWormhole
import Alamofire
import MMDB_Swift

public enum ManagerError: Error {
    case invalidProvider
    case vpnStartFail
}

public enum VPNStatus : Int {
    case off
    case connecting
    case on
    case disconnecting
}


public let kDefaultGroupIdentifier = "defaultGroup"
public let kDefaultGroupName = "defaultGroupName"
private let statusIdentifier = "status"
public let kProxyServiceVPNStatusNotification = "kProxyServiceVPNStatusNotification"

open class Manager {
    
    open static let shared = Manager()
    
    open fileprivate(set) var vpnStatus = VPNStatus.off {
        didSet {
            NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: kProxyServiceVPNStatusNotification), object: nil)
        }
    }
    
    open let wormhole = MMWormhole(applicationGroupIdentifier: sharedGroupIdentifier, optionalDirectory: "wormhole")

    var observerAdded: Bool = false
    
    open var defaultConfigGroup: ConfigurationGroup {
        return getDefaultConfigGroup()
    }

    fileprivate init() {
        loadProviderManager { (manager) -> Void in
            if let manager = manager {
                self.updateVPNStatus(manager)
                if self.vpnStatus == .on {
                    self.observerAdded = true
                    NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: manager.connection, queue: OperationQueue.main, using: { [unowned self] (notification) -> Void in
                        self.updateVPNStatus(manager)
                        })
                }
            }
        }
        setupDefaultReaml()
        do {
            try copyGEOIPData()
        }catch{
            print("copyGEOIPData fail")
        }
        do {
            try copyTemplateData()
        } catch {
            print("copyTemplateData fail")
        }
    }
    
    func addVPNStatusObserver() {
        guard !observerAdded else{
            return
        }
        loadProviderManager { [unowned self] (manager) -> Void in
            if let manager = manager {
                self.observerAdded = true
                NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: manager.connection, queue: OperationQueue.main, using: { [unowned self] (notification) -> Void in
                    self.updateVPNStatus(manager)
                })
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func updateVPNStatus(_ manager: NEVPNManager) {
        print("updateVPNStatus:", manager.connection.status.rawValue)
        switch manager.connection.status {
        case .connected:
            self.vpnStatus = .on
        case .connecting, .reasserting:
            self.vpnStatus = .connecting
        case .disconnecting:
            self.vpnStatus = .disconnecting
        case .disconnected, .invalid:
            self.vpnStatus = .off
        }
    }

    open func switchVPN(_ completion: ((NETunnelProviderManager?, Error?) -> Void)? = nil) {
        loadProviderManager { [unowned self] (manager) in
            if let manager = manager {
                self.updateVPNStatus(manager)
            }
            let current = self.vpnStatus
            guard current != .connecting && current != .disconnecting else {
                return
            }
            if current == .off {
                self.startVPN { (manager, error) -> Void in
                    completion?(manager, error)
                }
            }else {
                self.stopVPN()
                completion?(nil, nil)
            }

        }
    }
    
    open func switchVPNFromTodayWidget(_ context: NSExtensionContext) {
        if let url = URL(string: "mume://switch") {
            context.open(url, completionHandler: nil)
        }
    }

    func copyGEOIPData() throws {
        let toURL = Potatso.sharedUrl().appendingPathComponent("GeoLite2-Country.mmdb")

        if !FileManager.default.fileExists(atPath: toURL.path) {
            let maxminddbPath = Bundle(for: MMDB.self).path(forResource: "GeoLite2-Country", ofType: "mmdb") ?? ""
            if FileManager.default.fileExists(atPath: maxminddbPath) {
                try FileManager.default.copyItem(atPath: maxminddbPath, toPath: toURL.path)
                return
            }
        }
        
            let MaxmindLastModifiedKey = "MaxmindLastModifiedKey"
            let lastM = Potatso.sharedUserDefaults().string(forKey: MaxmindLastModifiedKey) ?? "Sun, 25 Jun 2017 00:07:41 GMT"
            
            let url = URL(string: "https://mumevpn.com/ios/GeoLite2-Country.mmdb")
            let request = NSMutableURLRequest(url: url!)
            request.setValue(lastM, forHTTPHeaderField: "If-Modified-Since")
            let headers: HTTPHeaders = [
                "If-Modified-Since": lastM,
            ]
            Alamofire.request(url!, headers: headers).response { response in
                guard let data = response.data, let r = response.response else {
                    print("Download GeoLite2-Country.mmdb error: empty data")
                    return
                }
                if (r.statusCode == 200 && data.count > 1024) {
                    let result = (try? data.write(to: toURL)) != nil
                    if result {
                        let thisM = r.allHeaderFields["Last-Modified"];
                        if let m = thisM {
                            Potatso.sharedUserDefaults().set(m, forKey: MaxmindLastModifiedKey)
                        }
                        print("writeToFile GeoLite2-Country.mmdb: OK")
                    } else {
                        print("writeToFile GeoLite2-Country.mmdb: failed")
                    }
                } else {
                    print("Download GeoLite2-Country.mmdb no update maybe: " + (r.description))
                }
            }
    }

    func copyTemplateData() throws {
        guard let bundleURL = Bundle.main.url(forResource: "template", withExtension: "bundle") else {
            return
        }
        let fm = FileManager.default
        let toDirectoryURL = Potatso.sharedUrl().appendingPathComponent("httptemplate")
        if !fm.fileExists(atPath: toDirectoryURL.path) {
            try fm.createDirectory(at: toDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        for file in try fm.contentsOfDirectory(atPath: bundleURL.path) {
            let destURL = toDirectoryURL.appendingPathComponent(file)
            let dataURL = bundleURL.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: dataURL.path) {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try fm.copyItem(at: dataURL, to: destURL)
            }
        }
    }

    fileprivate func getDefaultConfigGroup() -> ConfigurationGroup {
        if let groupUUID = Potatso.sharedUserDefaults().string(forKey: kDefaultGroupIdentifier), let group = DBUtils.get(groupUUID, type: ConfigurationGroup.self) {
            return group
        } else {
            var group = ConfigurationGroup()
            do {
                if let g = DBUtils.all(ConfigurationGroup.self, sorted: "createAt").first {
                    group = g
                } else {
                    group.name = "Default".localized()
                    try DBUtils.add(group)
                }
            } catch {
                group.name = "Default".localized()
            }
            let uuid = group.uuid
            let name = group.name
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async(execute: {
                self.setDefaultConfigGroup(uuid, name: name)
            })
            return group
        }
    }
    
    open func setDefaultConfigGroup(_ id: String, name: String) {
        do {
            try regenerateConfigFiles()
        } catch {

        }
        Potatso.sharedUserDefaults().set(id, forKey: kDefaultGroupIdentifier)
        Potatso.sharedUserDefaults().set(name, forKey: kDefaultGroupName)
        Potatso.sharedUserDefaults().synchronize()
    }
    
    open func regenerateConfigFiles() throws {
        try generateGeneralConfig()
        try generateShadowsocksConfig()
        try generateHttpProxyConfig()
    }

}

extension ConfigurationGroup {

    public var isDefault: Bool {
        let defaultUUID = Manager.shared.defaultConfigGroup.uuid
        let isDefault = defaultUUID == uuid
        return isDefault
    }
    
}

extension Manager {
    
    var upstreamProxy: Proxy? {
        return defaultConfigGroup.proxies.first
    }
    
    var defaultToProxy: Bool {
        return upstreamProxy != nil && defaultConfigGroup.defaultToProxy
    }
    
    open func generateGeneralConfig() throws {
        let confURL = Potatso.sharedGeneralConfUrl()
        let json: NSDictionary = ["dns": defaultConfigGroup.dns]
        do {
            if let str = json.jsonString() {
                print("generateGeneralConfig: " + str)
                try str.write(to: confURL, atomically: true, encoding: String.Encoding.utf8)
            } else {
                print("generateGeneralConfig: empty str")
            }
        } catch {
            print("generateGeneralConfig error")
        }
    }
    
    open func generateShadowsocksConfig() throws {
        let confURL = Potatso.sharedProxyConfUrl()
        var content = ""
        if let upstreamProxy = upstreamProxy {
            if upstreamProxy.type == .Shadowsocks || upstreamProxy.type == .ShadowsocksR {
                let dict: NSDictionary = [
                    "type": upstreamProxy.type.rawValue,
                    "host": upstreamProxy.ip ?? upstreamProxy.host,
                    "port": upstreamProxy.port,
                    "password": upstreamProxy.password ?? "",
                    "authscheme": upstreamProxy.authscheme ?? "", "ota": upstreamProxy.ota, "protocol": upstreamProxy.ssrProtocol ?? "", "obfs": upstreamProxy.ssrObfs ?? "", "obfs_param": upstreamProxy.ssrObfsParam ?? ""]
                content = dict.jsonString() ?? ""
            } else if upstreamProxy.type == .Socks5 {
                let dict: NSDictionary = [
                    "type": upstreamProxy.type.rawValue,
                    "host": upstreamProxy.ip ?? upstreamProxy.host,
                    "port": upstreamProxy.port, "password": upstreamProxy.password ?? "", "authscheme": upstreamProxy.authscheme ?? ""]
                content = dict.jsonString() ?? ""
            }
        }
        print("generateShadowsocksConfig: " + content)
        try content.write(to: confURL, atomically: true, encoding: String.Encoding.utf8)
    }
    
    func generateHttpProxyConfig() throws {
        let rootUrl = Potatso.sharedUrl()
        let confDirUrl = rootUrl.appendingPathComponent("httpconf")
        let templateDirPath = rootUrl.appendingPathComponent("httptemplate").path
        let temporaryDirPath = rootUrl.appendingPathComponent("httptemporary").path
        let logDir = rootUrl.appendingPathComponent("log").path
        var maxminddbPath = rootUrl.appendingPathComponent("GeoLite2-Country.mmdb").path
        if !FileManager.default.fileExists(atPath: maxminddbPath) {
            maxminddbPath = Bundle(for: MMDB.self).path(forResource: "GeoLite2-Country", ofType: "mmdb") ?? ""
        }
        let userActionUrl = confDirUrl.appendingPathComponent("mume.action")
        let directDomainsUrl = confDirUrl.appendingPathComponent("mume.direct")
        for p in [confDirUrl.path, templateDirPath, temporaryDirPath, logDir] {
            if !FileManager.default.fileExists(atPath: p) {
                _ = try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true, attributes: [FileAttributeKey.protectionKey.rawValue: FileProtectionType.none])
            }
        }
        
        var mainConf = NSMutableDictionary()
        if let path = Bundle.main.path(forResource: "proxy", ofType: "plist"), let defaultConf = NSMutableDictionary(contentsOfFile: path) {
            mainConf = defaultConf
        }
        mainConf["confdir"] = confDirUrl.path
        mainConf["templdir"] = templateDirPath
        mainConf["logdir"] = logDir
        mainConf["mmdbpath"] = maxminddbPath
        mainConf["global-mode"] = defaultToProxy
//        mainConf["debug"] = 1024+65536+1
        mainConf["debug"] = "131071"
        if Potatso.logLevel() > 0 {
            mainConf["logfile"] = privoxyLogFile
        }
        mainConf["actionsfile"] = userActionUrl.path
        mainConf["tolerate-pipelining"] = 1
        let mainContent = mainConf.map { "\($0) \($1)"}.joined(separator: "\n")
        try mainContent.write(to: Potatso.sharedHttpProxyConfUrl(), atomically: true, encoding: String.Encoding.utf8)

        var actionContent: [String] = []
        var forwardURLRules: [String] = []
        var forwardIPRules: [String] = []
        var forwardGEOIPRules: [String] = []
        var directDomainRules = [String]()
        let rules = defaultConfigGroup.ruleSets.flatMap({ $0.rules })
        for rule in rules {
            
            switch rule.type {
            case .GeoIP:
                forwardGEOIPRules.append(rule.description)
            case .IPCIDR:
                forwardIPRules.append(rule.description)
            default:
                if rule.action == .Direct,
                    (rule.type == .DomainSuffix) {
                    directDomainRules.append(rule.value)
                } else {
                    forwardURLRules.append(rule.description)
                }
            }
        }

        if forwardURLRules.count > 0 {
            actionContent.append("{+forward-rule}")
            actionContent.append(contentsOf: forwardURLRules)
        }

        if forwardIPRules.count > 0 {
            actionContent.append("{+forward-rule}")
            actionContent.append(contentsOf: forwardIPRules)
        }

        if forwardGEOIPRules.count > 0 {
            actionContent.append("{+forward-rule}")
            actionContent.append(contentsOf: forwardGEOIPRules)
        }

        // DNS pollution
        actionContent.append("{+forward-rule}")
        actionContent.append(contentsOf: Pollution.dnsList.map({ "DNS-IP-CIDR, \($0)/32, PROXY" }))

        let userActionString = actionContent.joined(separator: "\n")
        print("[generateHttpProxyConfig] " + userActionUrl.path + ": " + userActionString)
        try userActionString.write(toFile: userActionUrl.path, atomically: true, encoding: .utf8)
        print("[generateHttpProxyConfig] " + directDomainsUrl.path + ": " + directDomainRules.joined(separator: "\n"))
        try directDomainRules.joined(separator: "\n").write(to: directDomainsUrl, atomically: true, encoding: .utf8)
    }

}

extension Manager {
    
    public func startVPN(_ complete: ((NETunnelProviderManager?, Error?) -> Void)? = nil) {
        startVPNWithOptions(nil, complete: complete)
    }
    
    fileprivate func startVPNWithOptions(_ options: [String : NSObject]?, complete: ((NETunnelProviderManager?, Error?) -> Void)? = nil) {
        // Load provider
        loadAndCreateProviderManager { (manager, error) -> Void in
            if let error = error {
                complete?(nil, error)
            }else{
                guard let manager = manager else {
                    complete?(nil, ManagerError.invalidProvider)
                    return
                }
                if manager.connection.status == .disconnected || manager.connection.status == .invalid {
                    do {
                        try manager.connection.startVPNTunnel(options: options)
                        self.addVPNStatusObserver()
                        complete?(manager, nil)
                    }catch {
                        complete?(nil, error)
                    }
                }else{
                    self.addVPNStatusObserver()
                    complete?(manager, nil)
                }
            }
        }
    }
    
    public func stopVPN() -> Bool {
        // Stop provider
        if self.vpnStatus == .off {
            return false
        }
        loadProviderManager { (manager) -> Void in
            guard let manager = manager else {
                return
            }
            manager.connection.stopVPNTunnel()
        }
        return true
    }
    
    public func postToNETunnel(message: String, complete: @escaping (Int, Data?) -> Void) {
        loadProviderManager { (manager) -> Void in
            if let session = manager?.connection as? NETunnelProviderSession,
                let data = message.data(using: String.Encoding.utf8), manager?.connection.status != .invalid
            {
                do {
                    print("postToNETunnel: " + message);
                    try session.sendProviderMessage(data) { response in
                        if let response = response {
                            print("Received from T: " + (String(data: response, encoding: .utf8) ?? ""))
                            complete(0, response)
                        } else {
                            print("Received from T: empty");
                            complete(1, nil)
                        }
                    }
                } catch {
                    complete(2, nil)
                    print("Failed to send a message to the provider")
                }
            } else {
                complete(4, nil)
            }
        }
    }
    
    fileprivate func loadAndCreateProviderManager(_ complete: @escaping (NETunnelProviderManager?, Error?) -> Void ) {
        NETunnelProviderManager.loadAllFromPreferences { [unowned self] (managers, error) -> Void in
            if let managers = managers {
                let manager: NETunnelProviderManager = (managers.count) > 0 ? managers[0] : self.createProviderManager()
                manager.isEnabled = true
                manager.localizedDescription = AppEnv.appName
                manager.protocolConfiguration?.serverAddress = AppEnv.appName
                manager.isOnDemandEnabled = true
                let quickStartRule = NEOnDemandRuleEvaluateConnection()
                quickStartRule.connectionRules = [NEEvaluateConnectionRule(matchDomains: ["connect.mume.vpn"], andAction: NEEvaluateConnectionRuleAction.connectIfNeeded)]
                manager.onDemandRules = [quickStartRule]
                manager.saveToPreferences(completionHandler: { (error) -> Void in
                    if let error = error {
                        print("Failed to saveToPreferencesWithCompletionHandler")
                        complete(nil, error)
                    }else{
                        print("Did saveToPreferencesWithCompletionHandler")
                        complete(manager, nil)
                    }
                })
            }else{
                complete(nil, error)
            }
        }
    }
    
    public func loadProviderManager(_ complete: @escaping (NETunnelProviderManager?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) -> Void in
            if let managers = managers {
                if managers.count > 0 {
                    let manager = managers[0]
                    complete(manager)
                    return
                }
            }
            complete(nil)
        }
    }
    
    fileprivate func createProviderManager() -> NETunnelProviderManager {
        let manager = NETunnelProviderManager()
        let p = NETunnelProviderProtocol()
        p.providerBundleIdentifier = "info.liruqi.potatso.tunnel"
        if let upstreamProxy = upstreamProxy {
            p.providerConfiguration = ["host": upstreamProxy.host, "port": upstreamProxy.port]
            p.serverAddress = upstreamProxy.host
        }
        manager.protocolConfiguration = p
        return manager
    }
}

