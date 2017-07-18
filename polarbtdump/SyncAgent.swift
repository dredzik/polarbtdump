//
//  SyncAgent.swift
//  polarbtdump
//
//  Created by Adam Kuczyński on 28.05.2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import Foundation

public class SyncAgent: NSObject {

    private var device: Device

    private var currentPath: String?
    private var pathsToVisit = [String]()

    init(_ device: Device) {
        self.device = device

        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(self.syncStart(_:)), name: Notifications.Sync.Start, object: device)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Sync
    func syncStart(_ notification: Notification) {
        NotificationCenter.default.addObserver(self, selector: #selector(self.recv(_:)), name: Notifications.Message.Recv, object: device)
        NotificationCenter.default.post(name: Notifications.Sync.Started, object: device)
        NotificationCenter.default.post(name: Notifications.Message.Send, object: device, userInfo: ["Data" : Constants.Packets.SyncBegin])

        pathsToVisit.append("/")
        syncNext()
    }
    
    private func syncNext() {
        if pathsToVisit.count == 0 {
            syncFinish()

            return
        }
        
        currentPath = pathsToVisit.removeFirst()

        let request = PolarRequest.with {
            $0.type = .read
            $0.path = currentPath!
        }

        let message = PSMessage(request)

        NotificationCenter.default.post(name: Notifications.Message.Send, object: device, userInfo: ["Data" : message])
    }

    func syncFinish() {
        NotificationCenter.default.removeObserver(self, name: Notifications.Message.Recv, object: device)
        NotificationCenter.default.post(name: Notifications.Sync.Finished, object: device)
        NotificationCenter.default.post(name: Notifications.Message.Send, object: device, userInfo: ["Data" : Constants.Packets.SyncEnd])
        NotificationCenter.default.post(name: Notifications.Message.Send, object: device, userInfo: ["Data" : Constants.Packets.SessionEnd])
    }

    // MARK: Recv
    func recv(_ aNotification: Notification) {
        guard let message = aNotification.userInfo?["Data"] as? PSMessage else {
            return
        }

        if currentPath!.hasSuffix("/") {
            recvDirectory(message)
        } else {
            recvFile(message)
        }

        syncNext()
    }

    private func recvDirectory(_ message: PSMessage) {
        guard let path = currentPath else {
            return
        }

        _ = PBTDUrlForPath(path, forDevice: device)
        let list = try! PolarDirectory(serializedData: message.data)

        for entry in list.entries {
            let childPath = path + entry.path
            let childUrl = PBTDUrlForPath(childPath, forDevice: device)

            if PBTDShouldUpdate(entry, url: childUrl) {
                pathsToVisit.append(childPath)
            }
        }
    }

    private func recvFile(_ message: PSMessage) {
        guard let path = currentPath else {
            return
        }

        let url = PBTDUrlForPath(path, forDevice: device)
        let content = Data(message.payload.dropLast())

        try! content.write(to: url)
    }
}

