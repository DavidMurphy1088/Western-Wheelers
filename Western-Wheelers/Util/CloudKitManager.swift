import CloudKit
import os.log

class CloudKitManager {

    static var manager = CloudKitManager()
    
    private let container = CKContainer.default()

    private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    var status_msg = ""

    init() {
    }
    
    func canReadData() -> Bool {
        //In development, when you run your app through Xcode on a simulator or a device, you need to enter iCloud credentials to read records in the public database.
        //In production, the default permissions allow non-authenticated users to read records in the public database but do not allow them to write records.
        if FileManager.default.ubiquityIdentityToken != nil {
            return true
        } else {
            return false
        }
    }

    public func loadGlobalSettings() {
        let pred = NSPredicate(value: true)
        let query = CKQuery(recordType: "GlobalSettings", predicate: pred)

        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["location_update_accuracy", "track_riders_delay_secs"]
        operation.resultsLimit = 2
        operation.queuePriority = .veryHigh
        operation.qualityOfService = .userInteractive

        operation.recordFetchedBlock = { record in
            let delay_secs = record["track_riders_delay_secs"] as! UInt32
            //let accuracy = record["location_update_accuracy"] as! Int
            RidersTracker.tracker.track_riders_delay_secs = delay_secs
            //LocationManager.lm().accuracy = accuracy
        }
        
        operation.queryCompletionBlock = { (cursor, error) in
            if error != nil {
                Util.app().reportError(class_type: type(of: self), context: "Load global settings", error: error?.localizedDescription)
            }
        }
        CKContainer.default().publicCloudDatabase.add(operation)
    }
}
