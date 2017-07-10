//
//  Utils.swift
//  btproxy_mobile
//
//  Created by Adam Kuczyński on 05.06.2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import Foundation

func hex(data: [UInt8]) -> String {
    var result = "["
    
    data.forEach({body in
        result += String(format: "0x%02X,", body)
    })
    
    return result + "]"
}

func shouldUpdate(_ entry: Directory.Entry, withPath local: String) -> Bool {
    if local.hasSuffix("/") {
        return true
    }
    
    if !FileManager.default.fileExists(atPath: local) {
        return true
    }
    
    let remoteSize = Int(entry.size)
    let localSize = try! FileManager.default.attributesOfItem(atPath: local)[FileAttributeKey.size] as! Int
    
    return localSize != remoteSize
}

func proto2date(_ proto: PolarDateTime) -> Date {
    var c = DateComponents()

    c.year = Int(proto.date.year)
    c.month = Int(proto.date.month)
    c.day = Int(proto.date.day)
    c.hour = Int(proto.time.hour)
    c.minute = Int(proto.time.minute)
    c.second = Int(proto.time.second)
    
    c.timeZone = NSTimeZone(forSecondsFromGMT: Int(proto.timezone) * 60) as TimeZone
    
    return NSCalendar.autoupdatingCurrent.date(from: c)!
}

func formatDate(_ date: Date) -> String {
    let f = DateFormatter()
    
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    f.timeZone = NSTimeZone(forSecondsFromGMT: 0) as TimeZone!
    
    return f.string(from: date)
}
