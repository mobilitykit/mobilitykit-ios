//
//  KeepAlive.swift
//  Keeps the app alive in the background
//
//  Created by Tobias Frech on 07.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation


protocol KeepAliveDelegate {
    func keepAlive(remainingTime: Double)
}

class KeepAlive: NSObject {
    
    private let dispatchQueue = DispatchQueue(label: "mobilitykit.keepalive")
    private let locationManager = CLLocationManager()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var timer: Timer?
    private var timerStop: Timer?
    private var isKeepingAlive = false
    private var updatingLocation = false
    
    public var delegate: KeepAliveDelegate?
    
    override init() {
        super.init()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = kCLLocationAccuracyThreeKilometers
    }
    
    // setting up keep alive feature
    
    func startMonitoring() {
        addObserver()
        // TODO: Fix UIApplication must be called on main thread (no right if triggered by bluetooth-change)
        if UIApplication.shared.applicationState == .background {
            startAliveKeeping()
        }
    }
    
    func stopMonitoring() {
        removeObserver()
        stopAliveKeeping()
    }
    
    func permanentAliveKeeping() {
        stopAliveKeeping()
        locationManager.startUpdatingLocation()
    }
    
    // Mark - start/stop keeping alive

    @objc func startAliveKeeping() {
        guard !isKeepingAlive else { return }
        
        isKeepingAlive = true

        updatingLocation = true
        locationManager.startUpdatingLocation()
        
        backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            self.stopAliveKeeping()
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        })

        setupTimer()
    }
    
    @objc func stopAliveKeeping() {
        isKeepingAlive = false
        timer?.invalidate()
        timer = nil
        locationManager.stopUpdatingLocation()
        updatingLocation = false
    }
    
    
    // Mark - Internal stuff
    
    private func addObserver() {
        removeObserver()
        NotificationCenter.default.addObserver(self, selector:  #selector(startAliveKeeping), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopAliveKeeping), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    private func removeObserver() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    private func setupTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: 5.0, repeats: true, block: { (timer) in
            let remainingTime = UIApplication.shared.backgroundTimeRemaining
            self.dispatchQueue.async {
                if self.updatingLocation {
                    self.locationManager.stopUpdatingLocation()
                    self.updatingLocation = false
                } else if remainingTime < 100.0 {
                    self.updatingLocation = true
                    self.locationManager.startUpdatingLocation()
                }
                self.delegate?.keepAlive(remainingTime: remainingTime)
            }
        })
        timer?.tolerance = 1.0
        RunLoop.current.add(timer!, forMode: .common)
    }
    
}
