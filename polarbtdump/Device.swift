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

    public let identifier: UUID
    public let name: String
    public var central: CBCentral?
    public let peripheral: CBPeripheral

    private var sendPackets = [Data]()
    private var recvChunks = [PSChunk]()
    private var recvPackets = [PSPacket]()

    public init(_ peripheral: CBPeripheral) {
        self.identifier = peripheral.identifier
        self.name = peripheral.name!
        self.peripheral = peripheral

        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationMessageSend(_:)), name: Notifications.Message.Send, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationMessageRaw(_:)), name: Notifications.Message.SendRaw, object: self)

        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationPacketRecv(_:)), name: Notifications.Packet.Recv, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationPacketSendSuccess(_:)), name: Notifications.Packet.SendSuccess, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationPacketSendReady(_:)), name: Notifications.Packet.SendReady, object: nil)
    }

    // MARK: Send
    private func sendMessage(_ message: PSMessage) {
        for chunk in PSMessage.encode(message) {
            for packet in PSChunk.encode(chunk) {
                sendPackets.append(PSPacket.encode(packet))
            }
        }

        sendPacket()
    }

    private func sendRaw(_ value: Data) {
        sendPackets.append(value)
        sendPacket()
    }

    private func sendPacket() {
        if sendPackets.count > 0 {
            NotificationCenter.default.post(name: Notifications.Packet.Send, object: self, userInfo: ["Data" : sendPackets[0]])
        }
    }

    // MARK: Recv
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

        NotificationCenter.default.post(name: Notifications.Message.Recv, object: self, userInfo: ["Data" : message])
    }

    // MARK: Notifications
    func notificationMessageSend(_ aNotification: Notification) {
        guard let message = aNotification.userInfo?["Data"] as? PSMessage else {
            return
        }

        sendMessage(message)
    }

    func notificationMessageRaw(_ aNotification: Notification) {
        guard let data = aNotification.userInfo?["Data"] as? Data else {
            return
        }

        sendRaw(data)
    }

    func notificationPacketSendSuccess(_ aNotification: Notification) {
        sendPackets.removeFirst()
        sendPacket()
    }

    func notificationPacketSendReady(_ aNotification: Notification) {
        sendPacket()
    }

    func notificationPacketRecv(_ aNotification: Notification) {
        guard let data = aNotification.userInfo?["Data"] as? Data else {
            return
        }

        recvPacket(data)
    }
}
