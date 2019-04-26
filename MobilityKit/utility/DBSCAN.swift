//
//  DBSCAN.swift
//  Simple DBSCAN implementation for clustering CLLocation arrays
//
//  Created by Tobias Frech
//  2016-2019 niato UG / budo GmbH
//

import Foundation
import CoreLocation


struct Cluster {
    let location: CLLocation
    let members: [Int]
}

class DBSCAN {
    
    private var locations: [CLLocation]
    
    private var radius: Double = 0.075
    private var requiredNeighbours: Int = 1
    
    private var clusters: [[Int]] = []
    private var sequence: [Int] = []
    
    init(_ locations: [CLLocation]) {
        self.locations = locations
    }
    
    private func regionNeighbours(_ locationIndex: Int) -> [Int] {
        var neighbours: [Int] = []
        let location = locations[locationIndex]
        for i in 0..<locations.count {
            if i == locationIndex {
                continue
            }
            if location.distance(from: locations[i]) <= radius {
                neighbours.append(i)
            }
        }
        return neighbours
    }
    
    
    private func expandCluster(locationIndex: Int, neighbours: [Int], clusterIndex: Int) {
        clusters[clusterIndex - 1].append(locationIndex)
        sequence[locationIndex] = clusterIndex
        
        for i in 0..<neighbours.count {
            let currentLocationIndex = neighbours[i]
            if sequence[currentLocationIndex] == -1 {
                sequence[currentLocationIndex] = 0
                let currentNeighbours = regionNeighbours(currentLocationIndex)
                if currentNeighbours.count >= requiredNeighbours {
                    expandCluster(locationIndex: currentLocationIndex, neighbours: currentNeighbours, clusterIndex: clusterIndex)
                }
            }
            
            if sequence[currentLocationIndex] <= 0 {
                sequence[currentLocationIndex] = clusterIndex
                clusters[clusterIndex - 1].append(currentLocationIndex)
            }
        }
    }
    
    func findCluster(eps: Double, minPts: Int) -> (sequence: [Int], clusters: [Cluster]) {
        radius = eps
        requiredNeighbours = minPts
        
        clusters = []
        sequence = Array(repeating:-1, count: locations.count)
        
        for i in 0..<locations.count {
            if sequence[i] == -1 {
                sequence[i] = 0
                let neighbours = regionNeighbours(i)
                if neighbours.count < requiredNeighbours {
                    sequence[i] = 0
                } else {
                    clusters.append([])
                    let clusterIndex = clusters.count
                    expandCluster(locationIndex: i, neighbours: neighbours, clusterIndex: clusterIndex)
                }
            }
        }
        
        var places: [Cluster] = []
        for i in 0..<clusters.count {
            var latitude = 0.0, longitude = 0.0, accuracy = 0.0
            for j in 0..<clusters[i].count {
                let location = locations[clusters[i][j]]
                latitude += location.coordinate.latitude
                longitude += location.coordinate.longitude
                accuracy += location.horizontalAccuracy
            }
            latitude = latitude / Double(clusters[i].count)
            longitude = longitude / Double(clusters[i].count)
            accuracy = accuracy / Double(clusters[i].count)
            
            
            let location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: 0, timestamp: Date())
            let members = clusters[i]
            
            places.append(Cluster(location: location, members: members))
            
            
        }
        
        // reduce index, so that -1 is noice and sequence references directly to places array index
        for i in 0..<sequence.count {
            sequence[i] -= 1
        }
        
        return (sequence, places)
    }
    
    
}
