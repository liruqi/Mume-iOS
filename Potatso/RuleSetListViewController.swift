//
//  RuleSetListViewController.swift
//  Potatso
//
//  Created by LEI on 5/31/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import Cartography
import Realm
import RealmSwift

private let rowHeight: CGFloat = 54
private let kRuleSetCellIdentifier = "ruleset"

class RuleSetListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var ruleSets: Results<RuleSet>
    var chooseCallback: (RuleSet? -> Void)?
    // Observe Realm Notifications
    var heightAtIndex: [Int: CGFloat] = [:]
    private let pageSize = 20
    
    init(chooseCallback: (RuleSet? -> Void)? = nil) {
        self.chooseCallback = chooseCallback
        self.ruleSets = DBUtils.allNotDeleted(RuleSet.self, sorted: "createAt")
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func loadData() {
        API.getRuleSets() { (response) in
            self.tableView.pullToRefreshView?.stopAnimating()
            if response.result.isFailure {
                // Fail
//                let errDesc = response.result.error?.localizedDescription ?? ""
                // self.showTextHUD((errDesc.characters.count > 0 ? "\(errDesc)" : "Unkown error".localized()), dismissAfterDelay: 1.5)
            } else {
                guard let result = response.result.value else {
                    return
                }
                let data = result.filter({ $0.name.characters.count > 0})
                for i in 0..<data.count {
                    do {
                        try RuleSet.addRemoteObject(data[i])
                    } catch {
                        NSLog("Fail to subscribe".localized())
                    }
                }
                self.reloadData()
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.title = "Rule Set".localized()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(add))
        reloadData()
        
        tableView.addPullToRefreshWithActionHandler( { [weak self] in
            self?.loadData()
            })
        if ruleSets.count == 0 {
            tableView.triggerPullToRefresh()
        }
    }

    func reloadData() {
        ruleSets = DBUtils.allNotDeleted(RuleSet.self, sorted: "createAt")
        tableView.reloadData()
    }

    func add() {
        let vc = RuleSetConfigurationViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    func showRuleSetConfiguration(ruleSet: RuleSet?) {
        let vc = RuleSetConfigurationViewController(ruleSet: ruleSet)
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ruleSets.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(kRuleSetCellIdentifier, forIndexPath: indexPath) as! RuleSetCell
        cell.setRuleSet(ruleSets[indexPath.row], showSubscribe: true)
        return cell
    }

    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        heightAtIndex[indexPath.row] = cell.frame.size.height
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        let ruleSet = ruleSets[indexPath.row]
        if let cb = chooseCallback {
            cb(ruleSet)
            close()
        }else {
            showRuleSetConfiguration(ruleSet)
        }
    }

    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if let height = heightAtIndex[indexPath.row] {
            return height
        } else {
            return UITableViewAutomaticDimension
        }
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return chooseCallback == nil
    }

    func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        return .Delete
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let item: RuleSet
            guard indexPath.row < ruleSets.count else {
                return
            }
            item = ruleSets[indexPath.row]
            do {
                try DBUtils.hardDelete(item.uuid, type: RuleSet.self)
            }catch {
                self.showTextHUD("\("Fail to delete item".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
            }
        }
    }
    

    override func loadView() {
        super.loadView()
        view.backgroundColor = UIColor.clearColor()
        view.addSubview(tableView)
        tableView.registerClass(RuleSetCell.self, forCellReuseIdentifier: kRuleSetCellIdentifier)

        constrain(tableView, view) { tableView, view in
            tableView.edges == view.edges
        }
    }

    lazy var tableView: UITableView = {
        let v = UITableView(frame: CGRect.zero, style: .Plain)
        v.dataSource = self
        v.delegate = self
        v.tableFooterView = UIView()
        v.tableHeaderView = UIView()
        v.separatorStyle = .SingleLine
        v.rowHeight = UITableViewAutomaticDimension
        return v
    }()

}
