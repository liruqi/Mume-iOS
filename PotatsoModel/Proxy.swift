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

    open static let ssUriMethod = "ss"
    open static let ssrUriMethod = "ssr"

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
    
    public convenience init(uri: String) throws {
        self.init()
        if let rawUri = URL(string: uri), let s = rawUri.scheme?.lowercased() {
            if let fragment = rawUri.fragment, fragment.characters.count == 36 {
                self.uuid = fragment
            }
            
            if s == "socks5" || s == "socks" {
                guard let host = rawUri.host else {
                    throw ProxyError.invalidUri
                }
                self.type = .Socks5
                self.host = host
                self.port = rawUri.port ?? 1080
                return
            }
            
            // mume://method:base64(password)@hostname:port
            if s == "mume" || s == "shadowsocks" {
                let proxyString = uri.substring(from: uri.index(uri.startIndex, offsetBy: s.characters.count))
                guard let httpsurl = URL(string: "https" + proxyString),
                    let fullAuthscheme = httpsurl.user?.lowercased(),
                    let host = httpsurl.host,
                    let port = httpsurl.port else {
                        throw ProxyError.invalidUri
                }
                
                if let pOTA = fullAuthscheme.range(of: "-auth", options: .backwards)?.lowerBound {
                    self.authscheme = fullAuthscheme.substring(to: pOTA)
                    self.ota = true
                } else {
                    self.authscheme = fullAuthscheme
                }
                self.password = base64DecodeIfNeeded(httpsurl.password ?? "")
                self.host = host
                self.port = Int(port)
                self.type = .Shadowsocks
                return
            }
            
            // Shadowsocks ss://cmM0LW1kNTp4aWFtaS5sYUBjbjEuc3hpYW1pLmNvbTo0NTQwMg==
            guard let undecodedString = rawUri.host else {
                throw ProxyError.invalidUri
            }
            self.type = .Shadowsocks
            let proxyString = base64DecodeIfNeeded(undecodedString)
            let detailsParser = "([a-zA-Z0-9-_]+):(.*)@([a-zA-Z0-9-_.]+):(\\d+)"
            if let regex = try? Regex(detailsParser),
                regex.test(proxyString),
                let parts = regex.capturedGroup(string: proxyString),
                parts.count >= 4 {
                let fullAuthscheme = parts[0].lowercased()
                if let pOTA = fullAuthscheme.range(of: "-auth", options: .backwards)?.lowerBound {
                    self.authscheme = fullAuthscheme.substring(to: pOTA)
                    self.ota = true
                } else {
                    self.authscheme = fullAuthscheme
                    self.ota = false
                }
                self.password = parts[1]
                self.host = parts[2]
                self.port = Int(parts[3]) ?? 8388
                return
            }
            
            guard let httpsURL = URL(string: "https://" + proxyString),
                let fullAuthscheme = httpsURL.user?.lowercased(),
                let host = httpsURL.host,
                let port = httpsURL.port else {
                    throw ProxyError.invalidUri
            }
            
            if let pOTA = fullAuthscheme.range(of: "-auth", options: .backwards)?.lowerBound {
                self.authscheme = fullAuthscheme.substring(to: pOTA)
                self.ota = true
            }else {
                self.authscheme = fullAuthscheme
            }
            self.password = httpsURL.password
            self.host = host
            self.port = Int(port)
            self.type = .Shadowsocks
            
            if s == Proxy.ssUriMethod {
                return
            } else if s == Proxy.ssrUriMethod || s.hasPrefix("shadowsocksr") {
                guard let queryString = httpsURL.query else {
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
        }
    }
    
    public convenience init(host: String, port: Int, authscheme: String, password: String, type: ProxyType) throws {
        self.init()
        self.host = host
        self.port = port
        self.password = password
        self.authscheme = authscheme
        self.type = type
        try validate()
    }
    
    public static func proxy(dictionary: [String: String]) -> Proxy? {
        do {
            if let uriString = dictionary["uri"] {
                return try Proxy(uri: uriString.trimmingCharacters(in: CharacterSet.whitespaces))
            }
            
            guard let host = dictionary["host"] else {
                throw ProxyError.invalidHost
            }
            guard let typeRaw = dictionary["type"]?.uppercased(), let type = ProxyType(rawValue: typeRaw) else {
                throw ProxyError.invalidType
            }
            guard let portStr = dictionary["port"], let port = Int(portStr) else {
                throw ProxyError.invalidPort
            }
            guard let encryption = dictionary["encryption"] else {
                throw ProxyError.invalidAuthScheme
            }
            guard let password = dictionary["password"] else {
                throw ProxyError.invalidPassword
            }
            return try Proxy(host: host, port: port, authscheme: encryption, password: password, type: type)
        } catch {
        }
        return nil
    }

    fileprivate func base64DecodeIfNeeded(_ proxyString: String) -> String {
        let base64String = proxyString.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let base64Charset = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        if CharacterSet(charactersIn: base64String).isSubset(of: base64Charset) {
            let padding = base64String.characters.count + (base64String.characters.count % 4 != 0 ? (4 - base64String.characters.count % 4) : 0)
            if let decodedData = Data(base64Encoded: base64String.padding(toLength: padding, withPad: "=", startingAt: 0), options: NSData.Base64DecodingOptions(rawValue: 0)), let decodedString = NSString(data: decodedData, encoding: String.Encoding.utf8.rawValue) {
                return decodedString as String
            }
            return proxyString
        }
        return proxyString
    }

    public class func uriIsShadowsocks(_ uri: String) -> Bool {
        return uri.lowercased().hasPrefix(Proxy.ssUriMethod + "://") || uri.lowercased().hasPrefix(Proxy.ssrUriMethod + "://") || uri.lowercased().hasPrefix("mume://") || uri.lowercased().hasPrefix("shadowsocks")
    }

}

public func ==(lhs: Proxy, rhs: Proxy) -> Bool {
    return lhs.uuid == rhs.uuid
}
