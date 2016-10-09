//
//  ICloudSyncService.swift
//  Potatso
//
//  Created by LEI on 8/2/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import CloudKit
import PSOperations
import PotatsoModel
import Async

class ICloudSyncService: SyncServiceProtocol {

    let operationQueue = OperationQueue()

    init() {

    }

    func setup(completion: (ErrorType? -> Void)?) {
        NSLog(">>>>>> Setuping iCloud sync service")
        let setupOp = ICloudSetupOperation { [weak self] (error) in
            if let e = error {
                NSLog(">>>>>> Setuping iCloud sync service with error: \(e)")
            } else {
                NSLog(">>>>>> Setuping iCloud sync service with success")
                self?.subscribeNotification()
            }
            completion?(error)
        }
        operationQueue.addOperation(setupOp)
    }

    func sync(manually: Bool = false, completion: (ErrorType? -> Void)?) {
        NSLog(">>>>>>>>>> iCloud sync start")

        let pushLocalChangesOperation = PushLocalChangesOperation(zoneID: potatsoZoneId)
        let pushLocalChangesObserver = BlockObserver { [weak self] operation, error in
            if let _ = error.first {
                NSLog("<<< pushLocalChangesOperation finished with error: \(error)")
            } else {
                NSLog("<<< pushLocalChangesOperation finished with success")
            }
            self?.finishSync(error.first, completion: completion)
        }
        pushLocalChangesOperation.addObserver(pushLocalChangesObserver)

        let fetchCloudChangesOperation = FetchCloudChangesOperation(zoneID: potatsoZoneId)
        let fetchCloudChangesObserver = BlockObserver { [weak self] operation, error in
            if let error = error.first {
                NSLog("<<< fetchCloudChangesOperation finished with error: \(error)")
                self?.finishSync(error, completion: completion)
                return
            } else {
                NSLog("<<< fetchCloudChangesOperation finished with success")
            }
            self?.operationQueue.addOperation(pushLocalChangesOperation)
        }
        fetchCloudChangesOperation.addObserver(fetchCloudChangesObserver)

        setup { [weak self] (error) in
            if let error = error {
                self?.finishSync(error, completion: completion)
                return
            } else {
                self?.operationQueue.addOperation(fetchCloudChangesOperation)
            }
        }
    }

    func finishSync(error: ErrorType?, completion: (ErrorType? -> Void)?) {
        if let error = error {
            NSLog("<<<<<<<<<< iCloud sync finished with error: \(error)")
        } else {
            NSLog("<<<<<<<<<< iCloud sync finished with success")
        }
        Async.main {
            completion?(error)
        }
    }

    func subscribeNotification() {
        NSLog("subscribing cloudkit database changes...")
        let subscription = CKSubscription(zoneID: potatsoZoneId, subscriptionID: potatsoSubscriptionId, options: CKSubscriptionOptions(rawValue: 0))
        let info = CKNotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        potatsoDB.saveSubscription(subscription) { (sub, error) in
            if let error = error {
                NSLog("subscribe cloudkit database changes error: \(error.localizedDescription)")
            } else {
                NSLog("subscribe cloudkit database changes success")
            }
        }
    }

    func unsubscribeNotification() {
        NSLog("unsubscribing cloudkit database changes...")
        potatsoDB.deleteSubscriptionWithID(potatsoSubscriptionId) { (id, error) in
            if let error = error {
                NSLog("unsubscribe cloudkit database changes error: \(error.localizedDescription)")
            } else {
                NSLog("unsubscribe cloudkit database changes success")
            }
        }
    }

    func stop() {
        unsubscribeNotification()
    }

}
