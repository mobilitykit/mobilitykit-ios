//
//  LocationManager.swift
//  Detect physical movements of user in the real world
//
//  Created by Tobias Frech on 06.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit

protocol LocationManagerDelegate {
    func locationManager(_ location: CLLocation, trigger: Trigger)
}

enum TrackingLevel: Int, Codable {
    case notInCar
    case mayInCar
    case inCar
}

class LocationManager: NSObject, CLLocationManagerDelegate {
    
    private let dispatchQueue = DispatchQueue(label: "mobilitykit.locationmanager")
    private let locationsFilename = "mobilitykit_locations.json"
    private let visitsFilename = "mobilitykit_visits.json"
    var delegate: LocationManagerDelegate?
    private let locationManager = CLLocationManager()
    private var _visits: [String: Visit]
    public private(set) var isMonitoring = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var timer: Timer?

    override init() {
        _visits = Storage.fileExists(visitsFilename, in: .documents) ? Storage.retrieve(visitsFilename, from: .documents, as: [String: Visit].self) : [:]
        
        super.init()

        // setup location manager
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50.0
        locationManager.delegate = self

        // configure power monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // preset isMonitoring flag
        isMonitoring = isGeofencing()
    }

    func startMonitoring() {
        isMonitoring = true
        if !isGeofencing() {
            setupGeofencingHere()
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.startMonitoringVisits()
        }
    }

    func stopMonitoring() {
        removeGeofencing()
        stopDetectingLocations()
        locationManager.stopMonitoringVisits()
        locationManager.stopMonitoringSignificantLocationChanges()
        isMonitoring = false
    }
    
    func update(trackingLevel level: TrackingLevel) {
        // handle tracking level change
        if trackingLevel != level {
            if level == .mayInCar || level == .inCar {
                locationManager.activityType = .automotiveNavigation
            } else {
                locationManager.activityType = .fitness
            }
            startDetectingLocations()
            trackingLevel = level
        }
    }
    
    func update(motion state: Motion) {
        // handle motion state change
        if motionState != state {
            if state == .moving {
                if trackingLevel == .inCar || trackingLevel == .mayInCar {
                    startDetectingLocations()
                }
            } else {
                stopDetectingLocations()
            }
            motionState = state
        }
    }
    
