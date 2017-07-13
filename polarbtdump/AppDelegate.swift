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

    // MARK: NSApplicationDelegate
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        deviceManager = DeviceManager()

        NotificationCenter.default.addObserver(forName: PBTDNDeviceConnected, object: nil, queue: nil, using: self.notificationDeviceConnected)
        NotificationCenter.default.addObserver(forName: PBTDNDeviceDisconnected, object: nil, queue: nil, using: self.notificationDeviceDisconnected)
        NotificationCenter.default.addObserver(forName: PBTDNSyncStarted, object: nil, queue: nil, using: self.notificationSyncStarted)
        NotificationCenter.default.addObserver(forName: PBTDNSyncFinished, object: nil, queue: nil, using: self.notificationSyncFinished)
    }

    func notificationDeviceConnected(_ aNotification: Notification) {
        guard let device = aNotification.object as? Device else {
            return
        }

        deliver(title: "Device connected", informativeText:  device.name)
    }

    func notificationDeviceDisconnected(_ aNotification: Notification) {
        guard let device = aNotification.object as? Device else {
            return
        }

        deliver(title: "Device disconnected", informativeText: device.name)
    }

    func notificationSyncStarted(_ aNotification: Notification) {
        guard let device = aNotification.object as? Device else {
            return
        }

        deliver(title: "Sync started", informativeText: device.name)
    }

    func notificationSyncFinished(_ aNotification: Notification) {
        guard let device = aNotification.object as? Device else {
            return
        }

        deliver(title: "Sync finished", informativeText: device.name)
    }

    func deliver(title: String, informativeText: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = informativeText
        NSUserNotificationCenter.default.deliver(notification)
    }
}
