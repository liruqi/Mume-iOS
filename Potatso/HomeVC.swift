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

private let kFormName = "name"
private let kFormDNS = "dns"
private let kFormProxies = "proxies"
private let kFormDefaultToProxy = "defaultToProxy"

class HomeVC: FormViewController, UINavigationControllerDelegate, HomePresenterProtocol, UITextFieldDelegate {

    let presenter = HomePresenter()
    var proxies: [Proxy] = []

    var ruleSetSection: Section!

    var status: VPNStatus {
        didSet(o) {
            updateConnectButton()
        }
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        self.status = .Off
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
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.titleView = titleButton
        // Post an empty message so we could attach to packet tunnel process
        Manager.sharedManager.postMessage()
        handleRefreshUI(nil)
        updateForm()
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: "List".templateImage, style: .Plain, target: presenter, action: #selector(HomePresenter.chooseConfigGroups))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(addProxy(_:)))
        startTimer()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }
    
    func addProxy(sender: AnyObject) {
        let alert = UIAlertController(title: "Add Proxy".localized(), message: nil, preferredStyle: .ActionSheet)
        alert.addAction(UIAlertAction(title: "Import From QRCode".localized(), style: .Default, handler: { (action) in
            let importer = Importer(vc: self)
            importer.importConfigFromQRCode()
        }))
        alert.addAction(UIAlertAction(title: "Manual Settings".localized(), style: .Default, handler: { (action) in
            let vc = ProxyConfigurationViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .Cancel, handler: nil))
        if let presenter = alert.popoverPresentationController {
            if let rightBtn : View = navigationItem.rightBarButtonItem?.valueForKey("view") as? View {
                presenter.sourceView = rightBtn
                presenter.sourceRect = rightBtn.bounds
            } else {
                presenter.sourceView = titleButton
                presenter.sourceRect = titleButton.bounds
            }
        }
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    // MARK: - HomePresenter Protocol

    func handleRefreshUI(error: ErrorType?) {
        if presenter.group.isDefault {
            let vpnStatus = Manager.sharedManager.vpnStatus
            if status == .Connecting {
                if nil == error {
                    if vpnStatus == .Off {
                        return
                    }
                }
            }
            if status == .Disconnecting {
                if vpnStatus == .On {
                    return
                }
            }
            status = vpnStatus
        } else {
            status = .Off
        }
        updateTitle()
    }

    func updateTitle() {
        titleButton.setTitle(presenter.group.name, forState: .Normal)
        titleButton.sizeToFit()
    }

    func updateForm() {
        form.delegate = nil
        form.removeAll()

        
        form.delegate = nil
        form.removeAll()
        
        form +++ generateProxySection()

        let section = Section("Proxy".localized())
        proxies = DBUtils.allNotDeleted(Proxy.self, sorted: "createAt").map({ $0 })
        if proxies.count == 0 {
            section
                <<< ProxyRow() {
                    $0.value = nil
                    $0.cellStyle = UITableViewCellStyle.Subtitle
                    }.cellSetup({ (cell, row) -> () in
                        cell.selectionStyle = .None
                        cell.accessoryType = .Checkmark
                    })
        } else {
            if nil == self.presenter.proxy {
                try? ConfigurationGroup.changeProxy(forGroupId: self.presenter.group.uuid, proxyId: proxies[0].uuid)
            }
        
        for proxy in proxies {
            section
                <<< ProxyRow() {
                    $0.value = proxy
                    $0.cellStyle = UITableViewCellStyle.Subtitle
                    }.cellSetup({ (cell, row) -> () in
                        cell.selectionStyle = .None
                        if (self.presenter.proxy?.uuid == proxy.uuid) {
                            cell.accessoryType = .Checkmark
                        } else {
                            cell.accessoryType = .None
                        }
                    }).onCellSelection({ [unowned self] (cell, row) in
                        let proxy = row.value
                        do {
                            try ConfigurationGroup.changeProxy(forGroupId: self.presenter.group.uuid, proxyId: proxy?.uuid)
                            self.updateTitle()
                            self.updateForm()
                            //TODO: reconnect here
                        }catch {
                            self.showTextHUD("\("Fail to change proxy".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
                        }
                        })
        }
            }
        form +++ section
        
        form +++ generateRuleSetSection()
        form.delegate = self
        tableView?.reloadData()
    }

    func updateConnectButton() {
        tableView?.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .None)
    }

    // MARK: - Form

    func generateProxySection() -> Section {
        let proxySection = Section("Connect".localized())

        proxySection <<< SwitchRow("connection") {
            $0.title = status.hintDescription
            $0.value = status.onOrConnectiong
            }.onChange({ [unowned self] (row) in
                self.handleConnectButtonPressed()
                })
            .cellUpdate ({ cell, row in
                row.title = self.status.hintDescription
                row.value = self.status.onOrConnectiong
            })
        <<< TextRow(kFormDNS) {
            $0.title = "DNS".localized()
            $0.value = presenter.group.dns
        }.cellSetup { cell, row in
            cell.textField.placeholder = "System DNS".localized()
            cell.textField.autocorrectionType = .No
            cell.textField.autocapitalizationType = .None
        }
        return proxySection
    }

    func generateRuleSetSection() -> Section {
        ruleSetSection = Section("Rule Set".localized())
        for ruleSet in presenter.group.ruleSets {
            ruleSetSection
                <<< LabelRow () {
                    $0.title = "\(ruleSet.name)"
                    var count = 0
                    if ruleSet.ruleCount > 0 {
                        count = ruleSet.ruleCount
                    }else {
                        count = ruleSet.rules.count
                    }
                    if count > 1 {
                        $0.value = String(format: "%d rules".localized(),  count)
                    }else {
                        $0.value = String(format: "%d rule".localized(), count)
                    }
                }.cellSetup({ (cell, row) -> () in
                    cell.selectionStyle = .None
                })
        }
        ruleSetSection <<< SwitchRow(kFormDefaultToProxy) {
            $0.title = "Default To Proxy".localized()
            $0.value = presenter.group.defaultToProxy
            $0.hidden = Condition.Function([kFormProxies]) { [unowned self] form in
                return self.presenter.proxy == nil
            }
            }.onChange({ [unowned self] (row) in
                do {
                    try defaultRealm.write {
                        self.presenter.group.defaultToProxy = row.value ?? true
                    }
                }catch {
                    self.showTextHUD("\("Fail to modify default to proxy".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
                }
                })
        ruleSetSection <<< BaseButtonRow () {
            $0.title = "Add Rule Set".localized()
        }.onCellSelection({ [unowned self] (cell, row) -> () in
            self.presenter.addRuleSet()
        })
        return ruleSetSection
    }


    // MARK: - Private Actions

    func handleConnectButtonPressed() {
        if status == .On {
            status = .Disconnecting
        }else {
            status = .Connecting
        }
        presenter.switchVPN()
    }

    func handleTitleButtonPressed() {
        presenter.changeGroupName()
    }

    // MARK: - TableView

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if indexPath.section == ruleSetSection.index && indexPath.row < presenter.group.ruleSets.count {
            return true
        }
        return false
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            do {
                try defaultRealm.write {
                    presenter.group.ruleSets.removeAtIndex(indexPath.row)
                }
                form[indexPath].hidden = true
                form[indexPath].evaluateHidden()
            }catch {
                self.showTextHUD("\("Fail to delete item".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
            }
        }
    }

    func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        return .Delete
    }

    // MARK: - TextRow

    override func textInputDidEndEditing<T>(textInput: UITextInput, cell: Cell<T>) {
        guard let textField = textInput as? UITextField else {
            return
        }
        guard let dnsString = textField.text where cell.row.tag == kFormDNS else {
            return
        }
        presenter.updateDNS(dnsString)
        textField.text = presenter.group.dns
    }

    // MARK: - View Setup

    private let connectButtonHeight: CGFloat = 48

    override func loadView() {
        super.loadView()
        view.backgroundColor = Color.Background
    }

    lazy var titleButton: UIButton = {
        let b = UIButton(type: .Custom)
        b.setTitleColor(UIColor.blackColor(), forState: .Normal)
        b.addTarget(self, action: #selector(HomeVC.handleTitleButtonPressed), forControlEvents: .TouchUpInside)
        if let titleLabel = b.titleLabel {
            titleLabel.font = UIFont.boldSystemFontOfSize(titleLabel.font.pointSize)
        }
        return b
    }()

    var timer: NSTimer?
    
    func startTimer() {
        timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(onTime), userInfo: nil, repeats: true)
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
    
    var color: UIColor {
        switch self {
        case .On, .Disconnecting:
            return Color.StatusOn
        case .Off, .Connecting:
            return Color.StatusOff
        }
    }

    var onOrConnectiong: Bool {
        switch self {
        case .On, .Connecting:
            return true
        case .Off, .Disconnecting:
            return false
        }
    }
    
    var hintDescription: String {
        switch self {
        case .On:
            if let time = Settings.shared().startTime {
                let flags = NSCalendarUnit(rawValue: UInt.max)
                let difference = NSCalendar.currentCalendar().components(flags, fromDate: time, toDate: NSDate(), options: NSCalendarOptions.MatchFirst)
                let f = NSDateComponentsFormatter()
                f.unitsStyle = .Abbreviated
                return  "Connected".localized() + " - " + f.stringFromDateComponents(difference)!
            }
            return "Connected".localized()
        case .Disconnecting:
            return "Disconnecting...".localized()
        case .Off:
            return "Off".localized()
        case .Connecting:
            return "Connecting...".localized()
        }
    }
}
