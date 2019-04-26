//
//  TrackingManager.swift
//  Main manager to setup and controll the detection services
//
//  Created by Tobias Frech on 06.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import CoreLocation
import CoreMotion
import AVFoundation
import UIKit

class TrackingManager: NSObject, DeviceManagerDelegate, MobilityManagerDelegate, LocationManagerDelegate, BluetoothDelegate, PermissionDelegate, KeepAliveDelegate {
    
    private let dispatchQueue = DispatchQueue(label: "mobilitykit.trackingmanager")
    private let filename = "mobilitykit_trackings.json"
    private let singleLocation = SingleLocation()
    private let bluetooth = Bluetooth()
    private var permission = Permission()
    private let deviceManager = DeviceManager()
    private let mobilityManager = MobilityManager()
    private let locationManager = LocationManager()
    private let keepAlive = KeepAlive()
    private var motionTimeoutTimer: Timer?
    private var isStarted: Bool = false
    
    private var _trackings: [Tracking]
    

    override init() {
        // load trackings
        _trackings = Storage.fileExists(filename, in: .documents) ? Storage.retrieve(filename, from: .documents, as: [Tracking].self) : []

        // create object
        super.init()

        bluetooth.delegate = self
        permission.delegate = self
        mobilityManager.delegate = self
        deviceManager.delegate = self
        locationManager.delegate = self
        keepAlive.delegate = self
    }

    
    func start() {
        guard !isStarted else { return }
        guard permission.locationStatus() == .authorized else { return }
        isStarted = true
        keepAlive.permanentAliveKeeping()
        locationManager.startMonitoring()
        manageServices()
    }

    func stop() {
        mobilityManager.stopMonitoring()
        deviceManager.stopMonitoring()
        locationManager.stopMonitoring()
        keepAlive.stopMonitoring()
        isStarted = false
    }
    
    
    // Mark - Internal stuff
    
    private func manageServices() -> Void {
        guard isStarted else {
            stop()
            return
        }
        if bluetooth.available {
            if !deviceManager.isMonitoring {
                deviceManager.startMonitoring()
            }
        } else {
            if deviceManager.isMonitoring {
                deviceManager.stopMonitoring()
            }
        }
        if CMMotionActivityManager.authorizationStatus() == .authorized {
            if !mobilityManager.isMonitoring {
                mobilityManager.startMonitoring()
           }
        } else {
            if mobilityManager.isMonitoring {
                mobilityManager.stopMonitoring()
           }
        }
    }
    
    private func updateTrackingLevel() {
        if deviceManager.inCar {
            locationManager.update(trackingLevel: .inCar)
        } else if mobilityManager.transport == .car {
            locationManager.update(trackingLevel: .mayInCar)
        } else {
            locationManager.update(trackingLevel: .notInCar)
        }
    }
    
    private func updateMotion(by location: CLLocation? = nil) {
        motionTimeoutTimer?.invalidate()
        motionTimeoutTimer = nil
        
        if mobilityManager.isMonitoring {
            // by motion if available
            locationManager.update(motion: mobilityManager.motion)
        } else if let location = location, let last = _trackings.last?.location.location {
            // by location if available
            
            if location.speed == 0 {
                locationManager.update(motion: .stationary)
                return
            }
            
            locationManager.update(motion: .moving)
            
            let distance = last.distance(from: location)
            
            var timeout = 10.0
            if distance <= 100.0 {
                
                var distanceFilter = 75.0
                if location.speed < 8.0 {
                    distanceFilter = 50.0
                } else if location.speed < 17.0 {
                    distanceFilter = 80.0
                } else {
                    distanceFilter = 120.0
                }
                
                if location.speed > 0.0 { timeout = distanceFilter / location.speed + 10.0 }
                if location.speed < 0.0 { timeout = 30.0 }
            } else {
                timeout = 300.0
            }
            
            motionTimeoutTimer = Timer(timeInterval: timeout, repeats: false, block: { (timer) in
                self.locationManager.update(motion: .stationary)
            })
            motionTimeoutTimer?.tolerance = 2.0
            RunLoop.current.add(motionTimeoutTimer!, forMode: .common)

        } else {
            // fallback
            locationManager.update(motion: .unknown)
        }
    }
    
    
    // Mark - Manage trackings
    
