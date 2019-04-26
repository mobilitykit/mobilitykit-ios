//
//  SingleLocation.swift
//  Get the current location of the user (only once)
//
//  Created by Tobias Frech on 15.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import CoreLocation

class SingleLocation: NSObject, CLLocationManagerDelegate {
    
    typealias LocationResult = (_ location: CLLocation?) -> Void
    
    private var requests = [LocationResult]()
    private var requesting: Bool = false
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self
    }
    
    func get(_ closure: @escaping LocationResult) {
        requests.append(closure)
        if !requesting {
            requesting = true
            locationManager.requestLocation()
        }
    }
    
    
    // Mark - CLLocationManagerDelegate
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            while let request = requests.popLast() {
                request(location)
            }
            requesting = false
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        while let request = requests.popLast() {
            request(nil)
        }
    }
    
}
