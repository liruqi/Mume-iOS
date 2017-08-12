//
//  Config.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import ObjectMapper
import PotatsoModel
import RealmSwift

public enum ConfigError: Error {
    case downloadFail
    case syntaxError
}

extension ConfigError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .downloadFail:
            return "Download fail"
        case .syntaxError:
            return "Syntax error"
        }
    }
    
}

open class Config {
    
    open var groups: [ConfigurationGroup] = []
    open var proxies: [Proxy] = []
    open var ruleSets: [RuleSet] = []
    
    let realm: Realm
    var configDict: [String: AnyObject] = [:]
    
    public init() {
        realm = try! Realm()
    }
    
    open func setup(string: String) throws {
        guard let data = string.data(using: .utf8),
            data.count > 0,
            let dict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: AnyObject] else {
            throw ConfigError.syntaxError
        }
        self.configDict = dict
        try setupModels()
    }
    
    func setupModels() throws {
        do {
            try setupProxies()
            try setupRuleSets()
            try setupConfigGroups()
        } catch {
            throw error
        }
    }
    
    func setupProxies() throws {
        if let proxiesConfig = configDict["proxies"] as? [NSDictionary] {
            proxies = proxiesConfig.map({ (config) -> Proxy? in
                return Proxy.nsproxy(dictionary: config)
            }).filter { $0 != nil }.map { $0! }
            try proxies.forEach {
                try $0.validate()
                try DBUtils.add($0, inRealm: realm)
            }
        }
    }
    
    func setupRuleSets() throws {
        if let JSON = configDict["ruleSets"] as? [[String: Any]] {
            ruleSets = Mapper<RuleSet>().mapArray(JSONArray: JSON)
            try ruleSets.forEach {
                try $0.validate(inRealm: realm)
                try DBUtils.add($0, inRealm: realm)
            }
        }
    }
    
    func setupConfigGroups() throws{
        if let proxiesConfig = configDict["configGroups"] as? [[String: AnyObject]] {
            groups = try proxiesConfig.map({ (config) -> ConfigurationGroup? in
                return try ConfigurationGroup(dictionary: config, inRealm: realm)
            }).filter { $0 != nil }.map { $0! }
            try groups.forEach {
                try $0.validate()
                try DBUtils.add($0, inRealm: realm)
            }
        }
    }

}
