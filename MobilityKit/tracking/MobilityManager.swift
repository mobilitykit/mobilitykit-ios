//
//  MobilityManager.swift
//  Handles activity recognition results
//
//  Created by Tobias Frech on 06.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import CoreMotion
import CoreLocation


protocol MobilityManagerDelegate {
    func mobilityManager(_ manager: MobilityManager, didChange mobility: Mobility, from oldMobility: Mobility)
    func mobilityManagerMayLeaveCar(_ manager: MobilityManager)
}

class MobilityManager: NSObject {
    
    var delegate: MobilityManagerDelegate?
    private var activity: CMMotionActivity?
    private let activityManager = CMMotionActivityManager()
    public private(set) var isMonitoring = false
    private var mayLeaveCar = false
    
    public private(set) var transport: MBTransport {
        get { return MBTransport(rawValue: UserDefaults.standard.integer(forKey: "mobilitykit_transport")) ?? .unknown }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "mobilitykit_transport") }
    }
    
    public private(set) var motion: Motion {
        get { return Motion(rawValue: UserDefaults.standard.integer(forKey: "mobilitykit_motion")) ?? .unknown }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "mobilitykit_motion") }
    }
    
    public private(set) var startDate: Date {
        get { return Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: "mobilitykit_mobility_startDate")) }
        set { UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: "mobilitykit_mobility_startDate") }
    }
    
    public var mobility: Mobility { get { return Mobility(startDate: startDate, transport: transport, motion: motion) } }
    
    public func findMobility(at timestamp: Date, _ closure: @escaping (_ mobility: Mobility) -> Void) {
        var mobility = Mobility.Unknown
        activityManager.queryActivityStarting(from: timestamp.addingTimeInterval(-86400.0), to: timestamp, to: OperationQueue.main) { (activities, error) in
            if error == nil && activities != nil {
                for activity in activities!.filter({$0.confidence != .low}).reversed() {
                    if mobility.motion == .unknown {
                        mobility.motion = activity.stationary ? .stationary : .moving
                        self.startDate = activity.startDate
                        mobility.startDate = self.startDate
                    }
                    if mobility.transport == .unknown {
                        if activity.automotive {
                            mobility.transport = .car
                        } else if activity.walking || activity.running {
                            mobility.transport = .foot
                        } else if activity.cycling {
                            mobility.transport = .bike
                        }
                    }
                    if mobility.motion != .unknown && mobility.transport != .unknown {
                        closure(mobility)
                        return
                    }
                }
            }
            mobility.startDate = self.startDate
            closure(mobility)
        }
    }
    
    func startMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable(), CMMotionActivityManager.authorizationStatus() == .authorized else {
            handleMobility(Mobility.Unknown)
            return
        }
        
        isMonitoring = true
        
        findMobility(at: Date()) { (mobility) in
            if self.motion == .unknown || self.transport == .unknown {
                self.transport = mobility.transport
                self.motion = mobility.motion
            } else {
                self.handleMobility(mobility)
            }
        }
        
        // start watching activity
        activityManager.startActivityUpdates(to: OperationQueue.main) { activity in
            if let activity = activity {
                DispatchQueue.main.async {
                    self.handleActivity(activity)
                }
            }
        }
    }
    
    func stopMonitoring() {
        activityManager.stopActivityUpdates()
        isMonitoring = false
    }
    
    private func handleActivity(_ activity: CMMotionActivity) {
        // handle first event
        if transport == .unknown || motion == .unknown {
            guard activity.confidence != .low else { return }
            if activity.automotive {
                transport = .car
                motion = activity.stationary ? .stationary : .moving
            } else if activity.cycling {
                transport = .bike
                motion = .moving
            } else if activity.walking || activity.cycling {
                transport = .foot
                motion = .moving
            } else if activity.stationary {
                transport = .foot
                motion = .stationary
            }
            return
        }
        
        // handle event while in car
        if transport == .car {
            if activity.confidence == .medium || activity.confidence == .high {
                if activity.automotive {
                    mayLeaveCar = false
                    handleMobility(Mobility(startDate: activity.startDate, transport: .car, motion: activity.stationary ? .stationary : .moving))
                } else if activity.cycling {
                    mayLeaveCar = false
                    handleMobility(Mobility(startDate: activity.startDate, transport: .bike, motion: .moving))
                } else if activity.walking || activity.running {
                    mayLeaveCar = false
                    handleMobility(Mobility(startDate: activity.startDate, transport: .foot, motion: .moving))
                } else if !mayLeaveCar {
                    mayLeaveCar = true
                    delegate?.mobilityManagerMayLeaveCar(self)
                }
            } else  if !mayLeaveCar {
                if !activity.automotive && !activity.cycling && !activity.walking && !activity.running && !activity.stationary {
                    mayLeaveCar = true
                    delegate?.mobilityManagerMayLeaveCar(self)
                }
            }
            return
        }
        
        // handle event while on bike
        if transport == .bike {
            guard activity.confidence != .low else { return }
            if activity.stationary {
                handleMobility(Mobility(startDate: activity.startDate, transport: .bike, motion: .stationary))
            } else if activity.automotive {
                handleMobility(Mobility(startDate: activity.startDate, transport: .car, motion: activity.stationary ? .stationary : .moving))
            } else if activity.walking || activity.running {
                handleMobility(Mobility(startDate: activity.startDate, transport: .foot, motion: .moving))
            } else if activity.cycling {
                handleMobility(Mobility(startDate: activity.startDate, transport: .bike, motion: .moving))
            }
            return
        }
        
        // handle event while on foot
        if transport == .foot {
            guard activity.confidence != .low else { return }
            if activity.stationary {
                handleMobility(Mobility(startDate: activity.startDate, transport: .foot, motion: .stationary))
            } else if activity.automotive {
                handleMobility(Mobility(startDate: activity.startDate, transport: .car, motion: activity.stationary ? .stationary : .moving))
            } else if activity.cycling {
                handleMobility(Mobility(startDate: activity.startDate, transport: .bike, motion: .moving))
            } else if activity.walking || activity.running {
                handleMobility(Mobility(startDate: activity.startDate, transport: .foot, motion: .moving))
            }
            return
        }
    }
    
    private func handleMobility(_ mobility: Mobility) {
        if transport != mobility.transport || motion != mobility.motion {
            let oldMobility = Mobility(startDate: startDate, transport: transport, motion: motion)
            startDate = mobility.startDate
            transport = mobility.transport
            motion = mobility.motion
            delegate?.mobilityManager(self, didChange: mobility, from: oldMobility)
        }
    }
    
}

