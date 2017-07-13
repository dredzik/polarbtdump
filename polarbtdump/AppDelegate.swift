//
//  AppDelegate.swift
//  polarbtdump
//
//  Created by Adam Kuczynski on 10/07/2017.
//  Copyright © 2017 typedef.io. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private var deviceManager: DeviceManager?
    private var syncManager: SyncManager?

    // MARK: NSApplicationDelegate
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        deviceManager = DeviceManager()
        syncManager = SyncManager()

        NotificationCenter.default.addObserver(forName: PBTDNDeviceConnected, object: nil, queue: nil, using: self.notifyUser)
        NotificationCenter.default.addObserver(forName: PBTDNDeviceDisconnected, object: nil, queue: nil, using: self.notifyUser)
        NotificationCenter.default.addObserver(forName: PBTDNSyncStarted, object: nil, queue: nil, using: self.notifyUser)
        NotificationCenter.default.addObserver(forName: PBTDNSyncFinished, object: nil, queue: nil, using: self.notifyUser)
    }

    // MARK: Notifications
    func notifyUser(_ aNotification: Notification) {
        var message = ""

        switch aNotification.name {
        case PBTDNDeviceConnected:
            message = "Device connected"
        case PBTDNDeviceDisconnected:
            message = "Device disconnected"
        case PBTDNSyncStarted:
            message = "Sync started"
        case PBTDNSyncFinished:
            message = "Sync finished"
        default:
            return
        }

        guard let device = aNotification.object as? Device else {
            return
        }

        let notification = NSUserNotification()
        notification.title = device.name
        notification.informativeText = message
        NSUserNotificationCenter.default.deliver(notification)
    }
}
