//
//  Device.swift
//  polarbtdump
//
//  Created by Adam Kuczynski on 13/07/2017.
//  Copyright © 2017 typedef.io. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol DeviceDelegate {
    func send(_ value: Data, forDevice device: Device) -> Bool
}

public class Device: NSObject {

    private let delegate: DeviceDelegate

    public let identifier: UUID
    public let name: String
    public var central: CBCentral?
    public let peripheral: CBPeripheral

    private var sendPackets = [Data]()
    private var recvChunks = [PSChunk]()
    private var recvPackets = [PSPacket]()

    public init(_ delegate: DeviceDelegate, peripheral: CBPeripheral) {
        self.delegate = delegate

        self.identifier = peripheral.identifier
        self.name = peripheral.name!
        self.peripheral = peripheral

        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationMessageSend(_:)), name: Notifications.Message.Send, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationMessageSendRaw(_:)), name: Notifications.Message.SendRaw, object: self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func send() {
        while sendPackets.count > 0 {
            if !delegate.send(sendPackets[0], forDevice: self) {
                break
            }

            sendPackets.removeFirst()
        }
    }

    public func recv(_ value: Data) {
        recvPacket(value)
    }

    // MARK: Send
    private func sendMessage(_ message: PSMessage) {
        for chunk in PSMessage.encode(message) {
            for packet in PSChunk.encode(chunk) {
                sendPackets.append(PSPacket.encode(packet))
            }
        }

        send()
    }

    private func sendMessageRaw(_ value: Data) {
        sendPackets.append(value)
        send()
    }

    // MARK: Recv
    private func recvMessage(_ chunks: [PSChunk]) {
        let message = PSMessage.decode(chunks)

        NotificationCenter.default.post(name: Notifications.Message.Recv, object: self, userInfo: ["Data" : message])
    }

    private func recvChunk(_ packets: [PSPacket]) {
        let chunk = PSChunk.decode(packets)
        recvChunks.append(chunk)

        if packets.last!.more {
            sendMessageRaw(Data([0x09, chunk.number]))
        } else {
            recvMessage(recvChunks)
            recvChunks.removeAll()
        }
    }

    private func recvPacket(_ value: Data) {
        let packet = PSPacket.decode(value)
        recvPackets.append(packet)

        if packet.sequence == 0 {
            recvChunk(recvPackets)
            recvPackets.removeAll()
        }
    }

    // MARK: Notifications
    func notificationMessageSend(_ aNotification: Notification) {
        guard let message = aNotification.userInfo?["Data"] as? PSMessage else {
            return
        }

        sendMessage(message)
    }

    func notificationMessageSendRaw(_ aNotification: Notification) {
        guard let data = aNotification.userInfo?["Data"] as? Data else {
            return
        }

        sendMessageRaw(data)
    }
}
