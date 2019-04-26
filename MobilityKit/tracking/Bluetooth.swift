//
//  Bluetooth.swift
//  Monitors if Bluetooth is available or not
//
//  Created by Tobias Frech on 09.11.18.
//  Copyright © 2016-2019 niato UG / budo GmbH. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BluetoothDelegate {
    func bluetooth(available: Bool)
}

@objc(Bluetooth)
class Bluetooth: NSObject, CBCentralManagerDelegate {

    public var delegate: BluetoothDelegate?
    private var bleCentralManager: CBCentralManager?
    public private(set) var available: Bool
    
    public override init() {
        available = false
        let localCentralQueue = DispatchQueue(label: "mobilitykit.bluetooth.central)", attributes: .concurrent)
        super.init()
        bleCentralManager = CBCentralManager(delegate: self, queue: localCentralQueue)
    }
    
    @objc public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let available = (central.state == .poweredOn)
        let hasChanged = (self.available != available)
        self.available = available
        if hasChanged {
            delegate?.bluetooth(available: available)
        }
    }
    
}