    public private(set) var trackingLevel: TrackingLevel {
        get { return TrackingLevel(rawValue: UserDefaults.standard.integer(forKey: "mobilitykit_tracking_level")) ?? .notInCar }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "mobilitykit_tracking_level") }
    }
    
    public private(set) var motionState: Motion {
        get { return Motion(rawValue: UserDefaults.standard.integer(forKey: "mobilitykit_motion_state")) ?? .unknown }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "mobilitykit_motion_state") }
    }
    
    private func shouldContinueTracking() -> Bool {
        // stop tracking if battery is less than 25% and do not have external power supply
        if !Power.externalSource() && Power.state().batteryLevel < 0.25 { return false }
        // continue if we are sure that we are in a moving car
        if trackingLevel == .inCar && motionState == .moving { return true }
        // continue if we might be in a moving car and have external power supply
        if trackingLevel == .mayInCar && motionState == .moving && Power.externalSource() { return true }
        // otherwise stop tracking
        return false
    }
    
    private func startDetectingLocations() {
        locationManager.startUpdatingLocation()
        if backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                UIApplication.shared.endBackgroundTask(self.backgroundTask)
                self.backgroundTask = .invalid
                self.timer?.invalidate()
                self.timer = nil
                self.stopDetectingLocations()

            })
        }
        
        timer?.invalidate()
        timer = Timer(timeInterval: 120.0, repeats: false, block: { (timer) in
            self.stopDetectingLocations()
        })
        timer?.tolerance = 10.0
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func stopDetectingLocations() {
        timer?.invalidate()
        timer = nil
        locationManager.stopUpdatingLocation()
        locationManager.distanceFilter = 50.0
    }


    // Mark - Storage

    var visits: [Visit] { get { return _visits.map { $0.value } } }

    private func add(visit: Visit) {
        guard visit.arrivalDate != Date.distantPast else { return }
        dispatchQueue.sync {
            _visits[visit.id] = visit
            Storage.store(_visits, to: .documents, as: visitsFilename)
        }
    }
    

    // Mark - Geofencing Management

    private func isGeofencing() -> Bool {
        for region in locationManager.monitoredRegions {
            if region.identifier.starts(with: "mobilitykit") {
                return true
            }
        }
        return false
    }

    private func removeGeofencing() {
        for region in locationManager.monitoredRegions {
            if region.identifier.starts(with: "mobilitykit") {
                locationManager.stopMonitoring(for: region)
            }
        }
    }

    private func setupGeofencingHere() {
        removeGeofencing()
        locationManager.requestLocation()
    }

    private func setupGeofencing(at location: CLLocation) {
        removeGeofencing()

        let speedRadius = location.speed < 10.0 ? 80.0 : location.speed * 15.0
        let accuracyRadius = speedRadius + location.horizontalAccuracy

        locationManager.startMonitoring(for: CLCircularRegion(center: location.coordinate, radius: speedRadius, identifier: "mobilitykit-primary"))
        locationManager.startMonitoring(for: CLCircularRegion(center: location.coordinate, radius: accuracyRadius, identifier: "mobilitykit-fallback"))
    }

    private func geofencingCenter() -> CLLocation? {
        for region in locationManager.monitoredRegions {
            if region.identifier.starts(with: "mobilitykit") {
                if let region = region as? CLCircularRegion {
                    return CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
                }
            }
        }
        return nil
    }


    // Mark - CLLocationManagerDelegate

    public func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let visit = Visit(visit)
        add(visit: visit)
        if visit.departureDate == Date.distantFuture {
            // handle arrival event
            
            // reset geofence to visit location
            setupGeofencing(at: visit.location)

            // TODO: check if this is working correctly without using visit-arrival event
            // stopDetectingLocations()
            
            // TODO: Remove:
            delegate?.locationManager(visit.location, trigger: .visitArrival)

        } else {
            // handle departure event
            let location = CLLocation(coordinate: visit.coordinate, altitude: -1.0, horizontalAccuracy: visit.horizontalAccuracy, verticalAccuracy: -1.0, timestamp: visit.departureDate)

            // TODO: Remove:
            delegate?.locationManager(location, trigger: .visitDeparture)
        }
    }


    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region is CLCircularRegion && region.identifier.starts(with: "mobilitykit") {
            startDetectingLocations()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last!

        setupGeofencing(at: location)
        
        delegate?.locationManager(location, trigger: .detectedLocation)
        
        // cancel due to not being in a car
        if trackingLevel == .notInCar {
            stopDetectingLocations()
            return
        }
        
        // continue due to tracking level, motion state and power supply and slower than ~50 or 100km/h
        if (shouldContinueTracking() && location.speed < 18.0) ||
            (Power.externalSource() && location.speed < 28.0) {

            // set speed depended distance filter
            if location.speed < 8.0 {
                manager.distanceFilter = 50.0
            } else if location.speed < 18.0 {
                manager.distanceFilter = 80.0
            } else {
                manager.distanceFilter = 120.0
            }
            
            // to prevent fireing timeout timer, restart detection
            startDetectingLocations()
            return
        }

        // keep it running if accuracy is too bad
        if location.horizontalAccuracy > 25.0 {
            return
        }
        
        stopDetectingLocations()
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {

        if let error = error as? CLError {
            switch error {
            case CLError.locationUnknown:
                print("MobilityKit - LocationManager: Location unknown")
                // restart in 5 seconds if there was an error
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 5.0) {
                    manager.requestLocation()
                }
            case CLError.denied:
                print("MobilityKit - LocationManager: Denied")
            default:
                print("MobilityKit - LocationManager: \(error.localizedDescription)")
            }
        } else {
            print("MobilityKit - LocationManager: \(error.localizedDescription)")
        }
    }


}


