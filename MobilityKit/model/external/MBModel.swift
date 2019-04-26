//
//  Model.swift
//  Data structure for calculates timeline model
//
//  Created by Tobias Frech on 11.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation

/**
 The model contains the mobility timeline (events) and all visited places (clustered)
 */
public struct MBModel {
    /**
     List of visited places
     */
    public private(set) var places: [MBPlace]

    /**
     List of events containing visits and trips (mobility timeline)
     */
    public private(set) var events: [MBEvent]
    
    init(places: [MBPlace], events: [MBEvent]) {
        self.places = places
        self.events = events
    }
}

