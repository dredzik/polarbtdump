//
//  Device.swift
//  polarbtdump
//
//  Created by Adam Kuczynski on 13/07/2017.
//  Copyright © 2017 typedef.io. All rights reserved.
//

import Foundation
import CoreBluetooth

public class Device: NSObject {

    let identifier: UUID
    let name: String

    var central: CBCentral?
    let peripheral: CBPeripheral

    public init(_ peripheral: CBPeripheral) {
        self.identifier = peripheral.identifier
        self.name = peripheral.name!

        self.peripheral = peripheral
    }
}
