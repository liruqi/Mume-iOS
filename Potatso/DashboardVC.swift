//
//  DashboardVC.swift
//  Potatso
//
//  Created by LEI on 7/13/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Eureka

class DashboardVC: FormViewController {

    var timer: NSTimer?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Statistics".localized()
        self.updateForm()
    }

    func updateForm() {
        form.delegate = nil
        form.removeAll()
        form +++ generateLogSection()
        form.delegate = self
        tableView?.reloadData()
    }

    func generateLogSection() -> Section {
        let section = Section("Logs".localized())
        
        section <<< SwitchRow("Open logging") {
            $0.title = "Logging".localized()
            $0.value = LoggingLevel.currentLoggingLevel != .OFF 
        }.onChange({ [unowned self] (row) in
            LoggingLevel.currentLoggingLevel = (LoggingLevel.currentLoggingLevel == .OFF ? .DEBUG : .OFF)
            self.updateForm()
        })
        
        if LoggingLevel.currentLoggingLevel != .OFF {
            section <<< LabelRow() {
                $0.title = "stderr".localized()
                }.cellSetup({ (cell, row) -> () in
                    cell.accessoryType = .DisclosureIndicator
                    cell.selectionStyle = .Default
                }).onCellSelection({ [unowned self](cell, row) -> () in
                    cell.setSelected(false, animated: true)
                    self.showLogs()
                }) <<< LabelRow() {
                    $0.title = "Privoxy".localized()
                }.cellSetup({ (cell, row) -> () in
                    cell.accessoryType = .DisclosureIndicator
                    cell.selectionStyle = .Default
                }).onCellSelection({ [unowned self](cell, row) -> () in
                    cell.setSelected(false, animated: true)
                    self.showPrivoxyLogs()
                }) <<< LabelRow() {
                    $0.title = "Shadowsocks".localized()
                }.cellSetup({ (cell, row) -> () in
                    cell.accessoryType = .DisclosureIndicator
                    cell.selectionStyle = .Default
                }).onCellSelection({ [unowned self](cell, row) -> () in
                    cell.setSelected(false, animated: true)
                    self.showShadowsocksLogs()
                })
        } else {
            // try remove log file
            let fileManager = NSFileManager.defaultManager()
            try? fileManager.removeItemAtURL(Potatso.sharedLogUrl())
            
            let rootUrl = Potatso.sharedUrl()
            let logDir = rootUrl.URLByAppendingPathComponent("log")!
            let logPath = logDir.URLByAppendingPathComponent(privoxyLogFile)
            try? fileManager.removeItemAtURL(logPath!)
        }
        return section
    }

    func showRecentRequests() {
        let vc = RecentRequestsVC()
        navigationController?.pushViewController(vc, animated: true)
    }

    func showLogs() {
        print ("stderr log: %@", Potatso.sharedLogUrl())
        navigationController?.pushViewController(LogDetailViewController(path: Potatso.sharedLogUrl().path!), animated: true)
    }

    func showShadowsocksLogs() {
        let rootUrl = Potatso.sharedUrl()
        let logPath = rootUrl.URLByAppendingPathComponent(shadowsocksLogFile)
        print ("shadowsocks log: %@", logPath!)
        navigationController?.pushViewController(LogDetailViewController(path: logPath!.path!), animated: true)
    }
    
    func showPrivoxyLogs() {
        let rootUrl = Potatso.sharedUrl()
        let logDir = rootUrl.URLByAppendingPathComponent("log")!
        let logPath = logDir.URLByAppendingPathComponent(privoxyLogFile)
        print ("privoxy log: %@", logPath!)
        navigationController?.pushViewController(LogDetailViewController(path: logPath!.path!), animated: true)
    }
    
    lazy var startTimeFormatter: NSDateFormatter = {
        let f = NSDateFormatter()
        f.dateStyle = .MediumStyle
        f.timeStyle = .MediumStyle
        return f
    }()

    lazy var durationFormatter: NSDateComponentsFormatter = {
        let f = NSDateComponentsFormatter()
        f.unitsStyle = .Abbreviated
        return f
    }()

}
