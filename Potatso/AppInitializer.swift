//
//  AppInitilizer.swift
//  Potatso
//
//  Created by LEI on 12/27/15.
//  Copyright © 2015 TouchingApp. All rights reserved.
//

import Foundation
import ICSMainFramework
import Fabric

let appID = "1144787928"

class AppInitializer: NSObject, AppLifeCycleProtocol {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        configAppirater()
        #if !DEBUG
            Fabric.with([Answers.self, Crashlytics.self])
        #endif
        return true
    }

    func configAppirater() {
        Appirater.setAppId(appID)
        Appirater.appLaunched(true)
        Appirater.setDaysUntilPrompt(1)
        Appirater.setUsesUntilPrompt(3)
        Appirater.setSignificantEventsUntilPrompt(1)
        Appirater.setAlwaysUseMainBundle(true)
        #if DEBUG
        Appirater.setDebug(true)
        #endif
    }
    
}
