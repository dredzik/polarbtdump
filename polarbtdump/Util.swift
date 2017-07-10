//
//  Utils.swift
//  btproxy_mobile
//
//  Created by Adam Kuczyński on 05.06.2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import Foundation

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

func PBTDUrlForPath(_ path: String) -> URL {
    let manager = FileManager.default
    let identifier = Bundle.main.bundleIdentifier

    let rootDirectory = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let applicationDirectory = rootDirectory.appendingPathComponent(identifier!)

    try! manager.createDirectory(at: applicationDirectory, withIntermediateDirectories: true, attributes: nil)

    let url = applicationDirectory.appendingPathComponent(path)

    if url.hasDirectoryPath {
        try! manager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    print(url)

    return url
}

func PBTDShouldUpdate(_ entry: Directory.Entry, url: URL) -> Bool {
    let manager = FileManager.default
    let path = url.path

    if url.hasDirectoryPath {
        return true
    }

    if !manager.fileExists(atPath: path) {
        return true
    }

    let local = try! manager.attributesOfItem(atPath: path)[.size] as! Int
    let remote = Int(entry.size)

    return local != remote
}
