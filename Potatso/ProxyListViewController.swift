//
//  ProxyListViewController.swift
//  Potatso
//
//  Created by LEI on 5/31/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import Cartography
import Eureka

private let rowHeight: CGFloat = 107
private let kProxyCellIdentifier = "proxy"

class ProxyListViewController: FormViewController {

    var proxies: [Proxy?] = []

    let allowNone: Bool
    let chooseCallback: ((Proxy?) -> Void)?

    init(allowNone: Bool = false, chooseCallback: ((Proxy?) -> Void)? = nil) {
        self.chooseCallback = chooseCallback
        self.allowNone = allowNone
        super.init(style: .plain)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.title = "Proxy".localized()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add))
        reloadData()
    }

    func add() {
        let vc = ProxyConfigurationViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    func reloadData() {
        proxies = DBUtils.all(Proxy.self, sorted: "createAt").map({ $0 })
        if allowNone {
            proxies.insert(nil, at: 0)
        }
        form.delegate = nil
        form.removeAll()
        let section = DataInitializer.cloudProxies.count > 0 ? Section("Local".localized()) : Section()
        for proxy in proxies {
            section
                <<< ProxyRow () {
                    $0.value = proxy
                }.cellSetup({ (cell, row) -> () in
                    cell.selectionStyle = .none
                    cell.accessoryType = .disclosureIndicator
                    cell.imageView?.image = nil
                    cell.imageView?.isHidden = true
                }).onCellSelection({ [unowned self] (cell, row) in
                    cell.setSelected(false, animated: true)
                    let proxy = row.value
                    if let cb = self.chooseCallback {
                        cb(proxy)
                        self.close()
                    }else {
                        if proxy?.type != .none {
                            self.showProxyConfiguration(proxy)
                        }
                    }
                })
        }
        form +++ section
        
        if DataInitializer.cloudProxies.count > 0 {
            let cloudSection = Section("Cloud".localized())
            for proxy in DataInitializer.cloudProxies {
                cloudSection
                    <<< ProxyRow () {
                        $0.value = proxy
                        }.cellSetup({ (cell, row) -> () in
                            cell.selectionStyle = .none
                            cell.accessoryType = .disclosureIndicator
                            cell.imageView?.image = nil
                            cell.imageView?.isHidden = true
                        }).onCellSelection({ [weak self] (cell, row) in
                            cell.setSelected(false, animated: true)
                            if let cb = self?.chooseCallback {
                                cb(proxy)
                                self?.close()
                            } else {
                                if proxy.type != .none {
                                    let vc = ProxyConfigurationViewController(upstreamProxy: proxy)
                                    self?.navigationController?.pushViewController(vc, animated: true)
                                }
                            }
                            })
            }
            form +++ cloudSection
        }
        form.delegate = self
        tableView?.reloadData()
    }

    func showProxyConfiguration(_ proxy: Proxy?) {
        let vc = ProxyConfigurationViewController(upstreamProxy: proxy)
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, canEditRowAtIndexPath indexPath: IndexPath) -> Bool {
        if allowNone && indexPath.row == 0 {
            return false
        }
        return true
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAtIndexPath indexPath: IndexPath) -> UITableViewCellEditingStyle {
        if indexPath.section == 0 {
            return .delete
        }
        return .delete
    }

    func tableView(_ tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: IndexPath) {
        if editingStyle != .delete {
            return
        }
        if indexPath.section == 0 {
            guard indexPath.row < proxies.count, let item = (form[indexPath] as? ProxyRow)?.value else {
                return
            }
            do {
                try DBUtils.hardDelete(item.uuid, type: Proxy.self)
                proxies.remove(at: indexPath.row)
                form[indexPath].hidden = true
                form[indexPath].evaluateHidden()
            }catch {
                self.showTextHUD("\("Fail to delete item".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
            }
            return
        }
        
        guard indexPath.row < DataInitializer.cloudProxies.count else {
            return
        }
        DataInitializer.cloudProxies.remove(at: indexPath.row)
        form[indexPath].hidden = true
        form[indexPath].evaluateHidden()
        let item = DataInitializer.cloudProxies[indexPath.row]
        
        if let xAppSharedDefaults = Mume.sharedUserDefaults() {
            xAppSharedDefaults.set("delete", forKey: item.description)
            xAppSharedDefaults.synchronize()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView?.tableFooterView = UIView()
        tableView?.tableHeaderView = UIView()
    }

}
