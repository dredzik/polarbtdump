//
//  PSPacket.swift
//  polarbtdump
//
//  Created by Adam Kuczynski on 06/06/2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import Foundation

let PACKET_PAYLOAD_SIZE = 19

let FLAG_FIRST = UInt8(0x08)
let FLAG_ERROR = UInt8(0x04)
let FLAG_NOTIFICATION = UInt8(0x02)
let FLAG_MORE = UInt8(0x01)

public enum PSPacketType {
    case Control
    case Continue
    case Error
    case Normal
    
    public static func fromPacket(packet: PSPacket) -> PSPacketType {
        if packet.sequence == 0 && packet.first && packet.error && packet.notification && packet.more {
            return Control
        }
        
        if packet.sequence == 0 && packet.first && packet.more && packet.error {
            return Error
        }
        
        if packet.sequence == 0 && packet.first && packet.more {
            return Continue
        }
        
        return Normal
    }
}

public class PSPacket : NSObject {
    
    var sequence : UInt8 = 0
    var first : Bool = false
    var error : Bool = false
    var notification : Bool = false
    var more : Bool = false
    var type : PSPacketType = .Normal
    var payload : [UInt8] = [UInt8]()
    
    public static func decode(raw: [UInt8]) -> PSPacket {
        let result = PSPacket()
        
        result.sequence = raw[0] >> 4
        result.first = raw[0] & FLAG_FIRST > 0
        result.error = raw[0] & FLAG_ERROR > 0
        result.notification = raw[0] & FLAG_NOTIFICATION > 0
        result.more = raw[0] & FLAG_MORE > 0
        result.payload = Array(raw[1...raw.count-1])
        
        result.type = PSPacketType.fromPacket(result)

        return result
    }
    
    public static func encode(packet: PSPacket) -> [UInt8] {
        var header : UInt8 = packet.sequence << 4
        
        if (packet.first) { header += FLAG_FIRST }
        if (packet.error) { header += FLAG_ERROR }
        if (packet.notification) { header += FLAG_NOTIFICATION }
        if (packet.more) { header += FLAG_MORE }

        return [header] + packet.payload
    }
}
