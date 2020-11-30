# MobilityKit

First open source mobility detection framework for iOS

With the MobilityKit you are able to track the users mobility behavior. It automatically recordes every movement and provides an easy to use model including all visited places and the mobility timeline.

## Install MobilityKit

### Installing with Carthage

Add the following to your `Cartfile`:

```
github "mobilitykit/mobilitykit-ios"
```

Then run `carthage update`.

### Installing with CocoaPods

Add the following to your `Podfile`:

```ruby
use_frameworks!
pod 'MobilityKit', :git => 'https://github.com/mobilitykit/mobilitykit-ios.git'
```

Then run `pod install`.


## Getting started

Prepare your Xcode project to work with the MobilityKit

### Background location

To enable background location updates, the Xcode project must enable the "Location updates" background mode in the capabilities section of the target setting.


### Update Info.plist

An iOS app must include usage description keys in its Info.plist file for the types of data it needs. Failure to include these keys will cause the app to crash.

Add the following keys with usage descriptions:

* `NSLocationWhenInUseUsageDescription`
* `NSLocationAlwaysAndWhenInUseUsageDescription`
* `NSMotionUsageDescription`
* `NSBluetoothPeripheralUsageDescription`


### Request user permission

Ask user for location update permission
```
MobilityKit.requestLocationPermission({ (status) in
  if status == .authorized {
    // user has given permission
  }
})
```

Ask user for activity recognition permission
```
MobilityKit.requestMotionPermission({ (status) in
  if status == .authorized {
    // user has given permission
  }
})
```

### Start MobilityKit

Starting mobility tracking
```
MobilityKit.start()
```

### Get data

Getting the mobility timeline
```
// get the model
let model = MobilityKit.model()

// iterate through the mobility timeline
for event in model.events {
  // do stuff with the recorded trips and visits
}
```

### Get events

To receive realtime events from the MobilityKit register the MobilityKitDelegate
```
class MyDelegate : MobilityKitDelegate {

  func mobilityKit(didArrive location: MBLocation) {
    // do stuff after arrival...
  }

  func mobilityKit(didDepart location: MBLocation) {
    // do stuff after departure...
  }

}
```
