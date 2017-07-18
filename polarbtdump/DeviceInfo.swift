//
//  DeviceInfo.swift
//  polarbtdump
//
//  Created by Adam Kuczynski on 14/07/2017.
//  Copyright © 2017 typedef.io. All rights reserved.
//

import Foundation

public class DeviceInfo: NSObject {

    public override init() {
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(self.readDeviceInfo(_:)), name: Notifications.DeviceInfo.Start, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func readDeviceInfo(_ notification: Notification) {
        guard let device = notification.object as? Device else {
            return
        }

        let request = PolarRequest.with {
            $0.type = .read
            $0.path = "/DEVICE.BPB"
        }

        let message = PSMessage(request)

        NotificationCenter.default.addObserver(self, selector: #selector(self.recvDeviceInfo(_:)), name: Notifications.Message.Recv, object: device)
        NotificationCenter.default.post(name: Notifications.DeviceInfo.Started, object: device)
        NotificationCenter.default.post(name: Notifications.Message.Send, object: device, userInfo: ["Data" : message])
    }

    func recvDeviceInfo(_ notification: Notification) {
        guard let device = notification.object as? Device else {
            return
        }

        if let message = notification.userInfo?["Data"] as? PSMessage {
            let info = try! PolarDevice(serializedData: message.data)
            device.identifier = info.deviceID
        }

        NotificationCenter.default.removeObserver(self, name: Notifications.Message.Recv, object: device)
        NotificationCenter.default.post(name: Notifications.DeviceInfo.Finished, object: device)
    }
}
