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
import ICSMainFramework

struct API {

    static let URL = "https://api.mume.red/"

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
    
    static func getJSON(url: URL, callback: @escaping (Data, Error?) -> Void) {
        let lang = Locale.preferredLanguages[0]
        let versionCode = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        NSLog("API.getImportData ===> lang: \(lang), version: \(versionCode)")
        let parameters: Parameters = ["lang": lang, "version": versionCode]
        Alamofire.SessionManager.default.request(url, parameters: parameters)
            .responseData { response in
                if let JSON = response.data {
                    print("API.getImportData: " + (String(data: JSON, encoding: .ascii) ?? ""))
                    Crashlytics.sharedInstance().setObjectValue(JSON, forKey: "getImportData")
                    callback(JSON, nil)
                } else {
                    Crashlytics.sharedInstance().setObjectValue(response.data ?? "response.data", forKey: "getImportData")
                    callback(Data(), response.error)
                }
        }
    }
    
    static func getRuleSets(_ callback: @escaping ([RuleSet]) -> Void) {
        let lang = Locale.preferredLanguages[0]
        let network = (DataInitializer.reachabilityManager?.networkReachabilityStatus.description()) ?? ""
        let vi = (UIDevice.current.identifierForVendor?.uuidString) ?? ""
        var parameters: Parameters = ["lang": lang, "version": AppEnv.version, "build": AppEnv.build, "identifierForVendor": vi, "network": network, "appstore": AppEnv.isAppStore]
        let networkInfo = CTTelephonyNetworkInfo()
        if let carrier = networkInfo.subscriberCellularProvider {
            parameters["carrierName"] = carrier.carrierName
            parameters["mobileCountryCode"] = carrier.mobileCountryCode
            parameters["mobileNetworkCode"] = carrier.mobileNetworkCode
            parameters["isoCountryCode"] = carrier.isoCountryCode
        }
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
                    callback([])
                }
                
            }
    }
    
    static func getProxySets(_ callback: @escaping (NSArray) -> Void) {
        let lang = Locale.preferredLanguages[0]
        let kCloudProxySets = "kCloudProxySets" + AppEnv.version
        
        let network = (DataInitializer.reachabilityManager?.networkReachabilityStatus.description()) ?? ""
        let vi = (UIDevice.current.identifierForVendor?.uuidString) ?? ""
        var parameters: Parameters = ["lang": lang, "version": AppEnv.version, "build": AppEnv.build, "identifierForVendor": vi, "network": network, "appstore": AppEnv.isAppStore]
        #if DEBUG
        parameters["debug"] = 1
        #endif
        let networkInfo = CTTelephonyNetworkInfo()
        if let carrier = networkInfo.subscriberCellularProvider {
            parameters["carrierName"] = carrier.carrierName
            parameters["mobileCountryCode"] = carrier.mobileCountryCode
            parameters["mobileNetworkCode"] = carrier.mobileNetworkCode
            parameters["isoCountryCode"] = carrier.isoCountryCode
        }
        Alamofire.request("https://mumevpn.com/shared.php", parameters: parameters)
            .responseJSON { response in
                print(response.response ?? "response.response") // URL response
                print(response.data ?? "response.data")     // server data
                print(response.result.value ?? "empty")   // result of response serialization
                if let JSON = response.result.value as? NSArray {
                    Potatso.sharedUserDefaults().set(response.data, forKey: kCloudProxySets)
                    Crashlytics.sharedInstance().setObjectValue(JSON, forKey: "getProxySets")
                    callback(JSON)
                    return
                }
                
                Crashlytics.sharedInstance().setObjectValue(response.data ?? "response.data", forKey: "getProxySetsFailed")
                if let data = Potatso.sharedUserDefaults().data(forKey: kCloudProxySets) {
                    do {
                        if let JSON = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? NSArray {
                            callback(JSON)
                            return
                        }
                    } catch {
                        print("Local deserialization failed")
                    }
                }
        }
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


extension Alamofire.Request {
    fileprivate static func logError(_ error: NSError, request: NSURLRequest, response: URLResponse?) {
        NSLog("ObjectMapperSerializer failure: \(error), request: \(request.debugDescription), response: \(response.debugDescription)")
    }
}
