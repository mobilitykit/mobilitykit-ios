//
//  Place.swift
//  Data structure for visited place
//
//  Created by Tobias Frech on 11.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import CoreLocation

/**
 A visited place
 */
public struct MBPlace: Equatable {
    private var _id: Int
    private var _location: MBLocation
    
    init(id: Int, location: CLLocation) {
        _id = id
        _location = MBLocation(coordinate: location.coordinate)
    }
    
    /**
     Unique ID of this place
     */
    public var id: Int { get { return _id } }
    
    /**
     CoreLocation coordinate of this place
     */
    public var coordinate: CLLocationCoordinate2D { get { return location.coordinate } }
    
    /**
     CoreLocation location of this place
     */
    public var location: CLLocation { get { return _location.location } }
    
    // Mark - Comparable

    /**
     Compare `location` of both places
     */
    public static func == (lhs: MBPlace, rhs: MBPlace) -> Bool {
        return lhs._location == rhs._location
    }
    
}
