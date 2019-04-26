//
//  LocatonRequest.swift
//  Development
//
//  Created by Tobias Frech on 07.11.18.
//  Copyright © 2018 budo GmbH. All rights reserved.
//

import Foundation
import CoreLocation

typealias LocationResponse = (_ location: CLLocation?) -> Void

class LocationRequest: NSObject, CLLocationManagerDelegate {
    
    private static var requests = [LocationRequest]()
    
    var locationManager: CLLocationManager?
    let response: LocationResponse
    
    private init(_ response: @escaping LocationResponse) {
        self.response = response
        super.init()
        DispatchQueue.main.async {
            self.locationManager = CLLocationManager()
            self.locationManager!.allowsBackgroundLocationUpdates = true
            self.locationManager!.pausesLocationUpdatesAutomatically = false
            self.locationManager!.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager!.delegate = self
            self.locationManager!.requestLocation()
        }
    }
    
    static func start(_ response: @escaping LocationResponse) {
//        DispatchQueue.main.async {
        requests.append(LocationRequest(response))
//        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        LocationRequest.requests.removeAll(where: { $0 == self })
        response(locations.first)
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        LocationRequest.requests.removeAll(where: { $0 == self })
        response(nil)
    }
    
}
