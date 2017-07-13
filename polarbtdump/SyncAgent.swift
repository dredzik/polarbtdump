//
//  SyncAgent.swift
//  polarbtdump
//
//  Created by Adam Kuczyński on 28.05.2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import Foundation

public class SyncAgent: NSObject {

    private var device: Device

    private var currentPath: String?
    private var pathsToVisit = [String]()
    private var recvChunks = [PSChunk]()
    private var recvPackets = [PSPacket]()
    private var sendChunks = [PSChunk]()
    private var sendPackets = [Data]()

    init(_ device: Device) {
        self.device = device

        super.init()

        NotificationCenter.default.addObserver(forName: PBTDNDeviceReady, object: device, queue: nil, using: self.notificationDeviceReady)
        NotificationCenter.default.addObserver(forName: PBTDNPacketRecv, object: device, queue: nil, using: self.notificationPacketRecv)
        NotificationCenter.default.addObserver(forName: PBTDNPacketSendSuccess, object: device, queue: nil, using: self.notificationPacketSendSuccess)
        NotificationCenter.default.addObserver(forName: PBTDNPacketSendReady, object: nil, queue: nil, using: self.notificationPacketSendReady)
    }
    
    private func sync() {
        NotificationCenter.default.post(name: PBTDNSyncStarted, object: device)

        sendRaw(Constants.Packets.SyncBegin)

        pathsToVisit.append("/")
        syncNext()
    }
    
    private func syncNext() {
        if pathsToVisit.count == 0 {
            NotificationCenter.default.post(name: PBTDNSyncFinished, object: device)

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
    
    private func sendPacket() {
        if sendPackets.count > 0 {
            NotificationCenter.default.post(name: PBTDNPacketSend, object: device, userInfo: ["Data" : sendPackets[0]])
        }
    }
    
    private func sendRaw(_ value: Data) {
        sendPackets.append(value)
        sendPacket()
    }
    
    // Receiving
    private func recvPacket(_ value: Data) {
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

        syncNext()
    }

    private func recvDirectory(_ message: PSMessage) {
        guard let path = currentPath else {
            return
        }

        let url = PBTDUrlForPath(path, forDevice: device)
        let content = Data(message.payload.dropLast())

        let list = try! Directory(serializedData: content)

        for entry in list.entries {
            let childPath = path + entry.path
            let childUrl = PBTDUrlForPath(childPath, forDevice: device)

            if PBTDShouldUpdate(entry, url: childUrl) {
                pathsToVisit.append(childPath)
            }
        }
    }

    private func recvFile(_ message: PSMessage) {
        guard let path = currentPath else {
            return
        }

        let url = PBTDUrlForPath(path, forDevice: device)
        let content = Data(message.payload.dropLast())

        try! content.write(to: url)
    }

    // MARK: Notifications
    func notificationDeviceReady(_ aNotification: Notification) {
        sync()
    }

    func notificationPacketRecv(_ aNotification: Notification) {
        guard let data = aNotification.userInfo?["Data"] as? Data else {
            return
        }

        recvPacket(data)
    }

    func notificationPacketSendSuccess(_ aNotification: Notification) {
        sendPackets.removeFirst()
        sendPacket()
    }

    func notificationPacketSendReady(_ aNotification: Notification) {
        sendPacket()
    }
}

