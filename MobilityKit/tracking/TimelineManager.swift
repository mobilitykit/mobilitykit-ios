//
//  TimelineManager.swift
//  Builds the timeline model
//
//  Created by Tobias Frech on 11.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import CoreLocation

class Timeline {
    
    private static let kMinimumVisitDuration: TimeInterval = 300.0
    private static let kMinimumAccuracy: CLLocationDistance = 90.0
    private static let kMaximumVisitDateAdaption: TimeInterval = 900.0
    private static let kMaximumTripClusteringDistance: CLLocationDistance = 100.0
    
    // create mobility model out of tracking and visits data
    static func model(trackings: [Tracking], visits: [Visit]) -> MBModel {
        // prepare data
        let trackings = trackings.sorted()
        let visits = preperate(visits: filter(visits: visits.sorted()), trackings: trackings)
        
        // extract and cluster visit locations
        let visitLocations = visits.map { $0.location }
        let dbscan = DBSCAN(visitLocations)
        let clusterResult = dbscan.findCluster(eps: 75.0, minPts: 0)
        
        // create new places
        let places = clusterResult.clusters.enumerated().map { MBPlace(id: $0, location: $1.location) }
        
        // create new events
        var events:[MBEvent] = []
        for (id, visit) in visits.enumerated() {
            
            // skip (first) event with undefined startDate
            guard visit.arrivalDate != Date.distantPast else { continue }
            
            let placeId = clusterResult.sequence[id]
            
            // first event
            if events.count == 0 {
                events.append(MBVisit(places[placeId], startDate: visit.arrivalDate, endDate: visit.departureDate))
                continue
            }
            
            // information about the last location
            let lastPlaceId = clusterResult.sequence[id-1]
            let lastEvent = events.last!
            
            // handle exception with events at the same location
            if lastPlaceId == placeId {
                
                // update departure date if there is overlapping
                if lastEvent.endDate >= visit.arrivalDate {
                    events[events.endIndex - 1].endDate = visit.departureDate
                    continue
                }
                
                // merge if the trip duration between or one stay duraton is too short
                let tripDuration = visit.arrivalDate.timeIntervalSince(lastEvent.endDate)
                if  tripDuration < kMinimumVisitDuration || lastEvent.duration < kMinimumVisitDuration || visit.duration < kMinimumVisitDuration {
                    events[events.endIndex - 1].endDate = visit.departureDate
                    continue
                }
                
                // TODO merge if there are no recorded waypoints between these events
            }
            
            // handle exceptions with different locations
            
            // remove last stay/trip if stay was not finished recording -> add placeholder event
            if lastEvent.endDate == Date.distantFuture {
                events.removeLast()
                if events.last is MBTrip { events.removeLast() }
                if events.count > 0 {
                    events.append(MBEvent(startDate: events.last!.endDate, endDate: visit.arrivalDate))
                }
                events.append(MBVisit(places[placeId], startDate: visit.arrivalDate, endDate: visit.departureDate))
                continue
            }
            
            // remove last event + trip if stay duration is too short
            if lastEvent.duration < kMinimumVisitDuration {
                if events.count == 1 {
                    events.removeAll()
                    events.append(MBVisit(places[placeId], startDate: visit.arrivalDate, endDate: visit.departureDate))
                    continue
                } else {
                    events.removeLast()
                    if events.last is MBTrip { events.removeLast() }
                }
            }
            
            // get last visit event
            if let lastVisit = events.last as? MBVisit {
                // create next visit event
                let nextVisit = MBVisit(places[placeId], startDate: visit.arrivalDate, endDate: visit.departureDate)
                
                // create trip
                
                // find trip segments to append to trip
                let segments = self.segments(trackings: trackings, from: lastVisit, to: nextVisit)
                
                let trip = MBTrip(segments, from: lastVisit, to: nextVisit)
                
                // append trip and next visit
                events.append(trip)
                events.append(nextVisit)
            }
            
        }
        
        return MBModel(places: places, events: events)
    }
    
    // Mark - Internal stuff
    
