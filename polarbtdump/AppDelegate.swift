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
    var dumper: Dumper!
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let notification = NSUserNotification()
        notification.title = "polarbtdump started"
        notification.informativeText = "Press sync button on your Polar device to synchronize with this computer."
        NSUserNotificationCenter.default.deliver(notification)
        dumper = Dumper()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
}
