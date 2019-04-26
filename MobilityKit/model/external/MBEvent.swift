//
//  Event.swift
//  Data structure for a timeline event
//
//  Created by Tobias Frech on 11.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation


/**
 Event on the mobility timeline
 */
public class MBEvent: Comparable {

    /**
     Start date of this event
     */
    public var startDate: Date
    
    /**
     End date of this event. If event is not finished the date will be `Date.distantFuture`.
     */
    public var endDate: Date
    
    init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }
    
    /**
     Duration of this event
     */
    public var duration: TimeInterval { get { return endDate.timeIntervalSince(startDate)} }
    
    // Mark - Comparable
    
    /**
     Compare `startDate` of both events
     */
    public static func < (lhs: MBEvent, rhs: MBEvent) -> Bool {
        return lhs.startDate < rhs.startDate
    }
    
    /**
     Compare `startDate` and `endDate` of both events
     */
    public static func == (lhs: MBEvent, rhs: MBEvent) -> Bool {
        return lhs.startDate == rhs.startDate && lhs.endDate == rhs.endDate
    }
}

