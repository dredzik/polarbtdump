//
//  DeviceManager.swift
//  polarbtdump
//
//  Created by Adam Kuczynski on 13/07/2017.
//  Copyright © 2017 typedef.io. All rights reserved.
//

import CoreBluetooth
import Foundation

public class Device {

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

public class DeviceManager: NSObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate, DumperDelegate {

    var centralManager: CBCentralManager?
    var peripheralManager: CBPeripheralManager?
    let service = CBMutableService(type: Constants.UUIDs.Service, primary: true)
    let data = CBMutableCharacteristic(type: Constants.UUIDs.Data, properties: Constants.Props, value: nil, permissions: Constants.Perms)

    var devices: [UUID : Device] = [:]
    var dumpers: [UUID : Dumper] = [:]

    public override init() {
        super.init()

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

        let device = Device(peripheral)
        devices[device.identifier] = device

        central.stopScan()
        central.connect(device.peripheral, options: nil)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let identifier = peripheral.identifier

        guard let device = devices[identifier] else {
            return
        }

        dumpers[identifier] = Dumper(device, delegate: self)

        NotificationCenter.default.post(name: PBTDNDeviceConnected, object: device)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let identifier = peripheral.identifier

        guard let device = devices[identifier] else {
            return
        }

        dumpers.removeValue(forKey: identifier)
        devices.removeValue(forKey: identifier)

        central.scanForPeripherals(withServices: nil, options: nil)

        NotificationCenter.default.post(name: PBTDNDeviceDisconnected, object: device)
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

        guard let device = devices[identifier] else {
            return
        }

        device.central = central
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        peripheral.respond(to: request, withResult: .success)
        data.value = Data([0x0f, 0x00])

        let identifier = request.central.identifier

        guard let device = devices[identifier] else {
            return
        }

        NotificationCenter.default.post(name: PBTDNDeviceReady, object: device)
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
    public func updateValue(_ value: Data, forDevice device: Device) -> Bool {
        guard let central = device.central else {
            return false
        }

        return peripheralManager!.updateValue(value, for: data, onSubscribedCentrals: [central])
    }
}
