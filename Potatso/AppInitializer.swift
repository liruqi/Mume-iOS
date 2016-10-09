//
//  AppInitilizer.swift
//  Potatso
//
//  Created by LEI on 12/27/15.
//  Copyright © 2015 TouchingApp. All rights reserved.
//

import Foundation
import ICSMainFramework
import Appirater
import Fabric

let appID = "1144787928"

class AppInitializer: NSObject, AppLifeCycleProtocol {
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        configAppirater()
        #if !DEBUG
            Fabric.with([Answers.self, Crashlytics.self])
        #endif
        configHelpShift()
        return true
    }

    func configAppirater() {
        Appirater.setAppId(appID)
    }

    func configHelpShift() {
        HelpshiftCore.initializeWithProvider(HelpshiftAll.sharedInstance())
        HelpshiftCore.installForApiKey(HELPSHIFT_KEY, domainName: HELPSHIFT_DOMAIN, appID: HELPSHIFT_ID)
    }
    
}