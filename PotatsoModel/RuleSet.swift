//
//  RuleSet.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift
import ObjectMapper

public enum RuleSetError: Error {
    case invalidRuleSet
    case emptyName
    case nameAlreadyExists
}

extension RuleSetError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .invalidRuleSet:
            return "Invalid rule set"
        case .emptyName:
            return "Empty name"
        case .nameAlreadyExists:
            return "Name already exists"
        }
    }
    
}

public final class RuleSet: BaseModel {
    public dynamic var editable = true
    public dynamic var name = ""
    public dynamic var remoteUpdatedAt: TimeInterval = Date().timeIntervalSince1970
    public dynamic var desc = ""
    public dynamic var ruleCount = 0
    public dynamic var rulesJSON = ""
    public dynamic var isSubscribe = false
    public dynamic var isOfficial = false

    fileprivate var cachedRules: [Rule]? = nil

    public var rules: [Rule] {
        get {
            if let cachedRules = cachedRules {
                return cachedRules
            }
            updateCahcedRules()
            return cachedRules!
        }
        set {
            let json = (newValue.map({ $0.json }) as NSArray).jsonString() ?? ""
            rulesJSON = json
            updateCahcedRules()
            ruleCount = newValue.count
        }
    }

    public func validate(inRealm realm: Realm) throws {
        guard name.characters.count > 0 else {
            throw RuleSetError.emptyName
        }
    }

    fileprivate func updateCahcedRules() {
        guard let jsonArray = rulesJSON.jsonArray() as? [[String: AnyObject]] else {
            cachedRules = []
            return
        }
        cachedRules = jsonArray.flatMap({ Rule(json: $0) })
    }

    public func addRule(_ rule: Rule) {
        var newRules = rules
        newRules.append(rule)
        rules = newRules
    }

    public func insertRule(_ rule: Rule, atIndex index: Int) {
        var newRules = rules
        newRules.insert(rule, at: index)
        rules = newRules
    }

    public func removeRule(atIndex index: Int) {
        var newRules = rules
        newRules.remove(at: index)
        rules = newRules
    }

    public func move(_ fromIndex: Int, toIndex: Int) {
        var newRules = rules
        let rule = newRules[fromIndex]
        newRules.remove(at: fromIndex)
        insertRule(rule, atIndex: toIndex)
        rules = newRules
    }
    
    public override static func indexedProperties() -> [String] {
        return ["name"]
    }
    
}

public func ==(lhs: RuleSet, rhs: RuleSet) -> Bool {
    return lhs.uuid == rhs.uuid
}

extension RuleSet: Mappable {
    
    public convenience init?(map: Map) {
        self.init()
        guard let rulesJSON = map.JSON["rules"] else {
            return
        }
        var rules: [Rule] = []
        if let parsedObject = Mapper<Rule>().mapArray(JSONObject: rulesJSON){
            rules.append(contentsOf: parsedObject)
        }
        self.rules = rules
    }
    
    // Mappable
    public func mapping(map: Map) {
        uuid      <- map["id"]
        name      <- map["name"]
        createAt  <- (map["created_at"], DateTransform())
        remoteUpdatedAt  <- (map["updated_at"], DateTransform())
        desc      <- map["description"]
        ruleCount <- map["rule_count"]
        isOfficial <- map["is_official"]
    }
}


struct DateTransform: TransformType {
    
    func transformFromJSON(_ value: Any?) -> Double? {
        guard let dateStr = value as? String else {
            return Date().timeIntervalSince1970
        }
        if #available(iOS 10.0, *) {
            return ISO8601DateFormatter().date(from: dateStr)?.timeIntervalSince1970
        } else {
            return Date().timeIntervalSince1970
        }
    }
    
    func transformToJSON(_ value: Double?) -> Any? {
        guard let v = value else {
            return nil
        }
        let date = Date(timeIntervalSince1970: v)
        if #available(iOS 10.0, *) {
            return ISO8601DateFormatter().string(from: date)
        } else {
            return nil
        }
    }
    
}

