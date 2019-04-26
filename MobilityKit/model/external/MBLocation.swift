//
//  Location.swift
//  Data structure for location of a place
//
//  Created by Tobias Frech on 11.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import CoreLocation

/**
 Location (geocoordinates) representing a point on earth
 */
@objc public class MBLocation: NSObject {
    private var latitude: Double
    private var longitude: Double
    
    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    /**
     CoreLocation coordinate `CLLocationCoordinate2D` of this place
     */
    public var coordinate: CLLocationCoordinate2D { get { return CLLocationCoordinate2D(latitude: latitude, longitude: longitude) } }
    
    /**
     CoreLocation location `CLLocation` of this place
     */
    public var location: CLLocation { get { return CLLocation(coordinate: coordinate, altitude: -1.0, horizontalAccuracy: -1.0, verticalAccuracy: -1.0, timestamp: Date.distantPast) } }
    
    // Mark - Comparable
    
    /**
     Compare geo position (latitude and longitude) of both locations
     */
    public static func == (lhs: MBLocation, rhs: MBLocation) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

