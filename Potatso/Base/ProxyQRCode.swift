//
//  ProxyQRCode.swift
//  Potatso
//
//  Created by Ruqi on 6/18/2017.
//  Copyright © 2017 TouchingApp. All rights reserved.
//

import Foundation
import EFQRCode
import Cartography

class ProxyQRCode : UIView {
    var proxy: String

    var sadView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        return v
    }()
    
    convenience init(frame: CGRect, proxy: String) {
        self.init(frame: frame)
        self.proxy = proxy
        
        if let tryImage = EFQRCode.generate(
            content: proxy,
            watermark: UIImage(named: "Mume")?.toCGImage()
            ) {
            print("Create QRCode image success: \(tryImage)")
            self.sadView.image = UIImage(cgImage: tryImage)
        } else {
            print("Create QRCode image failed!")
        }
    }
    
    override init(frame: CGRect) {
        self.proxy = ""
        super.init(frame: frame)
        addSubview(sadView)
        constrain(sadView, self) { sadView, superView in
            sadView.centerX == superView.centerX
            sadView.width == superView.width - 20
            sadView.height == superView.height - 20
            sadView.centerY == superView.centerY
        }
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
