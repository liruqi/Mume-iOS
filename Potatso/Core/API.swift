//
//  API.swift
//  Potatso
//
//  Created by LEI on 6/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import Alamofire
import ObjectMapper

struct API {

    static let URL = "https://api.liruqi.info/"

    enum Path {
        case ruleSets
        case ruleSet(String)

        var url: String {
            let path: String
            switch self {
            case .ruleSets:
                path = "mume-rulesets.php"
            case .ruleSet(let uuid):
                path = "ruleset/\(uuid).json"
            }
            return API.URL + path
        }
    }
    
    static func getRuleSets(_ callback: @escaping ([RuleSet]) -> Void) {
        let lang = Locale.preferredLanguages[0]
        let versionCode = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        NSLog("API.getRuleSets ===> lang: \(lang), version: \(versionCode)")
        let parameters: Parameters = ["lang": lang, "version": versionCode]
        Alamofire.SessionManager.default.request(Path.ruleSets.url, parameters: parameters)
            .responseJSON { response in
                if let JSON = response.result.value {
                    print("JSON: \(JSON)")
                    Crashlytics.sharedInstance().setObjectValue(JSON, forKey: "getRuleSets")
                    if let parsedObject = Mapper<RuleSet>().mapArray(JSONObject: JSON) {
                        callback(parsedObject)
                        return
                    }
                } else {
                    Crashlytics.sharedInstance().setObjectValue(response.data ?? "response.data", forKey: "getRuleSetsFailed")
                }
                
            }
    }
    
    static func getProxySets(_ callback: @escaping ([Dictionary<String, String>]) -> Void) {
        let lang = Locale.preferredLanguages[0]
        let versionCode = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        let kCloudProxySets = "kCloudProxySets" + versionCode
        NSLog("API.getRuleSets ===> lang: \(lang), version: \(versionCode)")
        
        if let data = Potatso.sharedUserDefaults().data(forKey: kCloudProxySets) {
            do {
                if let JSON = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [Dictionary<String, String>] {
                    return callback(JSON)
                }
            } catch {
                print("Local deserialization failed")
            }
        }
        Alamofire.request("https://mumevpn.com/shared.php", parameters: ["lang": lang, "version": versionCode])
            .responseJSON { response in
                print(response.response ?? "response.response") // URL response
                print(response.data ?? "response.data")     // server data
                print(response.result)   // result of response serialization
                Potatso.sharedUserDefaults().set(response.data, forKey: kCloudProxySets)
                if let JSON = response.result.value as? [Dictionary<String, String>] {
                    Crashlytics.sharedInstance().setObjectValue(JSON, forKey: "getProxySets")
                    callback(JSON)
                } else {
                    Crashlytics.sharedInstance().setObjectValue(response.data ?? "response.data", forKey: "getProxySetsFailed")
                }
        }
    }
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

extension RuleSet {

    static func addRemoteObject(_ ruleset: RuleSet, update: Bool = true) throws {
        ruleset.isSubscribe = true
        ruleset.editable = false
        let id = ruleset.uuid
        guard let local = DBUtils.get(id, type: RuleSet.self) else {
            try DBUtils.add(ruleset)
            return
        }
        if local.remoteUpdatedAt == ruleset.remoteUpdatedAt {
            return
        }
        try DBUtils.add(ruleset)
    }

    static func addRemoteArray(_ rulesets: [RuleSet], update: Bool = true) throws {
        for ruleset in rulesets {
            try addRemoteObject(ruleset, update: update)
        }
    }

}

extension Rule: Mappable {

    public convenience init?(map: Map) {
        guard let pattern = map.JSON["pattern"] as? String else {
            return nil
        }
        guard let actionStr = map.JSON["action"] as? String, let action = RuleAction(rawValue: actionStr) else {
            return nil
        }
        guard let typeStr = map.JSON["type"] as? String, let type = MMRuleType(rawValue: typeStr) else {
            return nil
        }
        self.init(type: type, action: action, value: pattern)
    }
    
    public func mapping(map: Map) {
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

extension Alamofire.Request {
    fileprivate static func logError(_ error: NSError, request: NSURLRequest, response: URLResponse?) {
        NSLog("ObjectMapperSerializer failure: \(error), request: \(request.debugDescription), response: \(response.debugDescription)")
    }
}
