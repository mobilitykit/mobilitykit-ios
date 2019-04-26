//
//  RouteClustering.swift
//  Calculate the average distance between two routes
//
//  Created by Tobias Frech on 03.12.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import CoreLocation

/**
 Helper class to calculate the clustering of routes
 */
class RouteClustering {
    
    /**
     Calculate the average distance between two routes using the waypoints
     
     - parameters:
        - waypointsA: Array of coordinates of route A
        - waypointsB: Array of coordinates of route B
     
     - returns:
     Average distance between these two routes
     */
    // travelled route distance
    public static func averageDistance(_ waypointsA: [CLLocationCoordinate2D], from waypointsB: [CLLocationCoordinate2D]) -> CLLocationDistance {

        // distance between all points of tripand

        var distanceSum: CLLocationDistance = 0.0
        
        for waypoint in waypointsA {
            distanceSum += shortestDistance(waypoint, to: waypointsB)
        }
        
        for waypoint in waypointsB {
            distanceSum += shortestDistance(waypoint, to: waypointsA)
        }
        
        return distanceSum / Double(waypointsA.count + waypointsB.count)
    }
    
    // waypoint to route distance
    private static func shortestDistance(_ waypoint: CLLocationCoordinate2D, to waypoints: [CLLocationCoordinate2D]) -> CLLocationDistance {
        var routeDistance: CLLocationDistance?
        for i in 1..<waypoints.count {
            let segment = (start: waypoints[i-1], end: waypoints[i])
            let segmentDistance = shortestDistance(waypoint, to: segment)
            
            if routeDistance == nil || routeDistance! > segmentDistance {
                routeDistance = segmentDistance
            }
        }
        return routeDistance ?? 0.0
    }
    
    // wayppoint to segment distance
    private static func shortestDistance(_ waypoint: CLLocationCoordinate2D, to segment: (start: CLLocationCoordinate2D, end: CLLocationCoordinate2D)) -> CLLocationDistance {
        
        // handle if segment is just a point
        if segment.start.latitude == segment.end.latitude && segment.start.longitude == segment.end.longitude { return waypoint.distance(from: segment.start) }
        
        //Calculating closest point on the line to the input point lonPoint,latPoint
        let plat = segment.end.latitude - segment.start.latitude
        let plng = segment.end.longitude - segment.start.longitude

        // Squared distance between start- and endpoint of the segment
        let squaredSegementDistance = plng*plng + plat*plat
        
        var u = ((waypoint.longitude - segment.start.longitude) * plng + (waypoint.latitude - segment.start.latitude) * plat) / squaredSegementDistance
        u = min(max(u, 0.0), 1.0)
        
        // closest_line_point ist the point on the line that's closest to the point we want to calculate the distance to
        let closestSegmentPoint = CLLocationCoordinate2D(latitude: segment.start.latitude + u * plat, longitude: segment.start.longitude + u * plng)
        
        return waypoint.distance(from: closestSegmentPoint)
    }
    
}



extension CLLocationCoordinate2D {
    
    /**
     Calculate distance in meters between two coordinates
     */
    public func distance(from coordinate: CLLocationCoordinate2D) -> Double {
        let pointA = CLLocation(latitude: latitude, longitude: longitude)
        let pointB = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return pointB.distance(from: pointA)
    }
}