    var trackings: [Tracking] { get { return _trackings } }
    
    private func add(tracking: Tracking) {
        dispatchQueue.sync {
            _trackings.append(tracking)
            Storage.store(_trackings, to: .documents, as: filename)
        }
        if tracking.trigger == .detectedLocation {
            update(deviceUIDs: tracking.deviceUIDs, transport: tracking.mobility.transport)
        }
    }
    
    private func update(deviceUIDs: [String], transport: MBTransport) {
        guard transport != .unknown else { return }
        let automotive = transport == .car ? 1 : 0
        for deviceUID in deviceUIDs {
            deviceManager.update(deviceUID: deviceUID, newActivityItems: 1, automotive: automotive)
        }
    }
    
    var visits: [Visit] { get { return locationManager.visits } }

    
    // Mark - DeviceManager API
    
    func update(deviceUID: String, registeredAsCar: Bool) {
        deviceManager.update(deviceUID: deviceUID, registeredAsCar: registeredAsCar)
    }
    
    func devices() -> [MBDevice] {
        return deviceManager.devices()
    }
    
    
    // Mark - LocationManagerDelegate
    
    func locationManager(_ location: CLLocation, trigger: Trigger) {
        updateMotion(by: location)
        
        // create trackings
        let power = Power.state()
        let deviceUIDs = deviceManager.connectedDevices().map { $0.uid }
        let level = locationManager.trackingLevel

        // only store detected locations (geofence exit, significant location change, permanent tracking while in car)
        if trigger == .detectedLocation {
            if permission.motionStatus() == .authorized {
                mobilityManager.findMobility(at: location.timestamp, { (mobility) in
                    let tracking = Tracking(timestamp: location.timestamp, location: Location(location), trigger: trigger, deviceUIDs: deviceUIDs, power: power, mobility: mobility, level: level)
                    self.add(tracking: tracking)
                })
            } else {
                let tracking = Tracking(timestamp: location.timestamp, location: Location(location), trigger: trigger, deviceUIDs: deviceUIDs, power: power, mobility: Mobility.Unknown, level: level)
                self.add(tracking: tracking)
            }
        } else if trigger == .visitArrival {
            NotificationCenter.default.post(name: MobilityKit.didArriveNotification, object: MBLocation(coordinate: location.coordinate), userInfo: nil)
        } else if trigger == .visitDeparture {
            NotificationCenter.default.post(name: MobilityKit.didDepartNotification, object: MBLocation(coordinate: location.coordinate), userInfo: nil)
        }
    }
    
    // Mark - DeviceManagerDelegate
    
    func deviceManager(_ manager: DeviceManager, didDetect device: MBDevice) {
        NotificationCenter.default.post(name: MobilityKit.didDetectNewDeviceNotification, object: device, userInfo: nil)
    }
    
    func deviceManager(_ manager: DeviceManager, didConnect device: MBDevice) {
        updateTrackingLevel()
        if device.inCarDevice {
            let timestamp = Date()
            let power = Power.state()
            let deviceUIDs = deviceManager.connectedDevices().map { $0.uid }
            let level = locationManager.trackingLevel

            singleLocation.get { (location) in
                if let location = location {
                    if self.permission.motionStatus() == .authorized {
                        self.mobilityManager.findMobility(at: timestamp) { (mobility) in
                            let tracking = Tracking(timestamp: timestamp, location: Location(location), trigger: .deviceConnect, deviceUIDs: deviceUIDs, power: power, mobility: mobility, level: level)
                            self.add(tracking: tracking)
                        }
                    } else {
                        let tracking = Tracking(timestamp: timestamp, location: Location(location), trigger: .deviceConnect, deviceUIDs: deviceUIDs, power: power, mobility: Mobility.Unknown, level: level)
                        self.add(tracking: tracking)
                    }
                }
            }
        }
    }
    
