import os

private let subsystem = "org.ww"

//https://www.raywenderlich.com/605079-migrating-to-unified-logging-console-and-instruments
// formats https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFStrings/formatSpecifiers.html
// https://developer.apple.com/documentation/os/logging

struct Log {
    static let User = OSLog(subsystem: subsystem, category: "User")
    static let App = OSLog(subsystem: subsystem, category: "App")
    static let Scene = OSLog(subsystem: subsystem, category: "Scene")
    static let RidesLoader = OSLog(subsystem: subsystem, category: "RidesLoader")
    static let Ride = OSLog(subsystem: subsystem, category: "Ride")
    static let RideLevelView = OSLog(subsystem: subsystem, category: "RideLevelView")
    static let RidersListView = OSLog(subsystem: subsystem, category: "RidersListView")
    static let wa_api = OSLog(subsystem: subsystem, category: "wa_api")
    static let UserView = OSLog(subsystem: subsystem, category: "UserView")
    static let RidersTracker = OSLog(subsystem: subsystem, category: "RidersTracker")
    static let LocationManager = OSLog(subsystem: subsystem, category: "LocationManager")
    static let CloudKitManager = OSLog(subsystem: subsystem, category: "CloudKitManager")

    static let RideView = OSLog(subsystem: subsystem, category: "RideView")
    static let RiderLocationsView = OSLog(subsystem: subsystem, category: "RiderLocationsView")
    
    static let RiderLocationsMapView = OSLog(subsystem: subsystem, category: "RiderLocationsMapView")
    static let MapView = OSLog(subsystem: subsystem, category: "MapView")
}
