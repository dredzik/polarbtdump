//
//  Constants.swift
//  btproxy
//
//  Created by Adam Kuczyński on 28.05.2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import CoreBluetooth
import Foundation

struct Constants {
    struct UUIDs {
        static let Service = CBUUID(string: "fb005c14-9815-d766-a528-32d54cf35530")
        static let Data = CBUUID(string: "fb005c16-02e7-f387-1cad-8acd2d8df0c8")
    }

    struct Packets {
        static let SyncBegin = Data([0x0A, 0x00, 0x00, 0x00])
        static let SyncEnd = Data([0x0A, 0x00, 0x01, 0x08, 0x01, 0x0])
        static let SessionEnd = Data([0x0A, 0x00, 0x09, 0x00])
    }

    static let Perms: CBAttributePermissions = [.readable, .writeable]
    static let Props: CBCharacteristicProperties = [.read, .writeWithoutResponse, .notify]
}

let BackupRoot = NSHomeDirectory() + "/.polar/backup/bt"

let PBTDNDeviceConnected = Notification.Name("PBTDNDeviceConnected")
let PBTDNDeviceDisconnected = Notification.Name("PBTDNDeviceDisconnected")
let PBTDNSyncStarted = Notification.Name("PBTDNSyncStarted")
let PBTDNSyncFinished = Notification.Name("PBTDNSyncFinished")
