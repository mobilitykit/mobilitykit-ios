//
//  MBDevice.swift
//  Data structure for detected devices
//
//  Created by Tobias Frech on 12.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import AVFoundation

/**
 Detected connected device (CarPlay or Bluetooth using Handsfree Profile (HFP))
 */

@objc public class MBDevice: NSObject, Codable {
    
    /**
     Name of the device
     */
    public var name: String

    /**
     Unique ID of the device
     */
    public var uid: String
    
    /**
     If `true`, this device was connected using HFP
     */
    public var bluetoothHFP: Bool

    /**
     If `true`, this device is a CarPlay device
     */
    public var carAudio: Bool
    
    /**
     If `true`, the device was registered as a car
     */
    public var registeredAsCar: Bool
    
    var activityTotalCount: Int
    var activityAutomotiveCount: Int
    
    init(_ input: AVAudioSessionPortDescription) {
        name = input.portName
        uid = input.uid
        bluetoothHFP = (input.portType == .bluetoothHFP)
        carAudio = (input.portType == .carAudio)
        registeredAsCar = false
        activityTotalCount = 0
        activityAutomotiveCount = 0
    }
    
    /**
     Indicating the probability that this device is a car (value between 0 and 1.0)
     */
    public var carProbability: Double {
        get {
            guard activityTotalCount >= 5 else { return 0.0 }
            return Double(activityAutomotiveCount) / Double(activityTotalCount)
        }
    }
    
    /**
     If `true`, the device was identified as a car
     */
    public var inCarDevice: Bool {  get { return carAudio || registeredAsCar || carProbability >= 0.85 } }
}

