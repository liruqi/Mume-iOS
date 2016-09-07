//
//  CurrentGroupCell.swift
//  Potatso
//
//  Created by LEI on 4/13/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import UIKit
import Cartography
import PotatsoLibrary

class CurrentGroupCell: UIView {
    
    var switchVPN: (()->Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(nameLabel)
        self.addSubview(switchButton)
        setupLayout()
    }
    
    func onSwitchValueChanged() {
        switchButton.hidden = true
        switchVPN?()
    }
    
    func config(name: String?, status: Bool, switchVPN: (() -> Void)?) {
        nameLabel.text = name ?? "None".localized()
        switchButton.hidden = false
        switchButton.addTarget(self, action: #selector(self.onSwitchValueChanged), forControlEvents: .TouchUpInside)
        switchButton.setOn(status, animated: false)
        self.switchVPN = switchVPN
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupLayout() {
        constrain(nameLabel, switchButton, self) { nameLabel, switchButton, superView in
            nameLabel.leading == superView.leading
            nameLabel.centerY == superView.centerY
            nameLabel.trailing == switchButton.leading - 15
            
            switchButton.centerY == superView.centerY
            switchButton.trailing == superView.trailing - 8
            switchButton.width == 60
        }
    }
    
    lazy var nameLabel: UILabel = {
        let v = UILabel()
        v.font = UIFont.boldSystemFontOfSize(17)
        v.textColor = UIColor.whiteColor()
        return v
    }()
    
    lazy var switchButton: UISwitch = {
        let v = UISwitch()
        return v
    }()

    
}