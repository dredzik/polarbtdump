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
    }
}
