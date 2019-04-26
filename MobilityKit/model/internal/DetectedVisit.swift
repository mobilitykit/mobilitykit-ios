//
//  Visit.swift
//  Data structure for a detected visit
//
//  Created by Tobias Frech on 15.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import CoreLocation

struct Visit: Codable, Comparable {
    private var latitude: Double
    private var longitude: Double
    public var horizontalAccuracy: Double
    public var arrivalDate: Date
    public var departureDate: Date
    
    init(_ visit: CLVisit) {
        latitude = visit.coordinate.latitude
        longitude = visit.coordinate.longitude
        horizontalAccuracy = visit.horizontalAccuracy
        arrivalDate = visit.arrivalDate
        departureDate = visit.departureDate
    }
    
    public var id: String { get { return String(Int(arrivalDate.timeIntervalSince1970)) } }
    
    public var duration: TimeInterval { get { return departureDate.timeIntervalSince(arrivalDate)} }
    
    public var coordinate: CLLocationCoordinate2D {
        get { return CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
    
    public var location: CLLocation {
        get {
            return CLLocation(coordinate: coordinate, altitude: -1, horizontalAccuracy: horizontalAccuracy, verticalAccuracy: -1, timestamp: arrivalDate)
        }
    }
    
    // Mark - Comparable
    public static func < (lhs: Visit, rhs: Visit) -> Bool {
        return lhs.arrivalDate < rhs.arrivalDate
    }
    
    public static func == (lhs: Visit, rhs: Visit) -> Bool {
        return lhs.arrivalDate == rhs.arrivalDate
    }
    
}
