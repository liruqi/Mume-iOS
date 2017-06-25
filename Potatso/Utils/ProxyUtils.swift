//
//  ProxyUtils.swift
//  Potatso
//
//  Created by Ruqi on 6/25/2017.
//  Copyright © 2017 TouchingApp. All rights reserved.
//

import Foundation
import MMDB_Swift

class ProxyUtils {
    static let mmdb = MMDB()
    static func country(ip: String) -> String {
        if ip.characters.count >= 7,
            let mmdb = self.mmdb,
            let info = mmdb.lookup(ip) {
            let lang = Locale.preferredLanguages.first ?? "zh-CN"
            let name = info.names[lang] ?? info.isoCode
            return name + info.isoCode.emojiFlag()
        }
        return ""
    }
}

extension Proxy {
    open func subTitle() -> String {
        return self.type.description + " " + ProxyUtils.country(ip: self.ip)
    }
}
