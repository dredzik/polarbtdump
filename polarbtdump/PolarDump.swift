//
//  PolarDump.swift
//  polarbtdump
//
//  Created by Adam Kuczyński on 28.05.2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import CoreBluetooth
import Foundation

public class PolarDump : NSObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    
    var pm : CBPeripheralManager?
    var cm : CBCentralManager?
    var p : CBPeripheral?
    let s = CBMutableService(type: Constants.UUIDs.Service, primary: true)
    let cd = CBMutableCharacteristic(type: Constants.UUIDs.DataChar, properties: Constants.Props, value: nil, permissions: Constants.Perms)
    let cn = CBMutableCharacteristic(type: Constants.UUIDs.NotiChar, properties: Constants.Props, value: nil, permissions: Constants.Perms)
    
    public override init() {
        super.init()
        s.characteristics = [cd, cn]
        pm = CBPeripheralManager(delegate: self, queue: dispatch_get_main_queue())
        cm = CBCentralManager(delegate: self, queue: dispatch_get_main_queue())
    }
    
    // CBCentralManagerDelegate
    public func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == .PoweredOn {
            central.scanForPeripheralsWithServices(nil, options: nil)
        } else {
            central.stopScan()
        }
    }
    
    public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        if peripheral.name == nil || !peripheral.name!.containsString("Polar") {
            return
        }
        
        p = peripheral
        
        central.stopScan()
        central.connectPeripheral(peripheral, options: nil)
    }
    
    public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print(SUCC, "connected to", peripheral.name!)
    }
    
    public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print(FAIL, "disconnected from", peripheral.name!)
        p = nil
        central.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    // CBPeripheralManagerDelegate
    public func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        if peripheral.state == .PoweredOn {
            peripheral.addService(s)
        } else {
            peripheral.removeAllServices()
        }
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, didAddService service: CBService, error: NSError?) {
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey : Constants.UUIDs.Service,
            CBAdvertisementDataLocalNameKey : "Polar mobile 666",
            CBAdvertisementDataIsConnectable : true,
        ])
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, didReceiveReadRequest request: CBATTRequest) {
        cd.value = a2d([0x0f, 0x00])
        peripheral.respondToRequest(request, withResult: .Success)
        
        print(SUCC, "device ready")
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequest request: CBATTRequest) {
        if let value = request.value {
            cd.value = value
        }
        
        peripheral.respondToRequest(request, withResult: .Success)
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequests requests: [CBATTRequest]) {
        for request in requests {
            self.peripheralManager(peripheral, didReceiveWriteRequest: request)
        }
    }
    
    public func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
    }
    
    // PolarDump
}

