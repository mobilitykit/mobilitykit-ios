//
//  DeviceManager.swift
//  Monitor handsfree profile and carplay devices that are connceted to the phone
//
//  Created by Tobias Frech on 06.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import AVFoundation
import CoreBluetooth
import UIKit

protocol DeviceManagerDelegate {
    func deviceManager(_ manager: DeviceManager, didDetect device: MBDevice)
    func deviceManager(_ manager: DeviceManager, didConnect device: MBDevice)
    func deviceManager(_ manager: DeviceManager, didDisconnect device: MBDevice)
}

class DeviceManager: NSObject {
    
    private let dispatchQueueStorage = DispatchQueue(label: "mobilitykit.devicemanager.storage")
    private let dispatchQueueNotification = DispatchQueue(label: "mobilitykit.devicemanager.notification")
    private let filename = "mobilitykit_devices.json"
    var delegate: DeviceManagerDelegate?
    private var _devices: [String: MBDevice]
    public private(set) var isMonitoring = false
    private var timer: Timer?
    
    private var _connectedUIDs: [String] {
        get { return UserDefaults.standard.stringArray(forKey: "mobilitykit_connected_devices_uids") ?? [String]() }
        set { UserDefaults.standard.set(newValue, forKey: "mobilitykit_connected_devices_uids") }
    }
    
    static func inCarDevice(_ deviceUIDs: [String]) -> Bool {
        guard Storage.fileExists("mobilitykit_devices.json", in: .documents) else { return false }
        let devices = Storage.retrieve("mobilitykit_devices.json", from: .documents, as: [String: MBDevice].self)
        for uid in deviceUIDs {
            if devices[uid]?.inCarDevice ?? false {
                return true
            }
        }
        return false
    }
    
    override init() {
        _devices = Storage.fileExists(filename, in: .documents) ? Storage.retrieve(filename, from: .documents, as: [String: MBDevice].self) : [:]
        super.init()
        
        // Prepare bluetooth connection monitoring
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: .allowBluetooth)
        } catch let error {
            print("MobilityKit - DeviceManager: Error while configuring bluetooth monitoring: \(error.localizedDescription)")
        }
        
        // Update list of currently connected devices
        updateConnectionStates()
    }
    
    
    func startMonitoring() {
        isMonitoring = true
        addObserver()
        
        timer = Timer(timeInterval: 5.0, repeats: true, block: { (timer) in
            self.updateConnectionStates()
        })
        timer?.tolerance = 1.0
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    func stopMonitoring() {
        removeObserver()
        
        // stop timer
        timer?.invalidate()
        timer = nil
        
        // disconnect all devices
        dispatchQueueNotification.sync {
            for uid in _connectedUIDs {
                delegate?.deviceManager(self, didDisconnect: _devices[uid]!)
            }
            _connectedUIDs = []
        }

        isMonitoring = false
    }
    
    
    func devices() -> [MBDevice] {
        return _devices.map { $0.value }
    }
    
    func connectedDevices() -> [MBDevice] {
        var devices = [MBDevice]()
        if let inputs = AVAudioSession.sharedInstance().availableInputs {
            for input in inputs {
                if input.portType == .carAudio || input.portType == .bluetoothHFP {
                    if !_devices.keys.contains(input.uid) {
                        // register new device
                        dispatchQueueStorage.sync {
                            _devices[input.uid] = MBDevice(input)
                            Storage.store(_devices, to: .documents, as: filename)
                            delegate?.deviceManager(self, didDetect: _devices[input.uid]!)
                        }
                    }
                    devices.append(_devices[input.uid]!)
                }
            }
        }
        return devices
    }
    
    var inCar: Bool { get { return connectedDevices().contains { $0.inCarDevice } } }
    
    func update(deviceUID: String, registeredAsCar: Bool) {
        guard _devices.keys.contains(deviceUID) else { return }
        dispatchQueueStorage.sync {
            _devices[deviceUID]!.registeredAsCar = registeredAsCar
            Storage.store(_devices, to: .documents, as: filename)
        }
    }
    
    func update(deviceUID: String, newActivityItems: Int, automotive: Int) {
        guard _devices.keys.contains(deviceUID) else { return }
        dispatchQueueStorage.sync {
            _devices[deviceUID]!.activityTotalCount += newActivityItems
            _devices[deviceUID]!.activityAutomotiveCount += automotive
            Storage.store(_devices, to: .documents, as: filename)
        }
    }
    
    
    // Mark - Internal stuff
    
    private func addObserver() {
        removeObserver()
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    private func removeObserver() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    private func updateConnectionStates() {
        dispatchQueueNotification.sync {
            let devices = connectedDevices()
            let oldDevices = _connectedUIDs
            _connectedUIDs = devices.map({$0.uid})
            for device in devices {
                if !_connectedUIDs.contains(device.uid) {
                    delegate?.deviceManager(self, didConnect: device)
                }
            }
            for uid in oldDevices {
                if !devices.map({$0.uid}).contains(uid) {
                    delegate?.deviceManager(self, didDisconnect: _devices[uid]!)
                }
            }
            
        }
    }

    @objc func handleRouteChange(notification: Notification) {
        updateConnectionStates()
    }
        
}




