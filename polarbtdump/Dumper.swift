//
//  PolarDump.swift
//  polarbtdump
//
//  Created by Adam Kuczyński on 28.05.2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import CoreBluetooth
import Foundation

public protocol DumperDelegate {

    func updateValue(_ value: Data) -> Bool
}

public class Dumper: NSObject {

    var delegate: DumperDelegate
    var device: CBPeripheral
    var currentPath: String?
    var pathsToVisit = [String]()
    var recvChunks = [PSChunk]()
    var recvPackets = [PSPacket]()
    var sendChunks = [PSChunk]()
    var sendPackets = [Data]()

    init(device: CBPeripheral, delegate: DumperDelegate) {
        self.device = device
        self.delegate = delegate
    }
    
    func dump() {
        let notification = NSUserNotification()
        notification.title = "Sync started"
        notification.informativeText = device.name
        NSUserNotificationCenter.default.deliver(notification)
        sendRaw(Constants.Packets.SyncBegin)

        pathsToVisit.append("/U/0/")
        dumpNext()
    }
    
    func dumpNext() {
        if pathsToVisit.count == 0 {
            let notification = NSUserNotification()
            notification.title = "Sync finished"
            notification.informativeText = device.name
            NSUserNotificationCenter.default.deliver(notification)

            sendRaw(Constants.Packets.SyncEnd)
            sendRaw(Constants.Packets.SessionEnd)

            return
        }
        
        currentPath = pathsToVisit.removeFirst()
        let request = Request.with {
            $0.type = .read
            $0.path = currentPath!
        }

        sendRequest(request)
    }
    
    // Sending
    func sendRequest(_ request: Request) {
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
            if !delegate.updateValue(sendPackets[0]) {
                break
            }
            
            sendPackets.removeFirst()
        }
    }
    
    public func sendRaw(_ value: Data) {
        sendPackets.append(value)
        sendPacket()
    }
    
    // Receiving
    public func recvPacket(_ value: Data) {
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
            sendRaw(Data([0x09, chunk.number]))
        } else {
            recvMessage(recvChunks)
            recvChunks.removeAll()
        }
    }
    
    public func recvMessage(_ chunks: [PSChunk]) {
        let message = PSMessage.decode(chunks)

        if currentPath!.hasSuffix("/") {
            recvDirectory(message)
        } else {
            recvFile(message)
        }

        dumpNext()
    }

    public func recvDirectory(_ message: PSMessage) {
        guard let path = currentPath else {
            return
        }

        let url = PBTDUrlForPath(path)
        let content = Data(message.payload.dropLast())

        let list = try! Directory(serializedData: content)

        for entry in list.entries {
            let childPath = path + entry.path
            let childUrl = PBTDUrlForPath(childPath)

            if PBTDShouldUpdate(entry, url: childUrl) {
                pathsToVisit.append(childPath)
            }
        }
    }

    public func recvFile(_ message: PSMessage) {
        guard let path = currentPath else {
            return
        }

        let url = PBTDUrlForPath(path)
        let content = Data(message.payload.dropLast())

        try! content.write(to: url)
    }
}

