//
//  BaseModel.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift
import PotatsoBase
import CloudKit

private let version: UInt64 = 21
public var defaultRealm: Realm!

public func setupDefaultReaml() {
    var config = Realm.Configuration()
    let sharedURL = Potatso.sharedDatabaseUrl()
    
    config.fileURL = sharedURL
    config.schemaVersion = version
    config.migrationBlock = { migration, oldSchemaVersion in
        if oldSchemaVersion < version {
            migration.enumerateObjects(ofType: Proxy.className()) { oldObject, newObject in
                guard let oldObject = oldObject, let newObject = newObject else {
                    return
                }
                if oldObject["typeRaw"] as? String == ProxyType.ShadowsocksR.rawValue {
                    return
                }
                newObject["typeRaw"] = oldObject["typeRaw"] as! String
                newObject["host"] = oldObject["host"] as! String
                newObject["port"] = oldObject["port"] as! Int
                newObject["authscheme"] = oldObject["authscheme"] as? String
                newObject["user"] = oldObject["user"] as? String
                newObject["password"] = oldObject["password"] as? String
                newObject["ota"] = oldObject["ota"] as? Bool
            }
        }
    }
    Realm.Configuration.defaultConfiguration = config
    defaultRealm = try! Realm()
}


open class BaseModel: Object {
    open dynamic var uuid = UUID().uuidString
    open dynamic var createAt = Date().timeIntervalSince1970
    open dynamic var updatedAt = Date().timeIntervalSince1970

    override open static func primaryKey() -> String? {
        return "uuid"
    }
    
    static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f
    }

    open func validate() throws {
        //
    }

}

