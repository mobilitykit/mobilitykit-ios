//
//  Mobility.swift
//  Data structure for a detected mobility state (incl. detected motion)
//
//  Created by Tobias Frech on 15.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation

//public enum Transport: Int, Codable {
//    case unknown
//    case foot
//    case bike
//    case car
//}

enum Motion: Int, Codable {
    case unknown
    case stationary
    case moving
}

struct Mobility: Codable {
    public var startDate: Date
    public var transport: MBTransport
    public var motion: Motion
    
    public static func == (lhs: Mobility, rhs: Mobility) -> Bool {
        return lhs.transport == rhs.transport && lhs.motion == rhs.motion
    }
    
    public static let Unknown = Mobility(startDate: Date(timeIntervalSince1970: 0.0), transport: .unknown, motion: .unknown)
}