    // pre-process raw visit data (from tracking manager)
    private static func filter(visits: [Visit]) -> [Visit] {
        let visits = visits.sorted()
        var filteredVisits = [Visit]()
        
        for i in 0..<visits.count {
            let visit = visits[i]
            let visitLocation = CLLocation(coordinate: visit.coordinate, altitude: -1.0, horizontalAccuracy: visit.horizontalAccuracy, verticalAccuracy: -1.0, timestamp: visit.departureDate)
            
            // add first element
            if filteredVisits.isEmpty {
                // if first date starts in the distant past, update arrival date to start-of-day of the departure date
                if visit.arrivalDate == Date.distantPast {
                    guard visit.departureDate != Date.distantFuture else { continue }
                    var visit = visit
                    visit.arrivalDate = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: visit.departureDate)!
                }
                filteredVisits.append(visit)
                continue
            }

            // calculate travel distance and time
            let previousVisit = filteredVisits.last!
            let previousVisitLocation = CLLocation(coordinate: previousVisit.coordinate, altitude: -1.0, horizontalAccuracy: previousVisit.horizontalAccuracy, verticalAccuracy: -1.0, timestamp: previousVisit.departureDate)

            let travelDistance = visitLocation.distance(from: previousVisitLocation)
            let travelTime = visit.arrivalDate.timeIntervalSince(previousVisit.departureDate)
            
            // handle visit overlaps
            if travelTime < 0.0 {
                
                // hanlde similar (location, arrival or departure dates) visits -> merge them
                if travelDistance < 75.0 || abs(visit.arrivalDate.timeIntervalSince(previousVisit.arrivalDate)) < 30.0 || (abs(visit.departureDate.timeIntervalSince(previousVisit.departureDate)) < 30.0 && visit.departureDate != Date.distantFuture) {
                    
                    if previousVisit.arrivalDate > visit.arrivalDate {
                        filteredVisits[filteredVisits.endIndex-1].arrivalDate = visit.arrivalDate
                    }
                    if previousVisit.departureDate == Date.distantFuture || previousVisit.departureDate < visit.departureDate {
                        filteredVisits[filteredVisits.endIndex-1].departureDate = visit.departureDate
                    }
                    if previousVisit.horizontalAccuracy > visit.horizontalAccuracy {
                        filteredVisits[filteredVisits.endIndex-1].coordinate = visit.coordinate
                        filteredVisits[filteredVisits.endIndex-1].horizontalAccuracy = visit.horizontalAccuracy
                    }
                    
                    continue
                }
                
                // handle unstopped visits and small overlaps with good accuracy
                if previousVisit.departureDate == Date.distantFuture || abs(travelTime) < kMinimumVisitDuration {
                    // if accuracy is ok -> seperate visits
                    if previousVisit.horizontalAccuracy < 100.0 && visit.horizontalAccuracy < 100.0 {
                        filteredVisits[filteredVisits.endIndex-1].departureDate = visit.arrivalDate
                        
                        // remove too short visit before appending the new one
                        if previousVisit.duration < kMinimumVisitDuration || previousVisit.horizontalAccuracy > 150.0 {
                            filteredVisits.removeLast()
                        }
                        filteredVisits.append(visit)
                        continue
                    }
                }
                
                // merge if not so far and one accuracy is bad
                
                
                
                // if accuracy is bad try to merge them
                if travelDistance < previousVisit.horizontalAccuracy + visit.horizontalAccuracy {
                    if previousVisit.arrivalDate > visit.arrivalDate {
                        filteredVisits[filteredVisits.endIndex-1].arrivalDate = visit.arrivalDate
                    }
                    if previousVisit.departureDate == Date.distantFuture || previousVisit.departureDate < visit.departureDate {
                        filteredVisits[filteredVisits.endIndex-1].departureDate = visit.departureDate
                    }
                    if previousVisit.horizontalAccuracy > visit.horizontalAccuracy {
                        filteredVisits[filteredVisits.endIndex-1].coordinate = visit.coordinate
                        filteredVisits[filteredVisits.endIndex-1].horizontalAccuracy = visit.horizontalAccuracy
                    }
                    continue
                } else {
                    // seperate, no merging stradegy found
                    filteredVisits[filteredVisits.endIndex-1].departureDate = visit.arrivalDate
                }
            }
            
            // remove too short visit before appending the new one
            if previousVisit.duration < kMinimumVisitDuration || previousVisit.horizontalAccuracy > 150.0 {
                filteredVisits.removeLast()
            }
            filteredVisits.append(visit)
        }
        return filteredVisits
    }
    
    // sharpen arrival/departure date and filter out visits on-the-go
    // (e.g. traffic jam, walk near known places, ...)
    private static func preperate(visits: [Visit], trackings: [Tracking]) -> [Visit] {
        
        var optimizedVisits = [Visit]()
        
        for visit in visits {
            
            let inVisitTrackings = trackings.filter { $0.timestamp >= visit.arrivalDate && $0.timestamp <= visit.departureDate }

            // check if visit is already ok
            var visitIsOk = true
            for tracking in inVisitTrackings {
                if tracking.mobility.transport == .car || tracking.mobility.transport == .bike {
                    visitIsOk = false
                    break
                }
                if DeviceManager.inCarDevice(tracking.deviceUIDs) {
                    visitIsOk = false
                    break
                }
                if tracking.location.location.distance(from: visit.location) > 150.0 && tracking.location.horizontalAccuracy <= kMinimumAccuracy {
                    visitIsOk = false
                    break
                }
            }
            
            // add accurate visits
            if visitIsOk {
                optimizedVisits.append(visit)
                continue
            }

            // handle inaccurate visits
            var visit = visit
            var arrivalFound = false
            
            // find arrival date
            for (index, tracking) in inVisitTrackings.enumerated() {
                
                if tracking.mobility.transport == .car {
                    continue
                }
                if DeviceManager.inCarDevice(tracking.deviceUIDs) {
                    continue
                }
                if tracking.location.horizontalAccuracy <= kMinimumAccuracy && tracking.location.location.distance(from: visit.location) > 150.0 {
                    continue
                }
                
                if tracking.mobility.transport == .foot ||
                    tracking.trigger == .mayLeaveCar || !DeviceManager.inCarDevice(tracking.deviceUIDs) {
                    
                    if tracking.trigger == .mayLeaveCar && index+1 < inVisitTrackings.count {
                        let next = inVisitTrackings[index+1]
                        if next.mobility.transport == .foot {
                            let newDate = tracking.timestamp
                            visit.arrivalDate = newDate
                            arrivalFound = true
                            break
                        }
                    }
                    
                    if tracking.trigger != .mayLeaveCar {
                        let newDate: Date = tracking.timestamp.timeIntervalSince(visit.arrivalDate) <= kMaximumVisitDateAdaption ? tracking.timestamp : visit.arrivalDate.addingTimeInterval(kMaximumVisitDateAdaption)
                        visit.arrivalDate = newDate
                        break
                    }
                }
            }
            
            // append current place without adapting the departure time
            if visit.departureDate == Date.distantFuture {
                
                optimizedVisits.append(visit)
                continue
            }
            
            // move arrival date for this visit, if no arrival date was found
            if !arrivalFound {
                visit.arrivalDate.addTimeInterval(kMaximumVisitDateAdaption / 2.0)
            }
            
            // find departure date
            var departureFound = false

            var departureDate = visit.departureDate
            for tracking in inVisitTrackings.reversed() {
                if !DeviceManager.inCarDevice(tracking.deviceUIDs) && (tracking.mobility.transport == .foot || tracking.mobility.transport == .unknown) {
                    
                    departureFound = true
                    
                    let newDate: Date = visit.departureDate.timeIntervalSince(departureDate).rounded() <= kMaximumVisitDateAdaption ? departureDate : visit.departureDate.addingTimeInterval(-kMaximumVisitDateAdaption)
                    visit.departureDate = newDate
                    break
                }
                departureDate = tracking.timestamp
            }
            
            // move departure date for this visit, if no departure date was found
            if !departureFound {
                visit.arrivalDate.addTimeInterval(-kMaximumVisitDateAdaption / 2.0)
            }


            // skip this visit, if it's now too short
            if visit.duration < kMinimumVisitDuration {
                continue
            }
            
            optimizedVisits.append(visit)
        }
        return optimizedVisits
    }
    
    // provide trip segements from trackings
    private static func segments(trackings: [Tracking], from: MBVisit, to: MBVisit) -> [MBSegment] {
        guard from.endDate <= to.startDate else { return [] }
        let trackings = trackings.filter { (from.endDate ... to.startDate).contains($0.timestamp) && $0.location.horizontalAccuracy <= kMinimumAccuracy && ($0.trigger == .detectedLocation) }
        guard trackings.count > 0 else {
            // create default segment with no additional waypoints
            let duration = to.startDate.timeIntervalSince(from.endDate)
            let distance = to.place.location.distance(from: from.place.location)
            return [MBSegment(transport: .unknown, confidence: .low, waypoints: [from.place.coordinate, to.place.coordinate], duration: duration, distance: distance)]
        }
        
        var segments = [MBSegment]()
        var (transport, confidence) = self.transport(by: trackings.first!)
        var coordinates = [from.place.coordinate]
        var timestamp = from.endDate
        var distance: CLLocationDistance = 0.0
        
        for tracking in trackings {
            
            // calculate distance to last waypoint
            distance += CLLocation(coordinate: coordinates.last!, altitude: -1.0, horizontalAccuracy: -1.0, verticalAccuracy: -1.0, timestamp: timestamp).distance(from: tracking.location.location)

            // append waypoint
            coordinates.append(tracking.location.coordinate)
            
            let (newTransport, newConfidence) = self.transport(by: tracking)
            
            if transport != newTransport || confidence != newConfidence {
                // finalize current segement
                let duration = tracking.timestamp.timeIntervalSince(timestamp)
                let segment = MBSegment(transport: transport, confidence: confidence, waypoints: coordinates, duration: duration, distance: distance)
                segments.append(segment)

                // reset to start new segment
                transport = newTransport
                confidence = newConfidence
                coordinates = [tracking.location.coordinate]
                timestamp = tracking.timestamp
                distance = 0.0
            }
        }
        // finalize last segement
        let duration = to.startDate.timeIntervalSince(timestamp)
        coordinates.append(to.place.coordinate)
        let segment = MBSegment(transport: transport, confidence: confidence, waypoints: coordinates, duration: duration, distance: distance)
        segments.append(segment)

        return segments
    }
    
    // get transport and confidence out of tracking data
    private static func transport(by tracking: Tracking) -> (transport: MBTransport, confidence: MBTransportConfidence) {
        
        if DeviceManager.inCarDevice(tracking.deviceUIDs) {
            return (transport: .car, confidence: .high)
        }
        
        if tracking.mobility.transport == .car {
            return (transport: .car, confidence: .medium)
        }
        
        if tracking.mobility.transport == .bike {
            return (transport: .bike, confidence: .medium)
        }
        
        if tracking.mobility.transport == .foot {
            return (transport: .foot, confidence: .medium)
        }
        
        return (transport: .unknown, confidence: .low)
    }
    

}

