//
//  ProxyRow.swift
//  Potatso
//
//  Created by LEI on 6/1/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import Eureka
import Cartography

class ProxyRow: Row<Proxy, ProxyRowCell>, RowType {

    required init(tag: String?) {
        super.init(tag: tag)
        displayValueFor = nil
    }
}


class ProxyRowCell: Cell<Proxy>, CellType {

    required init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    override func setup() {
        super.setup()
//        preservesSuperviewLayoutMargins = false
//        layoutMargins = UIEdgeInsetsZero
//        separatorInset = UIEdgeInsetsZero
    }

    override func update() {
        super.update()
        if let proxy = row.value {
            self.textLabel?.text = proxy.description
            self.detailTextLabel?.text = proxy.type.description
            self.imageView?.isHidden = false
            self.imageView?.image = UIImage(named: "Shadowsocks")
        } else {
            self.textLabel?.text = "None".localized()
            self.imageView?.isHidden = true
        }
        if row.isDisabled {
            self.textLabel?.textColor = "5F5F5F".color
        }else {
            self.textLabel?.textColor = "000".color
        }
    }
}
