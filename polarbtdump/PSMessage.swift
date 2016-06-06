//
//  Message.swift
//  polarbtdump
//
//  Created by Adam Kuczyński on 05.06.2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import Foundation

public enum PSMessageType {
    case Notification
    case Query
    case Data
    case Unknown
    
    public static func fromMessage(message: PSMessage) -> PSMessageType {
        if message.notification {
            return Notification
        }
        
        if message.header[1] == 0x80 {
            return Query
        }
        
        if message.header[1] == 0x00 {
            return Data
        }
        
        return Unknown
    }
}

public class PSMessage : NSObject {
    var type : PSPacketType = .Normal
    var subtype : PSMessageType = .Data
    var notification : Bool = false
    var header : [UInt8] = [0x00, 0x00]
    var payload : [UInt8] = [UInt8]()
    
    public static func decode(chunks: [PSChunk]) -> PSMessage {
        let result = PSMessage()
        
        result.type = chunks[0].type
        result.notification = chunks[0].notification
        
        if result.type != .Normal {
            return result
        }

        result.header = Array(chunks.first!.payload[0...1])
        result.subtype = PSMessageType.fromMessage(result)

        for chunk in chunks {
            let start = chunks.first! == chunk ? 2 : 0

            if start < chunk.payload.count {
                result.payload += chunk.payload[start...chunk.payload.count-1]
            }
        }
        
        return result
    }
    
    public static func encode(message: PSMessage) -> [PSChunk] {
        var result = [PSChunk]()
        var data = message.header + message.payload
        var number : UInt8 = 0
        
        while data.count > 0 {
            let chunk = PSChunk()
            let end = data.count > CHUNK_PAYLOAD_SIZE ? CHUNK_PAYLOAD_SIZE : data.count
            
            chunk.payload = Array(data[0...end-1])
            data.removeFirst(end)
            
            chunk.number = number
            chunk.more = data.count > 0
            
            result.append(chunk)
            number += 1
        }
    
        return result
    }
}
