//
//  AppDelegate.swift
//  polarbtdump
//
//  Created by Adam Kuczynski on 10/07/2017.
//  Copyright © 2017 typedef.io. All rights reserved.
//

import Cocoa
import CoreBluetooth

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CBCentralManagerDelegate, CBPeripheralManagerDelegate, DumperDelegate {

    var centralManager: CBCentralManager?
    var peripheralManager: CBPeripheralManager?
    let service = CBMutableService(type: Constants.UUIDs.Service, primary: true)
    let data = CBMutableCharacteristic(type: Constants.UUIDs.Data, properties: Constants.Props, value: nil, permissions: Constants.Perms)

    var centrals: [UUID : CBCentral] = [:]
    var peripherals: [UUID : CBPeripheral] = [:]

    var dumpers: [UUID : Dumper] = [:]

    // MARK: NSApplicationDelegate
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)

        service.characteristics = [data]
    }

    // MARK: CBCentralManagerDelegate
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
        } else {
            central.stopScan()
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name else {
            return
        }

        if !name.hasPrefix("Polar") || name.hasPrefix("Polar mobile") {
            return
        }

        let identifier = peripheral.identifier
        peripherals[identifier] = peripheral

        central.stopScan()
        central.connect(peripherals[identifier]! , options: nil)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let notification = NSUserNotification()
        notification.title = "Device connected"
        notification.informativeText = peripheral.name
        NSUserNotificationCenter.default.deliver(notification)

        let identifier = peripheral.identifier
        dumpers[identifier] = Dumper(identifier, delegate: self)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let notification = NSUserNotification()
        notification.title = "Device disconnected"
        notification.informativeText = peripheral.name
        NSUserNotificationCenter.default.deliver(notification)

        let identifier = peripheral.identifier
        dumpers.removeValue(forKey: identifier)
        peripherals.removeValue(forKey: identifier)

        central.scanForPeripherals(withServices: nil, options: nil)
    }

    // MARK: CBPeripheralManagerDelegate
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            peripheral.add(service)
        } else {
            peripheral.removeAllServices()
        }
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey : Constants.UUIDs.Service,
            CBAdvertisementDataLocalNameKey : "Polar mobile 666",
            CBAdvertisementDataIsConnectable : true,
        ])
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        peripheral.setDesiredConnectionLatency(.low, for: central)

        let identifier = central.identifier
        centrals[identifier] = central
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        let identifier = central.identifier
        centrals.removeValue(forKey: identifier)
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        peripheral.respond(to: request, withResult: .success)
        data.value = Data([0x0f, 0x00])

        let identifier = request.central.identifier
        dumpers[identifier]?.dump()
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite request: CBATTRequest) {
        peripheral.respond(to: request, withResult: .success)
        if let value = request.value {
            data.value = value

            let identifier = request.central.identifier
            dumpers[identifier]?.recvPacket(value)
        }
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            self.peripheralManager(peripheral, didReceiveWrite: request)
        }
    }

    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        dumpers.forEach {
            $1.sendPacket()
        }
    }

    // MARK: DumperDelegate
    public func updateValue(_ value: Data, forCentral identifier: UUID) -> Bool {
        guard let central = centrals[identifier] else {
            return false
        }

        return peripheralManager!.updateValue(value, for: data, onSubscribedCentrals: [central])
    }
}
