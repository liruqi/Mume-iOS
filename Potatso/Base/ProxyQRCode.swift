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
import Photos

class ProxyQRCode : UIView {
    var proxy: String
    var image: UIImage? = nil
    var shareCallback: (_: UIImage) -> Void
    var sadView: UIButton = {
        let v = UIButton(type: .custom)
        v.contentMode = .scaleAspectFit
        return v
    }()
    
    convenience init(frame: CGRect, proxy: String, callback: @escaping (_: UIImage) -> Void ) {
        self.init(frame: frame)
        self.proxy = proxy
        self.shareCallback = callback
        if let tryImage = EFQRCode.generate(
            content: proxy,
            watermark: UIImage(named: "Mume")?.toCGImage()
            ) {
            print("Create QRCode image success: \(tryImage)")
            self.image = UIImage(cgImage: tryImage)
            self.sadView.setImage(self.image, for: .normal)
            self.sadView.addTarget(self, action: #selector(onShare(_:)), for: .touchUpInside)
        } else {
            print("Create QRCode image failed!")
        }
    }
    
    func onShare(_ sender: UITapGestureRecognizer) {
        if let image = self.image {
            let status = PHPhotoLibrary.authorizationStatus()
            if status != .notDetermined {
                self.shareCallback(image)
                return
            }
            PHPhotoLibrary.requestAuthorization({ (newStatus) in
                self.shareCallback(image)
            })
        }
    }
    
    override init(frame: CGRect) {
        self.proxy = ""
        self.shareCallback = { _ in }
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
