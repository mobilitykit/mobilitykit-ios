//
//  Visit.swift
//  Data structure for a visit event
//
//  Created by Tobias Frech on 11.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation

/**
 Visit event on the mobility timeline
 */
public class MBVisit: MBEvent {
    
    /**
     Place of the visit
     */
    public private(set) var place: MBPlace
    
    init(_ place: MBPlace, startDate: Date, endDate: Date) {
        self.place = place
        super.init(startDate: startDate, endDate: endDate)
    }
    
    /**
     Compare `place` and `startDate` of both visits
     */
    public static func == (lhs: MBVisit, rhs: MBVisit) -> Bool {
        return lhs.place == rhs.place && lhs.startDate == rhs.startDate
    }
}

