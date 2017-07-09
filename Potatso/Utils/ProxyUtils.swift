//
//  ProxyUtils.swift
//  Potatso
//
//  Created by Ruqi on 6/25/2017.
//  Copyright © 2017 TouchingApp. All rights reserved.
//

import Foundation
import MMDB_Swift
import ICSMainFramework

class ProxyUtils {
    static let mmdb = MMDB(Potatso.sharedUrl().appendingPathComponent("GeoLite2-Country.mmdb").path)
    static func country(ip: String) -> String {
        if ip.characters.count >= 7,
            let mmdb = self.mmdb,
            let info = mmdb.lookup(ip) {
            var lang = AppEnv.languageCode
            let ipstr = (DataInitializer.serverConfigurations["ip"] != nil) ? ip : ""
            if let name = info.names[lang] {
                return info.isoCode.emojiFlag() + name + " " + ipstr
            }
            lang = lang + "-" + AppEnv.countryCode
            let name = (info.names[lang] ?? info.isoCode) + " " + ipstr
            return info.isoCode.emojiFlag() + name
        }
        return ""
    }
    
    
    // https://stackoverflow.com/questions/25890533/
    static func resolve(host: String, completion: @escaping ((String) -> Void)) {
        let queue = DispatchQueue.global(qos: .background)
        let host = host
        queue.async {
            let host = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
            CFHostStartInfoResolution(host, .addresses, nil)
            var success: DarwinBoolean = false
            if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?,
                let theAddress = addresses.firstObject as? NSData {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(theAddress.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(theAddress.length),
                               &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let numAddress = String(cString: hostname)
                    print(numAddress)
                    completion(numAddress)
                }
            }
        }
    }
}

extension Proxy {
    open func subTitle() -> String {
        if let ip = self.ip {
            return ProxyUtils.country(ip: ip) + " " + self.type.description
        }
        ProxyUtils.resolve(host: self.host) { ip in
            DispatchQueue.main.async {
                do {
                    try DBUtils.modify(Proxy.self, id: self.uuid) { (realm, proxy) -> Error? in
                        proxy.ip = ip
                        //NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: kProxyServiceAdded), object: nil)
                        return nil
                    }
                } catch {
                    print("Failed to update ip in proxy db")
                }
            }
        }
        return self.type.description
    }
    
}
