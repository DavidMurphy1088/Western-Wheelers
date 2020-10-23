import Foundation
import os.log
import CloudKit
import Foundation
import os.log
import CloudKit

class UserMessage : Identifiable {
    var message:String
    var datetime:Date
    var rider:User
    init (rid:User, msg:String, time:Date) {
        self.message = msg
        self.datetime = time
        self.rider = rid
    }
}

class RidersTracker : ObservableObject {
    static var tracker = RidersTracker()
    var tracking_ride:Ride? = nil
    var ref_count = 0 // only stop when all listeners have said stop
    
    var tracked_riders = [User]()
    var tracked_messages = [UserMessage]()
    
    var last_query_rider_ids:[String] = [String]() // the riders that were found in the most recent query

    let queue = DispatchQueue.global()
    var suspended_ride:Ride?
    var suspended_ref_count:Int?
    
    var track_riders_delay_secs:UInt32 = 8
    
    @Published var refresh_notifcation_count = 0

    // Cloud Kit
    
    let container: CKContainer
    let publicDB: CKDatabase
    //let privateDB: CKDatabase
    
    private(set) var users: [User] = []

    init () {
        container = CKContainer.default()
        publicDB = container.publicCloudDatabase
    }
    
    //e.g when app goes background no view gets .onDisappear
    func suspend() {
        self.suspended_ride = self.tracking_ride
        //self.suspended_ref_count = self.ref_count
        self.tracking_ride = nil
    }

    //e.g app back from background
    func resume() {
        if let ride = self.suspended_ride {
            self.tracking_ride = ride
            self.start_queue(ride_to_track: ride)
            self.suspended_ride = nil
        }
    }

    func start_tracking(ride_to_track: Ride) {
        self.suspended_ride = nil
        ref_count += 1
        if ref_count == 1 {
            tracking_ride = ride_to_track
            start_queue(ride_to_track: ride_to_track)
        }
    }
    
    func stop_tracking() {
        if ref_count > 0 {
            ref_count -= 1
            if ref_count == 0 {
                self.tracking_ride = nil
                self.tracked_riders = [User]()
                self.tracked_messages = [UserMessage]()
            }
        }
    }

    private func start_queue(ride_to_track: Ride) {
        queue.async {
            while self.tracking_ride == ride_to_track {
                //self.query_simulate(ride: ride_to_track)
                self.query_remote(ride: ride_to_track)
                DispatchQueue.main.async {
                    self.refresh_notifcation_count += 1
                }
                sleep(self.track_riders_delay_secs) //Dont delete
            }
        }
    }
    
    private func query_remote(ride: Ride) {
        guard let ride = self.tracking_ride else {
            return
        }
        let filter = ""//ride_id = \"\(ride.rideId)\""
        let pred = NSPredicate(format: filter)
        let query = CKQuery(recordType: "Riders", predicate: pred)
        self.last_query_rider_ids = []
        
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["ride_id", "rider_id", "loc_latitude", "loc_longitude", "loc_last_update", "name_first", "name_last", "user_message"]
        operation.resultsLimit = 400
        operation.queuePriority = .veryHigh
        operation.qualityOfService = .userInteractive
        
        operation.recordFetchedBlock = { record in
            // try to avoid deleting and re-creating rider record since it makes the UI jerky. Better to update the rider record when possible
            let queried_rider_id = record["rider_id"] as! String
            let lat = record["loc_latitude"] as! Double
            if lat == 0.0 {
                // rider left ride
                return
            }
            self.last_query_rider_ids.append(queried_rider_id)
            var fnd_rider:User?
            var index = 0
            for rider in self.tracked_riders {
                if rider.email == queried_rider_id {
                    fnd_rider = rider
                    break
                }
                index += 1
            }

//            if fnd_rider == nil {
//                fnd_rider = User(local: false)
//                self.tracked_riders.append(fnd_rider!)
//            }
            
            //fnd_rider!.deviceId = record["rider_id"] as! String
            //fnd_rider!.joinedRideID?.rideId = record["ride_id"] as! String
            fnd_rider!.location_latitude = record["loc_latitude"]
            fnd_rider!.location_longitude = record["loc_longitude"]
            fnd_rider!.location_last_update = record["loc_last_update"]

            // process user message
            
            if record["user_message"] != nil && fnd_rider!.location_last_update != nil {
                let new_msg = record["user_message"] as! String
                if new_msg.count > 0 {
                    let duplicate = false
                    for _ in self.tracked_messages {
//                        if msg.rider.deviceId == fnd_rider?.deviceId {
//                            duplicate = msg.message == new_msg
//                            break
//                        }
                    }
                    if !duplicate {
                        let um = UserMessage(rid: fnd_rider!, msg: new_msg, time: fnd_rider!.location_last_update!)
                        self.tracked_messages.insert(um, at: 0)
                    }
                }
            }
        }
        
        operation.queryCompletionBlock = { [unowned self] (cursor, error) in
            if error == nil {
                var index = 0
                for _ in self.tracked_riders {
                    // rider was in ride left it. That rider's app has set the riders location to zero
//                    if !self.last_query_rider_ids.contains(rider.email) {
//                        if index < self.tracked_riders.count {
//                            self.tracked_riders.remove(at: index)
//                        }
//                    }
                    index += 1
                }
            } else {
            }
        }
        CKContainer.default().publicCloudDatabase.add(operation)
    }

    private func query_simulate (ride:Ride) {
        let user = User() //.user
        let count = Int.random(in: 4..<15)
        for i in 1...count {
            let new_rider = User()
            
            if user.location_latitude != nil {
                let dx = Double.random(in: -0.0005 ..< 0.0005)
                let dy = Double.random(in: -0.0005 ..< 0.0005)
                new_rider.location_latitude = user.location_latitude! + dx
                new_rider.location_longitude = user.location_longitude! + dy
            }
            let upd = Date()
            let secs = Int.random(in: 30..<300)
            new_rider.location_last_update = upd.advanced(by: Double(0-secs))
            new_rider.nameFirst = "fname\(i)"
            self.tracked_riders.append(new_rider)
        }
    }
}

