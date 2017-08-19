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

    var timer: Timer?

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
            $0.value = Potatso.logLevel() > 0
        }.onChange({ [unowned self] (row) in
            Potatso.setLogLevel((Potatso.logLevel() > 0 ? 0 : 1))
            self.updateForm()
        })
        
        if Potatso.logLevel() > 0 {
            section <<< LabelRow() {
                $0.title = "PacketTunnel".localized()
                }.cellSetup({ (cell, row) -> () in
                    cell.accessoryType = .disclosureIndicator
                    cell.selectionStyle = .default
                }).onCellSelection({ [unowned self](cell, row) -> () in
                    cell.setSelected(false, animated: true)
                    self.showLogs()
                }) <<< LabelRow() {
                    $0.title = "Privoxy".localized()
                }.cellSetup({ (cell, row) -> () in
                    cell.accessoryType = .disclosureIndicator
                    cell.selectionStyle = .default
                }).onCellSelection({ [unowned self](cell, row) -> () in
                    cell.setSelected(false, animated: true)
                    self.showPrivoxyLogs()
                }) <<< LabelRow() {
                    $0.title = "Shadowsocks".localized()
                }.cellSetup({ (cell, row) -> () in
                    cell.accessoryType = .disclosureIndicator
                    cell.selectionStyle = .default
                }).onCellSelection({ [unowned self](cell, row) -> () in
                    cell.setSelected(false, animated: true)
                    self.showShadowsocksLogs()
                })
        } else {
            // try remove log file
            let fileManager = FileManager.default
            try? fileManager.removeItem(at: Potatso.sharedLogUrl())
            
            let rootUrl = Potatso.sharedUrl()
            let logDir = rootUrl.appendingPathComponent("log")
            let logPath = logDir.appendingPathComponent(privoxyLogFile)
            try? fileManager.removeItem(at: logPath)
        }
        return section
    }

    func showRecentRequests() {
        let vc = RecentRequestsVC()
        navigationController?.pushViewController(vc, animated: true)
    }

    func showLogs() {
        print ("tunnel log: ", Potatso.sharedLogUrl())
        navigationController?.pushViewController(LogDetailViewController(path: Potatso.sharedLogUrl().path), animated: true)
    }

    func showShadowsocksLogs() {
        let rootUrl = Potatso.sharedUrl()
        let logPath = rootUrl.appendingPathComponent(shadowsocksLogFile)
        print ("shadowsocks log: ", logPath)
        navigationController?.pushViewController(LogDetailViewController(path: logPath.path), animated: true)
    }
    
    func showPrivoxyLogs() {
        let rootUrl = Potatso.sharedUrl()
        let logDir = rootUrl.appendingPathComponent("log")
        let logPath = logDir.appendingPathComponent(privoxyLogFile)
        print ("privoxy log: ", logPath)
        navigationController?.pushViewController(LogDetailViewController(path: logPath.path), animated: true)
    }
    
    lazy var startTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    lazy var durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

}
