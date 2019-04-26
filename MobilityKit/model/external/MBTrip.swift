//
//  Trip.swift
//  Data structure for a trip event and trip segement incl. transport type (with detection confidence)
//
//  Created by Tobias Frech on 11.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import CoreLocation

/**
 Trip event on the mobility timeline
 */

public class MBTrip: MBEvent {
    
    /**
     Place where the trip has started
     */
    public private(set) var startPlace: MBPlace
    
    /**
     Place where the trip has ended. `nil` if the trip is not finished yet
     */
    public private(set) var endPlace: MBPlace?
    
    /**
     Segments of the trip (seperated by transport type)
     */
    public private(set) var segments: [MBSegment]
    
    /**
     Route clusted ID
     
     - Important:
     Only available if the trips where clustered to routes
     */
    public var clusterId: Int?
    
    init(_ segments: [MBSegment], from: MBVisit, to: MBVisit? = nil) {
        startPlace = from.place
        endPlace = to?.place
        self.segments = segments
        super.init(startDate: from.endDate, endDate: to?.startDate ?? Date.distantFuture)
    }
    
    
    /**
     Travelled distance of this trip
     */
    public var distance: CLLocationDistance { get { return segments.reduce(0) { $0 + $1.distance } } }
    
    /**
     Number of waypoints of all segments
     */
    public var waypoints: [CLLocationCoordinate2D] { get { return segments.reduce([]) { $0 + $1.waypoints } } }
}

/**
 Segment of a trip
 */
public struct MBSegment {
    
    /**
     Transport type
     */
    public var transport: MBTransport
    
    /**
     Confidence level of transport type
     */
    public var confidence: MBTransportConfidence
    
    /**
     Waypoints (list of coordinates) of this segement (including start and end of this segement)
     */
    public var waypoints: [CLLocationCoordinate2D]
    
    /**
     Duration of this trip segment
     */
    public var duration: TimeInterval
    
    /**
     Travelled distance of this trip segment
     */
    public var distance: CLLocationDistance
}

/**
 Detected transport type
 
 * `unknown` if the transport type could not be determined
 * `foot` if the user was walking or running
 * `bike` if the user was cycling
 * `car` if the user was using a car
 */
@objc public enum MBTransport: Int, Codable {
    /**
     The transport type could not be determined
     */
    case unknown
    /**
     The user was walking or running
     */
    case foot
    /**
     The user was traveling by bike
     */
    case bike
    /**
     The user was traveling by car
     */
    case car
}

/**
 Transport type confidence
 
 * `low` if the detected transport type could be possible
 * `medium` if the detected transport type is probable
 * `high` if the detected transport type is very problable
 */
public enum MBTransportConfidence {
    /**
     The probability of the detected transport type is low
     */
    case low
    /**
     The probability of the detected transport type is medium
     */
    case medium
    /**
     The probability of the detected transport type is high
     */
    case high
}

