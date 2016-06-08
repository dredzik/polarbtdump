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
    let c1 = CBMutableCharacteristic(type: Constants.UUIDs.Char1, properties: [.WriteWithoutResponse], value: nil, permissions: [.Writeable])
    let c2 = CBMutableCharacteristic(type: Constants.UUIDs.Char2, properties: [.WriteWithoutResponse, .Notify], value: nil, permissions: [.Readable, .Writeable])
    let cd = CBMutableCharacteristic(type: Constants.UUIDs.CharD, properties: [.WriteWithoutResponse, .Notify, .Read], value: nil, permissions: [.Readable, .Writeable])
    
    public override init() {
        super.init()
        s.characteristics = [cd, c1, c2]
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
        if peripheral.name == nil || !peripheral.name!.containsString("Polar") || peripheral.name!.containsString("Polar mobile") {
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
            CBAdvertisementDataLocalNameKey : "Polar mobile 10148139",
            CBAdvertisementDataIsConnectable : true,
        ])
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, didReceiveReadRequest request: CBATTRequest) {
        peripheral.respondToRequest(request, withResult: .Success)
        cd.value = a2d([0x0f, 0x00])
        
        peripheral.setDesiredConnectionLatency(.Low, forCentral: request.central)
        print(SUCC, "device ready")
        dump()
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequest request: CBATTRequest) {
        peripheral.respondToRequest(request, withResult: .Success)
        if let value = request.value {
            cd.value = value
            recvp(d2a(value))
        }        
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

        sendra.append("/U/0/")
        nextr()
    }
    
    func nextr() {
        if sendra.count == 0 {
            print(SUCC, "dump finished")
            sendraw([0x0A, 0x00, 0x01, 0x08, 0x01, 0x0])

            return
        }
        
        r = sendra.removeFirst()
        sendr(try! Request.Builder().setTypes(.Read).setPath(r!).build())
    }
    
    func sendr(request: Request) {
        print(SUCC, (request.path.hasSuffix("/") ? "visiting" : "downloading"), request.path)
        
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
                let full = current + entry.path
                
                if shouldUpdate(entry, withPath: local + entry.path) {
                    sendra.append(full)
                }
            }
        } else {
            try! a2d(Array(message.payload.dropLast())).writeToFile(local, options: .AtomicWrite)
        }

        nextr()
    }
}

