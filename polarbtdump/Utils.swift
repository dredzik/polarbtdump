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

func d2a(data: NSData) -> [UInt8] {
    var result = [UInt8](count: data.length, repeatedValue: 0)
    data.getBytes(&result, length: data.length)
    return result
}

func a2d(array: [UInt8]) -> NSData {
    return NSData(bytes: array, length: array.count)
}