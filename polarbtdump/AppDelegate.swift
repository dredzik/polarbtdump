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
    func applicationDidFinishLaunching(_ notification: Notification) {
        deviceManager = DeviceManager()
        syncManager = SyncManager()

        NotificationCenter.default.addObserver(self, selector: #selector(self.notifyUser(_:)), name: nil, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: nil, object: nil)

        if let observer = deviceManager {
            NotificationCenter.default.removeObserver(observer, name: nil, object: nil)
        }

        if let observer = syncManager {
            NotificationCenter.default.removeObserver(observer, name: nil, object: nil)
        }
    }

    // MARK: Notifications
    func notifyUser(_ notification: Notification) {
        var message = ""

        switch notification.name {
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

        guard let device = notification.object as? Device else {
            return
        }

        let user = NSUserNotification()

        user.title = device.name
        user.informativeText = message

        NSUserNotificationCenter.default.deliver(user)
    }
}
