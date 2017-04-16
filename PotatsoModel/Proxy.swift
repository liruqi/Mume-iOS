//
//  Proxy.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift
import CloudKit

public enum ProxyType: String {
    case Shadowsocks = "Shadowsocks"
    case ShadowsocksR = "ShadowsocksR"
    case Https = "HTTPS"
    case Socks5 = "SOCKS5"
    case None = "NONE"
}

extension ProxyType: CustomStringConvertible {
    
    public var description: String {
        return rawValue
    }

    public var isShadowsocks: Bool {
        return self == .Shadowsocks || self == .ShadowsocksR
    }
    
}

public enum ProxyError: Error {
    case invalidType
    case invalidName
    case invalidHost
    case invalidPort
    case invalidAuthScheme
    case nameAlreadyExists
    case invalidUri
    case invalidPassword
}

extension ProxyError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .invalidType:
            return "Invalid type"
        case .invalidName:
            return "Invalid name"
        case .invalidHost:
            return "Invalid host"
        case .invalidAuthScheme:
            return "Invalid encryption"
        case .invalidUri:
            return "Invalid uri"
        case .nameAlreadyExists:
            return "Name already exists"
        case .invalidPassword:
            return "Invalid password"
        case .invalidPort:
            return "Invalid port"
        }
    }
    
}

open class Proxy: BaseModel {
    open dynamic var typeRaw = ProxyType.Shadowsocks.rawValue
    open dynamic var host = ""
    open dynamic var port = 0
    open dynamic var authscheme: String?  // method in SS
    open dynamic var user: String?
    open dynamic var password: String?
    open dynamic var ota: Bool = false
    open dynamic var ssrProtocol: String?
    open dynamic var ssrObfs: String?
    open dynamic var ssrObfsParam: String?

    open static let ssUriPrefix = "ss://"
    open static let ssrUriPrefix = "ssr://"

    open static let ssrSupportedProtocol = [
        "origin",
        "verify_simple",
        "auth_simple",
        "auth_sha1",
        "auth_sha1_v2"
    ]

    open static let ssrSupportedObfs = [
        "plain",
        "http_simple",
        "tls1.0_session_auth",
        "tls1.2_ticket_auth"
    ]

    open static let ssSupportedEncryption = [
        "table",
        "rc4",
        "rc4-md5",
        "aes-128-cfb",
        "aes-192-cfb",
        "aes-256-cfb",
        "bf-cfb",
        "camellia-128-cfb",
        "camellia-192-cfb",
        "camellia-256-cfb",
        "cast5-cfb",
        "des-cfb",
        "idea-cfb",
        "rc2-cfb",
        "seed-cfb",
        "salsa20",
        "chacha20",
        "chacha20-ietf"
    ]

    open override static func indexedProperties() -> [String] {
        return ["host","port"]
    }

    open override func validate() throws {
        guard let _ = ProxyType(rawValue: typeRaw)else {
            throw ProxyError.invalidType
        }
        guard host.characters.count > 0 else {
            throw ProxyError.invalidHost
        }
        guard port > 0 && port <= Int(UINT16_MAX) else {
            throw ProxyError.invalidPort
        }
        switch type {
        case .Shadowsocks, .ShadowsocksR:
            guard let _ = authscheme else {
                throw ProxyError.invalidAuthScheme
            }
        default:
            break
        }
    }

}

// Public Accessor
extension Proxy {
    
    public var type: ProxyType {
        get {
            return ProxyType(rawValue: typeRaw) ?? .Shadowsocks
        }
        set(v) {
            typeRaw = v.rawValue
        }
    }
    
    public var uri: String {
        switch type {
        case .Shadowsocks:
            if let authscheme = authscheme, let password = password {
                return "ss://\(authscheme):\(password)@\(host):\(port)"
            }
        case .Socks5:
            if let user = user, let password = password {
                return "socks5://\(user):\(password)@\(host):\(port)"
            }
            return "socks5://\(host):\(port)" // TODO: support username/password
        default:
            break
        }
        return ""
    }
    open override var description: String {
        return String.init(format: "%@:%d", host, port)
    }
    
}

// Import
extension Proxy {
    
