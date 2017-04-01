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
    
    var switchVPN: ((_ on: Bool)->Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(nameLabel)
        self.addSubview(switchButton)
        setupLayout()
    }
    
    func onSwitchValueChanged(_ sender: UISwitch) {
        switchButton.isHidden = true
        switchVPN?(on: sender.isOn)
    }
    
    func config(_ name: String?, status: Bool, switchVPN: ((on: Bool) -> Void)?) {
        nameLabel.text = name ?? "None".localized()
        switchButton.isHidden = false
        switchButton.addTarget(self, action: #selector(self.onSwitchValueChanged), for: .touchUpInside)
        switchButton.setOn(status, animated: false)
        self.switchVPN = switchVPN
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupLayout() {
        constrain(nameLabel, switchButton, self) { nameLabel, switchButton, superView in
            nameLabel.leading == superView.leading + 15
            nameLabel.centerY == superView.centerY
            nameLabel.trailing == switchButton.leading - 15
            
            switchButton.centerY == superView.centerY
            switchButton.trailing == superView.trailing - 8
            switchButton.width == 60
        }
    }
    
    lazy var nameLabel: UILabel = {
        let v = UILabel()
        v.font = UIFont.boldSystemFont(ofSize: 17)
        v.textColor = UIColor.white
        return v
    }()
    
    lazy var switchButton: UISwitch = {
        let v = UISwitch()
        return v
    }()

    
}
