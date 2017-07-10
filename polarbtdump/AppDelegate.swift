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
        dumper = Dumper()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
}
