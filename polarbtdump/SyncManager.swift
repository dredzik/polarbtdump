//
//  SyncManager.swift
//  polarbtdump
//
//  Created by Adam Kuczynski on 13/07/2017.
//  Copyright © 2017 typedef.io. All rights reserved.
//

import Foundation

public class SyncManager {

    private var agents: [Device : SyncAgent] = [:]

    public init() {
        NotificationCenter.default.addObserver(forName: PBTDNDeviceConnected, object: nil, queue: nil, using: self.notificationDeviceConnected)
        NotificationCenter.default.addObserver(forName: PBTDNDeviceDisconnected, object: nil, queue: nil, using: self.notificationDeviceDisconnected)
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
