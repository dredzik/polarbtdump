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
        print(error == nil ? SUCC : FAIL, "disconnected from", peripheral.name!)
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
            CBAdvertisementDataTxPowerLevelKey : 3
        ])
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, didReceiveReadRequest request: CBATTRequest) {
        cd.value = a2d([0x0f, 0x00])
        peripheral.respondToRequest(request, withResult: .Success)
        
        peripheral.setDesiredConnectionLatency(.Low, forCentral: request.central)
        print(SUCC, "device ready")
        dump()
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequest request: CBATTRequest) {
        if let value = request.value {
            cd.value = value
            recvp(d2a(value))
        }
        
        peripheral.respondToRequest(request, withResult: .Success)
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequests requests: [CBATTRequest]) {
        for request in requests {
            self.peripheralManager(peripheral, didReceiveWriteRequest: request)
        }
    }
    
    public func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
        sendp()
    }
    
    // PolarDump
    var recvpa = [PSPacket]()
    var recvca = [PSChunk]()
    var sendpa = [[UInt8]]()
    var sendca = [PSChunk]()
    var sendra = [String]()
    var r : String?
    
    func dump() {
        print(SUCC, "dump started")
        
        sendraw([0x0A, 0x00, 0x00, 0x00])

        sendra.append("/")
        nextr()
    }
    
    func nextr() {
        if sendra.count == 0 {
            print(SUCC, "dump finished")
            
            sendraw([0x0A, 0x00, 0x01, 0x00])

            return
        }
        
        r = sendra.removeFirst()
        sendr(try! Request.Builder().setTypes(.Read).setPath(r!).build())
    }
    
    func sendr(request: Request) {
        print(SUCC, "downloading", request.path)
        
        let data = d2a(request.data())
        let message = PSMessage()
        message.header = [UInt8(data.count), 0x00]
        message.payload = data + [0x00]
        
        sendca = PSMessage.encode(message)
        sendc()
    }
    
    public func sendc() {
        let chunk = sendca.removeFirst()

        for packet in PSChunk.encode(chunk) {
            sendpa.append(PSPacket.encode(packet))
        }

        sendp()
    }
    
    public func sendp() {
        while sendpa.count > 0 {
            if !pm!.updateValue(a2d(sendpa[0]), forCharacteristic: cd, onSubscribedCentrals: nil) {
                break
            }
            
            sendpa.removeFirst()
        }
    }
    
    public func sendraw(value: [UInt8]) {
        sendpa.append(value)
        sendp()
    }
    
    public func recvp(value: [UInt8]) {
        print(".", separator: "", terminator: "")
        let packet = PSPacket.decode(value)
        recvpa.append(packet)
        
        if (packet.sequence == 0) {
            recvc(recvpa)
            recvpa.removeAll()
        }
    }
    
    public func recvc(packets: [PSPacket]) {
        let chunk = PSChunk.decode(packets)
        recvca.append(chunk)
        
        if (packets.last!.more) {
            sendraw([0x09, chunk.number])
        } else {
            recvm(recvca)
            recvca.removeAll()
        }
    }
    
    public func recvm(chunks: [PSChunk]) {
        print()
        let message = PSMessage.decode(chunks)
        let current = r!
        let local = BackupRoot + current

        if (current.hasSuffix("/")) {
            if (!NSFileManager.defaultManager().fileExistsAtPath(local)) {
                try! NSFileManager.defaultManager().createDirectoryAtPath(local, withIntermediateDirectories: true, attributes: nil)
            }
            
            let list = try! Directory.parseFromData(a2d([] + message.payload.dropLast()))

            for entry in list.entries {
                sendra = [current + entry.path] + sendra
            }
        } else {
            try! a2d(Array(message.payload.dropLast())).writeToFile(local, options: .AtomicWrite)
        }

        nextr()
    }
}
