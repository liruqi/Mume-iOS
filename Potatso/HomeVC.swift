//
//  IndexViewController.swift
//  Potatso
//
//  Created by LEI on 5/27/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoLibrary
import PotatsoModel
import Eureka
import Cartography
import Async

private let kFormName = "name"
private let kFormDNS = "dns"
private let kFormProxies = "proxies"
private let kFormDefaultToProxy = "defaultToProxy"
public let kProxyServicePermissionChanged = "kProxyServicePermissionChanged"
public let kProxyServerConfigurationUpdated = "kProxyServerConfigurationUpdated"

class HomeVC: FormViewController, UINavigationControllerDelegate, HomePresenterProtocol, UITextFieldDelegate {

    let presenter = HomePresenter()
    var proxies: [Proxy] = []

    var ruleSetSection: Section!

    var status: VPNStatus {
        didSet(o) {
            updateConnectButton()
            DataInitializer.vpnStatus = self.status
            if let proxy = self.presenter.proxy {
                DataInitializer.selectedProxy = proxy.description
            }
        }
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.status = Manager.shared.vpnStatus
        print ("HomeVC.init: ", self.status.rawValue)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        presenter.bindToVC(self)
        presenter.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Fix a UI stuck bug
        navigationController?.delegate = self
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateForm),
                                               name: NSNotification.Name(rawValue: kProxyServiceAdded),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleConnectButtonPressed),
                                               name: NSNotification.Name(rawValue: kProxyServicePermissionChanged),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onServerConfigurationUpdated),
                                               name: NSNotification.Name(rawValue: kProxyServerConfigurationUpdated),
                                               object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.titleView = titleButton
        // Post an empty message so we could attach to packet tunnel process
        Manager.shared.postToNETunnel(message: "Hello", complete: { code, data in
            if let data = data, let ip = String(data: data, encoding: .utf8) {
                print(code, ip)
            }
        })
        
        updateForm()
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: "List".templateImage, style: .plain, target: presenter, action: #selector(HomePresenter.chooseConfigGroups))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addProxy(_:)))
        startTimer()
        if let proxy = presenter.proxy {
            Crashlytics.sharedInstance().setObjectValue(proxy.description, forKey: "ShadowsocksConfig")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }
    
    func addProxy(_ sender: AnyObject) {
        let alert = UIAlertController(title: "Add Proxy".localized(), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Import From QRCode".localized(), style: .default, handler: { (action) in
            let importer = Importer(vc: self)
            importer.importConfigFromQRCode()
        }))
        alert.addAction(UIAlertAction(title: "Manual Settings".localized(), style: .default, handler: { (action) in
            let vc = ProxyConfigurationViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .cancel, handler: nil))
        if let presenter = alert.popoverPresentationController {
            if let rightBtn : View = navigationItem.rightBarButtonItem?.value(forKey: "view") as? View {
                presenter.sourceView = rightBtn
                presenter.sourceRect = rightBtn.bounds
            } else {
                presenter.sourceView = titleButton
                presenter.sourceRect = titleButton.bounds
            }
        }
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: - HomePresenter Protocol

    func handleRefreshUI(_ error: Error?) {
        if presenter.group.isDefault {
            let vpnStatus = Manager.shared.vpnStatus
            if status == .connecting {
                if nil == error {
                    if vpnStatus == .off {
                        return
                    }
                }
            }
            if status == .disconnecting {
                if vpnStatus == .on {
                    return
                }
            }
            status = vpnStatus
        } else {
            status = .off
        }
        updateTitle()
    }

    func updateTitle() {
        titleButton.setTitle(presenter.group.name, for: UIControlState())
        titleButton.sizeToFit()
    }

    func updateForm() {
        form.delegate = nil
        form.removeAll()

        form.delegate = nil
        form.removeAll()
        
        form +++ generateConnectionSection()

        let section = Section("Proxy".localized())
        defer {
            form +++ section
            
            form +++ generateRuleSetSection()
            form.delegate = self
            tableView?.reloadData()
        }
        proxies = DBUtils.all(Proxy.self, sorted: "createAt").map({ $0 })
        if proxies.count == 0 {
            section
                <<< ProxyRow() {
                    $0.value = nil
                    $0.cellStyle = UITableViewCellStyle.subtitle
                    }.cellSetup({ (cell, row) -> () in
                        cell.selectionStyle = .none
                        cell.accessoryType = .none
                        cell.imageView?.isHidden = false
                    })
            return
        }
        if nil == self.presenter.proxy {
            self.presenter.change(proxy: proxies[0], status: self.status)
        }
        for proxy in proxies {
            section
                <<< ProxyRow() {
                    $0.value = proxy
                    $0.cellStyle = UITableViewCellStyle.subtitle
                    }.cellSetup({ (cell, row) -> () in
                        cell.selectionStyle = .none
                        cell.setSelected(self.presenter.proxy?.uuid == proxy.uuid, animated: false)
                        cell.accessoryType = .disclosureIndicator
                    }).onCellSelection({ [unowned self] (cell, row) in
                        guard let proxy = row.value else {
                            return
                        }
                        row.updateCell()
                        if (self.presenter.proxy?.uuid == proxy.uuid) {
                            if proxy.type != .none {
                                let vc = ProxyConfigurationViewController(upstreamProxy: proxy, readOnly: true)
                                self.navigationController?.pushViewController(vc, animated: true)
                            }
                            return
                        }
                        if self.presenter.change(proxy: proxy, status: self.status) {
                            self.updateTitle()
                            self.updateForm()
                        }
                    })
        }
    }

    func updateConnectButton() {
        tableView?.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
    }

    // MARK: - Form

    func generateConnectionSection() -> Section {
        let proxySection = Section("Connect".localized())
        var reloading = true

        proxySection <<< SwitchRow("connection") {
            reloading = true
            $0.title = status.hintDescription()
            $0.value = status.onOrConnectiong()
            reloading = false
            }.onChange({ [unowned self] (row) in
                if reloading {
                    return
                }
                self.handleConnectButtonPressed()
                })
            .cellUpdate ({ cell, row in
                reloading = true
                row.title = self.status.hintDescription()
                row.value = self.status.onOrConnectiong()
                reloading = false
            })
        <<< TextRow(kFormDNS) {
            $0.title = "DNS".localized()
            $0.value = presenter.group.dns
        }.cellSetup { cell, row in
            cell.textField.placeholder = "System DNS".localized()
            cell.textField.autocorrectionType = .no
            cell.textField.autocapitalizationType = .none
        }
        return proxySection
    }

    func generateRuleSetSection() -> Section {
        let group = self.presenter.group
        var ruleSetIds = [String]()
        ruleSetSection = Section("Rule Set".localized())
        for ruleSet in group.ruleSets {
            ruleSetIds.append(ruleSet.uuid)
            ruleSetSection
                <<< LabelRow () {
                    $0.title = "\(ruleSet.name)"
                    var count = 0
                    if ruleSet.ruleCount > 0 {
                        count = ruleSet.ruleCount
                    } else {
                        count = ruleSet.rules.count
                    }
                    if count > 1 {
                        $0.value = String(format: "%d rules".localized(),  count)
                    }else {
                        $0.value = String(format: "%d rule".localized(), count)
                    }
                }.cellSetup({ (cell, row) -> () in
                    cell.selectionStyle = .none
                })
        }
        ruleSetSection <<< SwitchRow(kFormDefaultToProxy) {
            $0.title = "Default To Proxy".localized()
            $0.value = group.defaultToProxy
            $0.hidden = Condition.function([kFormProxies]) { [unowned self] form in
                return self.presenter.proxy == nil
            }
            }.onChange({ [unowned self] (row) in
                do {
                    try defaultRealm.write {
                        self.presenter.group.defaultToProxy = row.value ?? true
                    }
                    try Manager.shared.generateHttpProxyConfig()
                    self.presenter.restartVPN()
                }catch {
                    self.showTextHUD("\("Fail to modify default to proxy".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
                }
                })
        ruleSetSection <<< BaseButtonRow () {
            $0.title = "Add Rule Set".localized()
        }.onCellSelection({ [unowned self] (cell, row) -> () in
            self.presenter.addRuleSet(existing: ruleSetIds)
        })
        Crashlytics.sharedInstance().setObjectValue(ruleSetIds.joined(separator: " "), forKey: "activeRules")
        return ruleSetSection
    }


    // MARK: - Private Actions

    func handleConnectButtonPressed() {
        if status == .on {
            status = .disconnecting
        } else {
            status = .connecting
        }
        presenter.switchVPN()
    }

    func handleTitleButtonPressed() {
        presenter.changeGroupName()
    }

    func onServerConfigurationUpdated() {
        guard let rules = DataInitializer.serverConfigurations["rules"] as? String else {
            return
        }
        var ruleids = (rules ).components(separatedBy: ",")
        let rulesTriggerCondition = (DataInitializer.serverConfigurations["rulesTriggerCondition"] as? Int) ?? 0
        let group = self.presenter.group
        
        if group.ruleSets.count > rulesTriggerCondition {
            return
        }
        for er in group.ruleSets {
            ruleids = ruleids.filter() { $0 == er.uuid }
        }
        if ruleids.count == 0 {
            return
        }
        for ruleid in ruleids {
            let ruleSet = DBUtils.get(ruleid, type: RuleSet.self)
            self.presenter.appendRuleSet(ruleSet)
        }
        self.updateForm()
    }
    // MARK: - TableView

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == ruleSetSection.index && indexPath.row < presenter.group.ruleSets.count {
            return true
        }
        return false
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            do {
                let group = presenter.group
                try defaultRealm.write {
                    group.ruleSets.remove(at: indexPath.row)
                }
                form[indexPath].hidden = true
                form[indexPath].evaluateHidden()
                if Manager.shared.setDefaultConfigGroup(group.uuid, name: group.name) {
                    self.presenter.restartVPN()
                }
            } catch {
                self.showTextHUD("\("Fail to delete item".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
            }
        }
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let proxy = self.proxies[indexPath.row]
        let vc = ProxyConfigurationViewController(upstreamProxy: proxy)
        self.navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - TextRow

    override func textInputDidEndEditing<T>(_ textInput: UITextInput, cell: Cell<T>) {
        guard let textField = textInput as? UITextField else {
            return
        }
        guard let dnsString = textField.text, cell.row.tag == kFormDNS else {
            return
        }
        presenter.updateDNS(dnsString)
        textField.text = presenter.group.dns
    }

    // MARK: - View Setup

    fileprivate let connectButtonHeight: CGFloat = 48

    override func loadView() {
        super.loadView()
        view.backgroundColor = Color.Background
    }

    lazy var titleButton: UIButton = {
        let b = UIButton(type: .custom)
        b.setTitleColor(UIColor.black, for: UIControlState())
        b.addTarget(self, action: #selector(HomeVC.handleTitleButtonPressed), for: .touchUpInside)
        if let titleLabel = b.titleLabel {
            titleLabel.font = UIFont.boldSystemFont(ofSize: titleLabel.font.pointSize)
        }
        return b
    }()

    var timer: Timer?
    
    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(onTime), userInfo: nil, repeats: true)
        timer?.fire()
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func onTime() {
        updateConnectButton()
    }
}

extension VPNStatus {
    
    func onOrConnectiong() -> Bool {
        switch self {
        case .on, .connecting:
            return true
        case .off, .disconnecting:
            return false
        }
    }
    
    func hintDescription() -> String {
        switch self {
        case .on:
            if let time = Settings.shared().startTime {
                let flags = NSCalendar.Unit(rawValue: UInt.max)
                let difference = (Calendar.current as NSCalendar).components(flags, from: time, to: Date(), options: NSCalendar.Options.matchFirst)
                let f = DateComponentsFormatter()
                f.unitsStyle = .abbreviated
                return  (DataInitializer.selectedProxy ?? "Connected".localized()) + " - " + f.string(from: difference)!
            }
            return (DataInitializer.selectedProxy) ?? "Connected".localized()
        case .disconnecting:
            return "Disconnecting...".localized()
        case .off:
            return "Off".localized()
        case .connecting:
            return "Connecting...".localized()
        }
    }
}

