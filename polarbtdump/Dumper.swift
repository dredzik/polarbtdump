//
//  PolarDump.swift
//  polarbtdump
//
//  Created by Adam Kuczyński on 28.05.2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import CoreBluetooth
import Foundation

public class Dumper : NSObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    
    var centralManager : CBCentralManager?
    var peripheralManager : CBPeripheralManager?

    var device : CBPeripheral?

    let service = CBMutableService(type: Constants.UUIDs.Service, primary: true)
    let data = CBMutableCharacteristic(type: Constants.UUIDs.Data, properties: Constants.Props, value: nil, permissions: Constants.Perms)
    let unknown1 = CBMutableCharacteristic(type: Constants.UUIDs.Unknown1, properties: Constants.Props, value: nil, permissions: Constants.Perms)
    let unknown2 = CBMutableCharacteristic(type: Constants.UUIDs.Unknown2, properties: Constants.Props, value: nil, permissions: Constants.Perms)
    
    public override init() {
        super.init()

        service.characteristics = [data, unknown1, unknown2]

        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    // CBCentralManagerDelegate
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

        if name.range(of: "Polar") == nil || name.range(of: "Polar mobile") != nil {
            return
        }
        
        device = peripheral
        
        central.stopScan()
        central.connect(peripheral, options: nil)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print(SUCC, "connected to", peripheral.name!)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print(error == nil ? SUCC : FAIL, "disconnected from", peripheral.name!)

        device = nil

        central.scanForPeripherals(withServices: nil, options: nil)
    }
    
    // CBPeripheralManagerDelegate
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
        print(SUCC, "device subscribed for", characteristic.uuid.uuidString)
        peripheral.setDesiredConnectionLatency(.low, for: central)
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print(SUCC, "read requested on", request.characteristic.uuid.uuidString)
        peripheral.respond(to: request, withResult: .success)
        data.value = a2d([0x0f, 0x00])
        
        dump()
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite request: CBATTRequest) {
        peripheral.respond(to: request, withResult: .success)
        if let value = request.value {
            data.value = value
            recvPacket(d2a(value))
        }        
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            self.peripheralManager(peripheral, didReceiveWrite: request)
        }
    }

    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sendPacket()
    }
    
    // Dumper
    var dumpCurrent : String?
    var dumpPaths = [String]()
    var recvChunks = [PSChunk]()
    var recvPackets = [PSPacket]()
    var sendChunks = [PSChunk]()
    var sendPackets = [[UInt8]]()
    
    func dump() {
        print(SUCC, "dump started")
        sendRaw(Constants.Packets.SyncBegin)

        dumpPaths.append("/U/0/")
        dumpNext()
    }
    
    func dumpNext() {
        if dumpPaths.count == 0 {
            print(SUCC, "dump finished")

            sendRaw(Constants.Packets.SyncEnd)
            sendRaw(Constants.Packets.SessionEnd)

            return
        }
        
        dumpCurrent = dumpPaths.removeFirst()
        let request = Request.with {
            $0.type = .read
            $0.path = dumpCurrent!
        }

        sendRequest(request)
    }
    
    // Sending
    func sendRequest(_ request: Request) {
        print(SUCC, (request.path.hasSuffix("/") ? "visiting" : "downloading"), request.path)
        
        let message = PSMessage(request)
        sendChunks = PSMessage.encode(message)

        sendChunk()
    }
    
    public func sendChunk() {
        let chunk = sendChunks.removeFirst()

        for packet in PSChunk.encode(chunk) {
            sendPackets.append(PSPacket.encode(packet))
        }

        sendPacket()
    }
    
    public func sendPacket() {
        while sendPackets.count > 0 {
            if !peripheralManager!.updateValue(a2d(sendPackets[0]), for: data, onSubscribedCentrals: nil) {
                break
            }
            
            sendPackets.removeFirst()
        }
    }
    
    public func sendRaw(_ value: [UInt8]) {
        sendPackets.append(value)
        sendPacket()
    }
    
    // Receiving
    public func recvPacket(_ value: [UInt8]) {
        print(".", separator: "", terminator: "")
        fflush(__stdoutp)

        let packet = PSPacket.decode(value)
        recvPackets.append(packet)
        
        if packet.sequence == 0 {
            recvChunk(recvPackets)
            recvPackets.removeAll()
        }
    }
    
    public func recvChunk(_ packets: [PSPacket]) {
        let chunk = PSChunk.decode(packets)
        recvChunks.append(chunk)
        
        if packets.last!.more {
            sendRaw([0x09, chunk.number])
        } else {
            print()
            recvMessage(recvChunks)
            recvChunks.removeAll()
        }
    }
    
    public func recvMessage(_ chunks: [PSChunk]) {
        let message = PSMessage.decode(chunks)

        if dumpCurrent!.hasSuffix("/") {
            recvDirectory(message)
        } else {
            recvFile(message)
        }

        dumpNext()
    }

    public func recvDirectory(_ message: PSMessage) {
        let remoteDirectory = dumpCurrent!
        let localDirectory = BackupRoot + remoteDirectory
        let content = a2d(Array(message.payload.dropLast()))
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: localDirectory) {
            try! fileManager.createDirectory(atPath: localDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        let list = try! Directory(serializedData: content)

        for entry in list.entries {
            let remoteEntry = remoteDirectory + entry.path
            let localEntry = localDirectory + entry.path

            if shouldUpdate(entry, withPath: localEntry) {
                dumpPaths.append(remoteEntry)
            }
        }
    }

    public func recvFile(_ message: PSMessage) {
        let remoteFile = dumpCurrent!
        let localFile = BackupRoot + remoteFile
        let content = a2d(Array(message.payload.dropLast()))

        try! content.write(to: URL(string: "file://" + localFile)!)
    }
}