    public convenience init(dictionary: [String: Any]) throws {
        self.init()
        if let uriString = dictionary["uri"] as? String, let rawUri = URL(string: uriString) {
            if let s = rawUri.scheme?.lowercased(),
                s == "socks5" || s == "socks" {
                guard let host = rawUri.host else {
                    throw ProxyError.invalidUri
                }
                self.type = .Socks5
                self.host = host
                self.port = rawUri.port ?? 1080
                return
            }
            // Shadowsocks
            guard let undecodedString = rawUri.host,
                let proxyString = base64DecodeIfNeeded(undecodedString),
                let url = URL(string: "https://" + proxyString),
                let fullAuthscheme = url.user?.lowercased(),
                let host = url.host,
                let port = url.port else {
                    throw ProxyError.invalidUri
            }
            
            if let pOTA = fullAuthscheme.range(of: "-auth", options: .backwards)?.lowerBound {
                self.authscheme = fullAuthscheme.substring(to: pOTA)
                self.ota = true
            }else {
                self.authscheme = fullAuthscheme
            }
            self.password = url.password
            self.host = host
            self.port = Int(port)
            self.type = .Shadowsocks
            
            if uriString.lowercased().hasPrefix(Proxy.ssUriPrefix) {
                return
            } else if uriString.lowercased().hasPrefix(Proxy.ssrUriPrefix) {
                guard let queryString = url.query else {
                    throw ProxyError.invalidUri
                }
                var hostString: String = proxyString
                if let queryMarkIndex = proxyString.range(of: "?", options: .backwards)?.lowerBound {
                    hostString = proxyString.substring(to: queryMarkIndex)
                }
                if let hostSlashIndex = hostString.range(of: "/", options: .backwards)?.lowerBound {
                    hostString = hostString.substring(to: hostSlashIndex)
                }
                let hostComps = hostString.components(separatedBy: ":")
                guard hostComps.count == 6 else {
                    throw ProxyError.invalidUri
                }
                self.host = hostComps[0]
                guard let p = Int(hostComps[1]) else {
                    throw ProxyError.invalidPort
                }
                self.port = p
                self.ssrProtocol = hostComps[2]
                self.authscheme = hostComps[3]
                self.ssrObfs = hostComps[4]
                self.password = base64DecodeIfNeeded(hostComps[5])
                for queryComp in queryString.components(separatedBy: "&") {
                    let comps = queryComp.components(separatedBy: "=")
                    guard comps.count == 2 else {
                        continue
                    }
                    switch comps[0] {
                    case "obfsparam":
                        self.ssrObfsParam = comps[1]
                    default:
                        continue
                    }
                }
                self.type = .ShadowsocksR
            } else {
                // Not supported yet
                throw ProxyError.invalidUri
            }
        }else {
            guard let host = dictionary["host"] as? String else{
                throw ProxyError.invalidHost
            }
            guard let typeRaw = (dictionary["type"] as? String)?.uppercased(), let type = ProxyType(rawValue: typeRaw) else{
                throw ProxyError.invalidType
            }
            guard let portStr = (dictionary["port"] as? String), let port = Int(portStr) else{
                throw ProxyError.invalidPort
            }
            guard let encryption = dictionary["encryption"] as? String else{
                throw ProxyError.invalidAuthScheme
            }
            guard let password = dictionary["password"] as? String else{
                throw ProxyError.invalidPassword
            }
            self.host = host
            self.port = port
            self.password = password
            self.authscheme = encryption
            self.type = type
        }
        try validate()
    }

    fileprivate func base64DecodeIfNeeded(_ proxyString: String) -> String? {
        if let _ = proxyString.range(of: ":")?.lowerBound {
            return proxyString
        }
        let base64String = proxyString.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = base64String.characters.count + (base64String.characters.count % 4 != 0 ? (4 - base64String.characters.count % 4) : 0)
        if let decodedData = Data(base64Encoded: base64String.padding(toLength: padding, withPad: "=", startingAt: 0), options: NSData.Base64DecodingOptions(rawValue: 0)), let decodedString = NSString(data: decodedData, encoding: String.Encoding.utf8.rawValue) {
            return decodedString as String
        }
        return nil
    }

    public class func uriIsShadowsocks(_ uri: String) -> Bool {
        return uri.lowercased().hasPrefix(Proxy.ssUriPrefix) || uri.lowercased().hasPrefix(Proxy.ssrUriPrefix)
    }

}

public func ==(lhs: Proxy, rhs: Proxy) -> Bool {
    return lhs.uuid == rhs.uuid
}
