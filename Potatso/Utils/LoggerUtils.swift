//
//  LoggerUtils.swift
//  Potatso
//
//  Created by LEI on 6/21/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation

extension ErrorProtocol {

    func log(_ message: String?) {
        if let message = message {
            NSLog("\(message): \(self)")
        }else {
            NSLog("\(self)")
        }
    }

}
