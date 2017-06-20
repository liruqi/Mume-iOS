//
//  DBUtils.swift
//  Potatso
//
//  Created by LEI on 8/3/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

open class DBUtils {

    fileprivate static func currentRealm(_ realm: Realm?) -> Realm {
        var mRealm = realm
        if mRealm == nil {
            mRealm = try! Realm()
        }
        return mRealm!
    }

    open static func add(_ object: BaseModel, update: Bool = true, setModified: Bool = true, inRealm realm: Realm? = nil) throws {
        let mRealm = currentRealm(realm)
        mRealm.beginWrite()
        if setModified {
            object.setModified()
        }
        mRealm.add(object, update: update)
        try mRealm.commitWrite()
    }

    open static func add<S: Sequence where S.Iterator.Element: BaseModel>(_ objects: S, update: Bool = true, setModified: Bool = true, inRealm realm: Realm? = nil) throws {
        let mRealm = currentRealm(realm)
        mRealm.beginWrite()
        objects.forEach({
            if setModified {
                $0.setModified()
            }
        })
        mRealm.add(objects, update: update)
        try mRealm.commitWrite()
    }

    open static func hardDelete<T: BaseModel>(_ id: String, type: T.Type, inRealm realm: Realm? = nil) throws {
        let mRealm = currentRealm(realm)
        guard let object: T = DBUtils.get(id, type: type, inRealm: mRealm) else {
            return
        }
        mRealm.beginWrite()
        mRealm.delete(object)
        try mRealm.commitWrite()
    }

    open static func hardDelete<T: BaseModel>(_ ids: [String], type: T.Type, inRealm realm: Realm? = nil) throws {
        for id in ids {
            try hardDelete(id, type: type, inRealm: realm)
        }
    }
}


// Query
extension DBUtils {

    public static func all<T: BaseModel>(_ type: T.Type, filter: String? = nil, sorted: String? = nil, inRealm realm: Realm? = nil) -> Results<T> {
        let mRealm = currentRealm(realm)
        var res = mRealm.objects(type)
        if let filter = filter, filter.characters.count > 0 {
            res = res.filter(filter)
        }
        if let sorted = sorted {
            res = res.sorted(byKeyPath: sorted)
        }
        return res
    }

    public static func get<T: BaseModel>(_ uuid: String, type: T.Type, filter: String? = nil, sorted: String? = nil, inRealm realm: Realm? = nil) -> T? {
        let mRealm = currentRealm(realm)
        var mFilter = "uuid = '\(uuid)'"
        if let filter = filter {
            mFilter += " && " + filter
        }
        var res = mRealm.objects(type).filter(mFilter)
        if let sorted = sorted {
            res = res.sorted(byKeyPath: sorted)
        }
        return res.first
    }

    public static func modify<T: BaseModel>(_ type: T.Type, id: String, inRealm realm: Realm? = nil, modifyBlock: ((Realm, T) -> Error?)) throws {
        let mRealm = currentRealm(realm)
        guard let object: T = DBUtils.get(id, type: type, inRealm: mRealm) else {
            return
        }
        mRealm.beginWrite()
        if let error = modifyBlock(mRealm, object) {
            throw error
        }
        do {
            try object.validate()
        }catch {
            mRealm.cancelWrite()
            throw error
        }
        object.setModified()
        try mRealm.commitWrite()
    }

}

// BaseModel API
extension BaseModel {

    func setModified() {
        updatedAt = Date().timeIntervalSince1970
    }

}


// Config Group API
extension ConfigurationGroup {

    public static func changeProxy(forGroupId groupId: String, proxyId: String?) throws {
        try DBUtils.modify(ConfigurationGroup.self, id: groupId) { (realm, group) -> Error? in
            group.proxies.removeAll()
            if let proxyId = proxyId, let proxy = DBUtils.get(proxyId, type: Proxy.self, inRealm: realm){
                group.proxies.append(proxy)
            }
            return nil
        }
    }

    public static func appendRuleSet(forGroupId groupId: String, rulesetId: String) throws {
        try DBUtils.modify(ConfigurationGroup.self, id: groupId) { (realm, group) -> Error? in
            if let ruleset = DBUtils.get(rulesetId, type: RuleSet.self, inRealm: realm) {
                group.ruleSets.append(ruleset)
            }
            return nil
        }
    }

    public static func changeDNS(forGroupId groupId: String, dns: String?) throws {
        try DBUtils.modify(ConfigurationGroup.self, id: groupId) { (realm, group) -> Error? in
            group.dns = dns ?? ""
            return nil
        }
    }

    public static func changeName(forGroupId groupId: String, name: String) throws {
        try DBUtils.modify(ConfigurationGroup.self, id: groupId) { (realm, group) -> Error? in
            group.name = name
            return nil
        }
    }

}

