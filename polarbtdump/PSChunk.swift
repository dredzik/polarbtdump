//
//  Chunk.swift
//  polarbtdump
//
//  Created by Adam Kuczynski on 06/06/2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import Foundation

let CHUNK_PAYLOAD_SIZE = 303

public class PSChunk : NSObject {
    
    var type : PSPacketType = .Normal
    var notification : Bool = false
    var more : Bool = false
    var number : UInt8 = 0
    var payload : [UInt8] = [UInt8]()
    
    public static func decode(_ packets: [PSPacket]) -> PSChunk {
        let result = PSChunk()
        
        result.type = packets[0].type

        if result.type == .Normal {
            result.notification = packets[0].notification
            result.more = packets[0].more
        }
        
        result.number = packets[0].payload.first!
        
        for packet in packets {
            let start = packets.first! == packet ? 1 : 0

            if start < packet.payload.count {
                result.payload += packet.payload[start...packet.payload.count-1]
            }
        }
    
        return result
    }
    
    public static func encode(_ chunk: PSChunk) -> [PSPacket] {
        var result = [PSPacket]()
        var data = [chunk.number] + chunk.payload
        
        while data.count > 0 {
            let packet = PSPacket()
            let end = data.count > PACKET_PAYLOAD_SIZE ? PACKET_PAYLOAD_SIZE : data.count
            
            packet.more = chunk.more
            packet.payload = Array(data[0...end-1])
            data.removeFirst(end)
            
            result.append(packet)
        }
        
        for i in 0..<result.count {
            result[i].sequence = UInt8(result.count - (i + 1))
        }
        
        result.first?.first = true
        
        return result
    }
}
