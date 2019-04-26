//
//  MobilityKit.swift
//  Main interface for app integration
//
//  Created by Tobias Frech on 07.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit

/**
 MobilityKit
 */
public class MobilityKit {
    
    static let didDetectNewDeviceNotification = NSNotification.Name("MobilityKit.didDetectNewDeviceNotification")
    static let didArriveNotification = NSNotification.Name("MobilityKit.didArriveNotification")
    static let didDepartNotification = NSNotification.Name("MobilityKit.didDepartNotification")
    static let didChangeTransportNotification = NSNotification.Name("MobilityKit.didChangeTransportNotification")
    static let didDetectBluetoothAvailabilityNotification = NSNotification.Name("MobilityKit.didDetectBluetoothAvailabilityNotification")

    private static let shared = MobilityKit()
    private var delegate: MobilityKitDelegate?
    
    /**
     The delegate of the MobilityKit receiving the events and updates
     */
    public static var delegate: MobilityKitDelegate? {
        set { shared.delegate = newValue }
        get { return shared.delegate }
    }
    
    private var permission: Permission
    private var trackingManager: TrackingManager

    
    // keep it private
    private init() {
        permission = Permission()
        trackingManager = TrackingManager()
    }
    
    /**
     Start mobility tracking
     */
    public static func start() {
        shared.addObserver()
        shared.trackingManager.start()
    }
    
    /**
     Stop mobility tracking
     */
    public static func stop() {
        shared.trackingManager.stop()
        shared.removeObserver()
    }
    
    private func addObserver() {
        removeObserver()
        NotificationCenter.default.addObserver(self, selector: #selector(handleTransportChange), name: MobilityKit.didChangeTransportNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleArrival), name: MobilityKit.didArriveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDeparture), name: MobilityKit.didDepartNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewDevice), name: MobilityKit.didDetectNewDeviceNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleBluetooth), name: MobilityKit.didDetectBluetoothAvailabilityNotification, object: nil)
    }
    
    private func removeObserver() {
        NotificationCenter.default.removeObserver(self, name: MobilityKit.didChangeTransportNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: MobilityKit.didArriveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: MobilityKit.didDepartNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: MobilityKit.didDetectNewDeviceNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: MobilityKit.didDetectBluetoothAvailabilityNotification, object: nil)
    }
    
    // Mark - Notifications
    
    @objc private func handleTransportChange(_ notification: Notification) {
        if let transport = notification.object as? MBTransport {
            delegate?.mobilityKit?(didChange: transport)
        }
    }
    
    @objc private func handleArrival(_ notification: Notification) {
        if let location = notification.object as? MBLocation {
            delegate?.mobilityKit?(didArrive: location)
        }
    }
    
    @objc private func handleDeparture(_ notification: Notification) {
        if let location = notification.object as? MBLocation {
            delegate?.mobilityKit?(didDepart: location)
        }
    }
    
    @objc private func handleNewDevice(_ notification: Notification) {
        if let device = notification.object as? MBDevice {
            delegate?.mobilityKit?(didDetect: device)
        }
    }
    
    @objc private func handleBluetooth(_ notification: Notification) {
        if let available = notification.object as? Bool {
            if available {
                delegate?.mobilityKit?(bluetooth: true)
            } else {
                delegate?.mobilityKit?(bluetooth: false)
            }
        }
    }


    // Mark - Timeline Model API

    /**
     Get the current model with visited places and mobility timeline
     */
    public static func model() -> MBModel {
        return Timeline.model(trackings: shared.trackingManager.trackings, visits: shared.trackingManager.visits)
    }
    
    
    // Mark - DeviceManager API
    
    /**
     Get list of detected devices
     
     - returns:
     An array of all detected devices
     */
    public static func devices() -> [MBDevice] {
        return shared.trackingManager.devices()
    }
    
    /**
     Configure a detected device as a car
     
     - parameters:
        - deviceUID: The unique ID of the device
        - registeredAsCar: If `true`, set this device as a car
     */
    public static func update(deviceUID: String, registeredAsCar: Bool) {
        shared.trackingManager.update(deviceUID: deviceUID, registeredAsCar: registeredAsCar)
    }
    

    
    // Mark - Permission Handling
    
    /**
     Request permission to CoreMotion activity recognition
     */
    public static func requestMotionPermission(_ result: @escaping PermissionCallback) {
        shared.permission.requestMotion(result)
    }
    
    /**
     Request permission to CoreLocation location updates (always)
     */
    public static func requestLocationPermission(_ result: @escaping PermissionCallback) {
        shared.permission.requestLocation(result)
    }
    
    /**
     Check current state of permission to activity recognition
     
     - returns:
     Status of the permission
     */
    public static func checkMotionPermission() -> PermissionStatus {
        return shared.permission.motionStatus()
    }
    
    /**
     Check current state of permission to location updates (always)
     
     - returns:
     Status of the permission
     */
    public static func checkLocationPermission() -> PermissionStatus {
        return shared.permission.locationStatus()
    }

}

/**
 Delegate of MobilityKit
 */
@objc public protocol MobilityKitDelegate {
    
    /**
     Is called every time, when a new devices was detected (HFP or CarPlay)
     */
    @objc optional func mobilityKit(didDetect newDevice: MBDevice)
    
    /**
     Is called every time, when an arrival event was detected
     */
    @objc optional func mobilityKit(didArrive location: MBLocation)
    
    /**
     Is called every time, when a departure event was detected
     */
    @objc optional func mobilityKit(didDepart location: MBLocation)
    
    /**
     Is called every time, when a change of the transport type was detected (transport type or confidence level)
     */
    @objc optional func mobilityKit(didChange transport: MBTransport)
    
    /**
     Is called every time, when the bluetooth availablity changes (e.g. switching off Bluetooth)
     */
    @objc optional func mobilityKit(bluetooth isAvailable: Bool)
}


