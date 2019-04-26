//
//  Location.swift
//  Data structure for a detected location
//
//  Created by Tobias Frech on 15.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import CoreLocation

struct Location: Codable, Comparable {
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double
    public var horizontalAccuracy: Double
    public var verticalAccuracy: Double
    public var course: Double
    public var speed: Double
    public var timestamp: Date
    
    init(_ location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        horizontalAccuracy = location.horizontalAccuracy
        verticalAccuracy = location.verticalAccuracy
        course = location.course
        speed = location.speed
        timestamp = location.timestamp
    }
    
    public var coordinate: CLLocationCoordinate2D { get { return CLLocationCoordinate2D(latitude: latitude, longitude: longitude) } }
    
    public var location: CLLocation {
        get {
            return CLLocation(coordinate: coordinate, altitude: altitude, horizontalAccuracy: horizontalAccuracy, verticalAccuracy: verticalAccuracy, course: course, speed: speed, timestamp: timestamp)
        }
    }
    
    public var id: String { get { return String(Int(timestamp.timeIntervalSince1970)) } }
    
    
    // Mark - Comparable
    public static func < (lhs: Location, rhs: Location) -> Bool {
        return lhs.timestamp < rhs.timestamp
    }
    
    public static func == (lhs: Location, rhs: Location) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude && lhs.timestamp == rhs.timestamp
    }
}


