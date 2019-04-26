//
//  Power.swift
//  Monitors power and charging state of the phone battery
//
//  Created by Tobias Frech on 07.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import UIKit

class Power {
    public static func externalSource() -> Bool {
        return UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
    }
    
    public static func state() -> PowerState {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return PowerState(externalSource: externalSource(), batteryLevel: Double(UIDevice.current.batteryLevel * 100).rounded())
    }
}

struct PowerState: Codable {
    public var externalSource: Bool
    public var batteryLevel: Double
}

