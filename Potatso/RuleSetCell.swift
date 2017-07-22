//
//  RuleSetCell.swift
//  Potatso
//
//  Created by LEI on 5/31/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography
import PotatsoModel

class RuleSetCell: UITableViewCell {

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        preservesSuperviewLayoutMargins = false
        layoutMargins = UIEdgeInsets.zero
        separatorInset = UIEdgeInsets.zero
        contentView.addSubview(titleLabel)
        contentView.addSubview(countLabel)
        contentView.addSubview(leftHintView)
        contentView.addSubview(descLabel)
        contentView.addSubview(subscribeFlagLabel)
        self.translatesAutoresizingMaskIntoConstraints = false
//        contentView.addSubview(avatarImageView)
//        contentView.addSubview(authorNameLabel)
//        contentView.addSubview(updateAtLabel)
        countLabel.setContentHuggingPriority(UILayoutPriorityRequired, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .horizontal)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateRSCellLayout(subscribe: Bool) -> CGFloat {
        var rootFrame = self.bounds
        self.contentView.frame = rootFrame
        let topFrame = CGRect(x: 15, y: 13, width: rootFrame.width - 30, height: 24)
        self.titleLabel.frame = topFrame
        self.countLabel.frame = topFrame
        var y: CGFloat = 24 + 13 + 11
        self.descLabel.frame = CGRect(x: 15 + 2 + 5, y: y, width: topFrame.width - 7, height: 89)
        self.descLabel.sizeToFit()
        let descFrame = self.descLabel.frame
        let hintFrame = CGRect(x: 15, y: y, width: 2, height: descFrame.height)
        self.leftHintView.frame = hintFrame
        y += descFrame.height
        subscribeFlagLabel.isHidden = !subscribe
        if subscribe {
            y += 8
            self.subscribeFlagLabel.frame = CGRect(x: 15, y: y, width: topFrame.width, height: 20)
            self.subscribeFlagLabel.sizeToFit()
            self.subscribeFlagLabel.frame.size = CGSize(width: self.subscribeFlagLabel.frame.width + 20, height: 20)
            y += 20
        } else {
            print ("not subscribe")
        }
        rootFrame.size.height = y + 13
        self.contentView.frame = rootFrame
        return rootFrame.height
    }
    
    static func caculateRSCellLayoutHeight(ruleSet: RuleSet) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        var y: CGFloat = 24 + 13 + 11
        let desc = ruleSet.desc as NSString
        let rect = desc.boundingRect(with: CGSize(width: screenWidth - 30 - 7, height: 128), options: .usesLineFragmentOrigin, attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 13)], context: nil)
        y += rect.height
        
        if ruleSet.isSubscribe {
            y += 8 + 20
        }
        return y + 13
    }
    
    func setRuleSet(_ ruleSet: RuleSet, showFullDescription: Bool = false) -> CGFloat {
        titleLabel.text = ruleSet.name
        var count = 0
        if ruleSet.ruleCount > 0 {
            count = ruleSet.ruleCount
        }else {
            count = ruleSet.rules.count
        }
        if count > 1 {
            countLabel.text = String(format: "%d rules".localized(),  count)
        }else {
            countLabel.text = String(format: "%d rule".localized(), count)
        }
        descLabel.text = ruleSet.desc
        descLabel.numberOfLines = showFullDescription ? 0 : 2
        subscribeFlagLabel.text = "Default".localized()
        return self.updateRSCellLayout(subscribe: ruleSet.isSubscribe)
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        subscribeFlagLabel.backgroundColor = "16A085".color
        leftHintView.backgroundColor = "DEDEDE".color
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        subscribeFlagLabel.backgroundColor = "16A085".color
        leftHintView.backgroundColor = "DEDEDE".color
    }

    lazy var titleLabel: UILabel = {
        let v = UILabel()
        v.textColor = "000".color
        v.font = UIFont.systemFont(ofSize: 17)
        v.textAlignment = .left
        return v
    }()

    lazy var countLabel: UILabel = {
        let v = UILabel()
        v.textColor = "404040".color
        v.font = UIFont.systemFont(ofSize: 14)
        v.textAlignment = .right
        return v
    }()

    lazy var descLabel: UILabel = {
        let v = UILabel()
        v.textColor = "5B5B5B".color
        v.font = UIFont.systemFont(ofSize: 13)
        v.numberOfLines = 2
        return v
    }()

    lazy var leftHintView: UIView = {
        let v = UIView()
        v.backgroundColor = "DEDEDE".color
        return v
    }()

    lazy var avatarImageView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        return v
    }()

    lazy var authorNameLabel: UILabel = {
        let v = UILabel()
        v.textColor = "5D5D5D".color
        v.font = UIFont.systemFont(ofSize: 12)
        return v
    }()

    lazy var updateAtLabel: UILabel = {
        let v = UILabel()
        v.textColor = "5D5D5D".color
        v.font = UIFont.systemFont(ofSize: 12)
        return v
    }()

    lazy var subscribeFlagLabel: PaddingLabel = {
        let v = PaddingLabel()
        v.textColor = UIColor.white
        v.font = UIFont.systemFont(ofSize: 10)
        v.padding = UIEdgeInsetsMake(3, 10, 3, 10)
        v.layer.cornerRadius = 3
        v.layer.masksToBounds = true
        v.clipsToBounds = true
        return v
    }()

}