    func deviceManager(_ manager: DeviceManager, didDisconnect device: MBDevice) {
        updateTrackingLevel()
        if device.inCarDevice {
            let timestamp = Date()
            let power = Power.state()
            let deviceUIDs = deviceManager.connectedDevices().map { $0.uid }
            let level = locationManager.trackingLevel
            
            singleLocation.get { (location) in
                if let location = location {
                    if self.permission.motionStatus() == .authorized {
                        self.mobilityManager.findMobility(at: timestamp) { (mobility) in
                            let tracking = Tracking(timestamp: timestamp, location: Location(location), trigger: .deviceDisconnect, deviceUIDs: deviceUIDs, power: power, mobility: mobility, level: level)
                            self.add(tracking: tracking)
                        }
                    } else {
                        let tracking = Tracking(timestamp: timestamp, location: Location(location), trigger: .deviceDisconnect, deviceUIDs: deviceUIDs, power: power, mobility: Mobility.Unknown, level: level)
                        self.add(tracking: tracking)
                    }
                }
            }
        }
    }
    
    // Mark - MobilityManagerDelegate
    
    func mobilityManager(_ manager: MobilityManager, didChange mobility: Mobility, from oldMobility: Mobility) {
        if mobility.transport != oldMobility.transport {
            updateTrackingLevel()
        }
        
        if mobility.motion != oldMobility.motion {
            locationManager.update(motion: mobility.motion)
        }
        
        if mobility.transport != oldMobility.transport {
            NotificationCenter.default.post(name: MobilityKit.didChangeTransportNotification, object: mobility.transport, userInfo: nil)
        }
        
    }
    
    func mobilityManagerMayLeaveCar(_ manager: MobilityManager) {
        let timestamp = Date()
        let power = Power.state()
        let deviceUIDs = deviceManager.connectedDevices().map { $0.uid }
        let level = locationManager.trackingLevel
        
        singleLocation.get { (location) in
            if let location = location {
                let tracking = Tracking(timestamp: timestamp, location: Location(location), trigger: .mayLeaveCar, deviceUIDs: deviceUIDs, power: power, mobility: Mobility.Unknown, level: level)
                self.add(tracking: tracking)
            }
        }
    }
    
    
    // Mark - BluetoothDelegate
    
    func bluetooth(available: Bool) {
        NotificationCenter.default.post(name: MobilityKit.didDetectBluetoothAvailabilityNotification, object: bluetooth.available, userInfo: nil)
        manageServices()
    }
    
    
    // Mark - PermissionDelegate
    
    func permission(locationPermission: PermissionStatus) {
        if locationPermission == .authorized {
            start()
        } else {
            stop()
        }
    }
    
    
    // Mark - KeepAliveDelegate
    
    func keepAlive(remainingTime: Double) {
        // do nothing
    }
    

    
}


enum Trigger: Int, Codable {
    case deviceConnect
    case deviceDisconnect
    case transportChange
    case mayLeaveCar
    
    case visitArrival
    case visitDeparture
    case detectedLocation
}

struct Tracking: Codable, Comparable {
    static func < (lhs: Tracking, rhs: Tracking) -> Bool {
        return lhs.timestamp < rhs.timestamp
    }
    
    static func == (lhs: Tracking, rhs: Tracking) -> Bool {
        return lhs.timestamp == rhs.timestamp
    }
    
    public var timestamp: Date
    public var location: Location
    public var trigger: Trigger
    public var deviceUIDs: [String]
    public var power: PowerState
    public var mobility: Mobility
    public var level: TrackingLevel
}

