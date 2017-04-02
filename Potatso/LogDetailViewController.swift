//
//  LogDetailViewController.swift
//  Potatso
//
//  Created by LEI on 4/21/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography
import PotatsoLibrary

class LogDetailViewController: UIViewController {
    
    var source: DispatchSource?
    var fd: Int32 = 0
    var data = NSMutableData()
    var logs = NSMutableArray()
    var logPath = ""
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    init(path: String) {
        self.logPath = path
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Logs".localized()
        showLog()
    }
    
    deinit {
        if let source = source {
            source.cancel()
        }
    }
    
    func showLog() {
        guard LoggingLevel.currentLoggingLevel != .off && self.logPath != "" else {
            emptyView.isHidden = false
            return
        }
        fd = Darwin.open(self.logPath, O_RDONLY)
        guard fd > 0 else {
            return
        }
        let queue = DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.background)
        source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue) /*Migrator FIXME: Use DispatchSourceRead to avoid the cast*/ as! DispatchSource
        guard let source = source else {
            return
        }
        source.setEventHandler{ [weak self] in
            self?.updateUI()
        }
        source.setCancelHandler {
            let fd = (source as DispatchSourceProtocol).handle
            Darwin.close(Int32(fd));
        }
        source.resume();
    }
    
    func updateUI() {
        guard let source = source else {
            return
        }
        let pending = (source as DispatchSourceProtocol).data
        let size = Int(min(pending, 65535))
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer {
            buffer.deallocate(capacity: size)
        }
        let readSize = Darwin.read(fd, buffer, size)
        data.append(buffer, length: readSize)
        if let content = String(data: data as Data, encoding: String.Encoding.utf8) {
            logs.add(content)
            if logs.count > 16 {
                logs.removeObject(at: 0)
            }
            let slog = self.logs.componentsJoined(by: "")
            DispatchQueue.main.async(execute: {
                self.logView.text = slog
            })
            data = NSMutableData()
        }
    }
    
    override func loadView() {
        super.loadView()
        view.backgroundColor = Color.Background
        view.addSubview(logView)
        view.addSubview(emptyView)
        constrain(logView, emptyView, view) { logView, emptyView, view in
            logView.edges == view.edges
            emptyView.edges == view.edges
        }
    }
    
    lazy var logView: UITextView = {
        let v = UITextView()
        v.isEditable = false
        v.backgroundColor = Color.Background
        return v
    }()
    
    lazy var emptyView: BaseEmptyView = {
        let v = BaseEmptyView()
        v.title = "Logging is disabled".localized()
        v.isHidden = true
        return v
    }()
    
}
