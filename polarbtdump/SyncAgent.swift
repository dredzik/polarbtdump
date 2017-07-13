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

        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationDeviceReady(_:)), name: PBTDNDeviceReady, object: device)
        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationMessageRecv(_:)), name: PBTDNMessageRecv, object: device)
    }
    
    private func sync() {
        NotificationCenter.default.post(name: PBTDNSyncStarted, object: device)
        NotificationCenter.default.post(name: PBTDNMessageRaw, object: device, userInfo: ["Data" : Constants.Packets.SyncBegin])

        pathsToVisit.append("/")
        syncNext()
    }
    
    private func syncNext() {
        if pathsToVisit.count == 0 {
            NotificationCenter.default.post(name: PBTDNSyncFinished, object: device)
            NotificationCenter.default.post(name: PBTDNMessageRaw, object: device, userInfo: ["Data" : Constants.Packets.SyncEnd])
            NotificationCenter.default.post(name: PBTDNMessageRaw, object: device, userInfo: ["Data" : Constants.Packets.SessionEnd])

            return
        }
        
        currentPath = pathsToVisit.removeFirst()
        let request = Request.with {
            $0.type = .read
            $0.path = currentPath!
        }

        let message = PSMessage(request)

        NotificationCenter.default.post(name: PBTDNMessageSend, object: device, userInfo: ["Data" : message])
    }
    
    private func recvDirectory(_ message: PSMessage) {
        guard let path = currentPath else {
            return
        }

        let url = PBTDUrlForPath(path, forDevice: device)
        let content = Data(message.payload.dropLast())

        let list = try! Directory(serializedData: content)

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

    // MARK: Notifications
    func notificationDeviceReady(_ aNotification: Notification) {
        sync()
    }

    func notificationMessageRecv(_ aNotification: Notification) {
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
}

