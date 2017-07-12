//
//  PolarDump.swift
//  polarbtdump
//
//  Created by Adam Kuczyński on 28.05.2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import Foundation

public protocol DumperDelegate {

    func updateValue(_ value: Data, forCentral identifier: UUID) -> Bool
}

public class Dumper: NSObject {

    private var delegate: DumperDelegate
    private var identifier: UUID

    private var currentPath: String?
    private var pathsToVisit = [String]()
    private var recvChunks = [PSChunk]()
    private var recvPackets = [PSPacket]()
    private var sendChunks = [PSChunk]()
    private var sendPackets = [Data]()

    init(_ identifier: UUID, delegate: DumperDelegate) {
        self.delegate = delegate
        self.identifier = identifier
    }
    
    public func dump() {
        let notification = NSUserNotification()
        notification.title = "Sync started"
        notification.informativeText = identifier.description
        NSUserNotificationCenter.default.deliver(notification)
        sendRaw(Constants.Packets.SyncBegin)

        pathsToVisit.append("/U/0/")
        dumpNext()
    }
    
    private func dumpNext() {
        if pathsToVisit.count == 0 {
            let notification = NSUserNotification()
            notification.title = "Sync finished"
            notification.informativeText = identifier.description
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
    private func sendRequest(_ request: Request) {
        let message = PSMessage(request)
        sendChunks = PSMessage.encode(message)

        sendChunk()
    }
    
    private func sendChunk() {
        let chunk = sendChunks.removeFirst()

        for packet in PSChunk.encode(chunk) {
            sendPackets.append(PSPacket.encode(packet))
        }

        sendPacket()
    }
    
    public func sendPacket() {
        while sendPackets.count > 0 {
            if !delegate.updateValue(sendPackets[0], forCentral: identifier) {
                break
            }
            
            sendPackets.removeFirst()
        }
    }
    
    private func sendRaw(_ value: Data) {
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
    
    private func recvChunk(_ packets: [PSPacket]) {
        let chunk = PSChunk.decode(packets)
        recvChunks.append(chunk)
        
        if packets.last!.more {
            sendRaw(Data([0x09, chunk.number]))
        } else {
            recvMessage(recvChunks)
            recvChunks.removeAll()
        }
    }
    
    private func recvMessage(_ chunks: [PSChunk]) {
        let message = PSMessage.decode(chunks)

        if currentPath!.hasSuffix("/") {
            recvDirectory(message)
        } else {
            recvFile(message)
        }

        dumpNext()
    }

    private func recvDirectory(_ message: PSMessage) {
        guard let path = currentPath else {
            return
        }

        let url = PBTDUrlForPath(path, forDevice: identifier)
        let content = Data(message.payload.dropLast())

        let list = try! Directory(serializedData: content)

        for entry in list.entries {
            let childPath = path + entry.path
            let childUrl = PBTDUrlForPath(childPath, forDevice: identifier)

            if PBTDShouldUpdate(entry, url: childUrl) {
                pathsToVisit.append(childPath)
            }
        }
    }

    private func recvFile(_ message: PSMessage) {
        guard let path = currentPath else {
            return
        }

        let url = PBTDUrlForPath(path, forDevice: identifier)
        let content = Data(message.payload.dropLast())

        try! content.write(to: url)
    }
}

