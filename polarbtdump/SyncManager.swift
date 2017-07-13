//
//  SyncManager.swift
//  polarbtdump
//
//  Created by Adam Kuczynski on 13/07/2017.
//  Copyright © 2017 typedef.io. All rights reserved.
//

import Foundation

public class SyncManager: NSObject {

    private var agents: [Device : SyncAgent] = [:]

    public override init() {
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationDeviceConnected(_:)), name: Notifications.Device.Connected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationDeviceDisconnected(_:)), name: Notifications.Device.Disconnected, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Notifications
    func notificationDeviceConnected(_ aNotification: Notification) {
        guard let device = aNotification.object as? Device else {
            return
        }

        agents[device] = SyncAgent(device)
    }

    func notificationDeviceDisconnected(_ aNotification: Notification) {
        guard let device = aNotification.object as? Device else {
            return
        }

        agents.removeValue(forKey: device)
    }
}
