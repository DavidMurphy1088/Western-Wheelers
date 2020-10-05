import Foundation
import UIKit

import CoreLocation
import SwiftUI
import os.log
import CloudKit

class UserModel : ObservableObject {
    static let defaults = UserDefaults.standard
    static let JOINED_RIDE_KEY = "ww_ride_joined"
    static var userModel = UserModel() //singleton
    
    @Published var currentUser:User? = nil // created when user signs into WW, exists when apps find data in localUserModel.defaults at startup, ceases to exist when user deletes their profile
    @Published var userProfileList:[User]? = nil
    @Published var fetchedUser:User? = nil
    
    init() {
        if let _ = UserModel.defaults.string(forKey: "email") {
            currentUser = User(fromLocalSettings: true)
        }
    }
    
    func notifyAllLoaded(loaded:[User]) {
        let sortedUsers = loaded.sorted {
            ($0.nameLast ?? "") < ($1.nameLast ?? "")
        }
        DispatchQueue.main.async {
            self.userProfileList = sortedUsers
        }
    }
    
    public func loadAllUsers(warmup:Bool = false) {
//        for n in 100...200 {
//            //test data...
//            let user = User()
//            user.email = "e\(n)@.com"
//            user.nameLast = "Zaborowski_\(n)"
//            user.nameFirst = "Dmitriy_\(n)"
//            user.info = "my info"
//            user.remoteAdd(completion: {id in pxrint (id)})
//        }

        //must use cursor since max records is ~100 on Cloudkit
        //https://gist.github.com/felixmariaa/fc7fe3ab78748793146e6450dd8e2c59#file-viewcontroller-swift
        var listAll:[User] = []
        let queryOperation = CKQueryOperation(query: CKQuery(recordType: "People", predicate: NSPredicate(value: true)))
        // specify the zoneID from which the records should be retrieved
        queryOperation.desiredKeys = ["email", "name_last", "name_first", "ride_joined_id", "ride_joined_level", "ride_joined_date"]
        
        if warmup {
            queryOperation.recordFetchedBlock = {record in
                if self.currentUser != nil {
                    let user = User(record: record)
                    self.fetchUser(recordId: user.recordId!, notify: false)
                }
            }
            
        } else {
            queryOperation.recordFetchedBlock = {record in
                // very bad idea, current user may not yet have a record id
//                if let currentUser = self.currentUser {
//                    if record["email"] == currentUser.email {
//                        listAll.append(User(user: currentUser))
//                    }
//                    else {
//                        listAll.append(User(record: record))
//                    }
//                }
//                else {
                    listAll.append(User(record: record))
//                }
            }
        }
        
        if !warmup {
            queryOperation.completionBlock = {
                self.notifyAllLoaded(loaded: listAll)
            }
        }
        
        if !warmup {
            queryOperation.queryCompletionBlock = { [weak self] (cursor : CKQueryOperation.Cursor?, error : Error?) -> Void in
                // Continue if there are no errors
                guard error == nil else {
                    Util.app().reportError(class_type: type(of: self!), usrMsg: "Cannot load users", error: error?.localizedDescription ?? "")
                    //completion(error)
                    return
                }
                // Invoke completion if there is no cursor
                guard cursor != nil else {
                    return
                }
                // Add another operation to fetch remaining records using cursor
                let nextOperation = CKQueryOperation(cursor: cursor!)
                nextOperation.recordFetchedBlock = {record in
                    listAll.append(User(record: record))
                }
                // Attach the existing completion block
                nextOperation.completionBlock = {
                    self!.notifyAllLoaded(loaded: listAll)
                }
                nextOperation.resultsLimit = queryOperation.resultsLimit
                CKContainer.default().publicCloudDatabase.add(nextOperation)
            }
        }
        
        CKContainer.default().publicCloudDatabase.add(queryOperation)
    }
    
    func remoteQuery(pred: NSPredicate, fields: [String], fetch: @escaping (CKRecord) -> Void, completion: @escaping () -> Void) {
        let query = CKQuery(recordType: "People", predicate: pred)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = fields
        //operation.resultsLimit = 1
        operation.queuePriority = .veryHigh
        operation.qualityOfService = .userInteractive //see https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/PrioritizeWorkWithQoS.html
        //operation.resultsLimit = CKQueryOperation.maximumResults
        operation.recordFetchedBlock = { record in
            fetch(record)
        }
        
        operation.queryCompletionBlock = {(cursor, error) in //{ [unowned self] (cursor, error) in
            if error == nil {
                completion()
            } else {
                Util.app().reportError(class_type: type(of: self), usrMsg: "Cannot remote query", error: error?.localizedDescription ?? "")
            }
        }
        CKContainer.default().publicCloudDatabase.add(operation)
    }
    
    func fetchUser(recordId : CKRecord.ID, notify:Bool = true) {
        CKContainer.default().publicCloudDatabase.fetch(withRecordID: recordId) { /*[unowned self]*/ record, error in
            if let _ = error {
                DispatchQueue.main.async {
                    Util.app().reportError(class_type: type(of: self), usrMsg: "Cannot fetch record", error: error?.localizedDescription ?? "")
                }
            } else {
                if let record = record {
                    if notify {
                        DispatchQueue.main.async {
                            self.fetchedUser = User(record: record)
                        }
                    }
                }
            }
        }
    }
    
    func searchUserByEmail(email: String) {
        var queryUser:User? = nil
        let pred = NSPredicate(format: "email == %@", email)
        self.remoteQuery(pred: pred, fields: ["email", "info", "picture", "name_last", "name_first", "ride_joined_id", "ride_joined_level", "ride_joined_date"],
        fetch: {record in
            queryUser = User(record: record)
        },
        completion: {
            DispatchQueue.main.async {
                if let user = queryUser  {
                    if let rideId = user.joinedRideID {
                        //user was on ride that finished
                        var fnd = false
                        for ride in Rides.instance().rides {
                            if ride.rideId == rideId {
                                fnd = true
                                break
                            }
                        }
                        if !fnd {
                            user.joinedRideID = nil
                            user.joinedRideLevel = nil
                        }
                    }
                    self.fetchedUser = user
                }
                else {
                    self.fetchedUser = nil
                }
            }
        })
    }
        
}

class User : ObservableObject, Identifiable { //: NSObject, Identifiable, CLLocationManagerDelegate, ObservableObject {
    //@Published var locationUpdateCount = 0 // tell listeners to update
    //@Published var userLoaded:User? = nil
    
    // The value of identifierForVendor is the same for apps that come from the same vendor running on the same device
    // e.g. if the app is deleted and re-installed the device id changes..
    //var deviceId: String dont use device ID as a record key since it changes on every install of the app
    var email:String? = nil
    var recordId: CKRecord.ID? = nil
    
    var nameFirst: String? = nil
    var nameLast: String? = nil
    var info: String? = nil
    var picture: UIImage? = nil

    // joined ride
    var joinedRideID: String? = nil
    var joinedRideLevel: String? = nil
    var joinedRideDate:Date? = nil

    // location
    
    var location_last_update:Date? = nil
    var location_latitude:Double? = nil
    var location_longitude:Double? = nil
    var location_message:String = ""

    // -------------------- app state ---------------------
    
    init() {
    }
    
    init(fromLocalSettings:Bool) {
        if fromLocalSettings {
            if let email = UserModel.defaults.string(forKey: "email") {
                self.email = email
                self.nameLast = UserModel.defaults.string(forKey: "name_last")
                self.nameFirst = UserModel.defaults.string(forKey: "name_first")
                
//                self.email = "david2.murphy2@sbcglobal.net "
//                self.nameLast = "Ferdinand"
//                self.nameFirst = "Magellan"
                //              self.info = User.defaults.string(forKey: "info")
                //              if let imgData = User.defaults.object(forKey: "picture") as? NSData {
                //                self.picture = UIImage(data: imgData as Data)'
            }
        }
    }
    
    init(record:CKRecord) {
        // empty "" fields come back as nil
        guard let _ = record["email"] else {
            os_log("attempt to make nil user", log: Log.User, type: .error, "")
            return
        }
        recordId = record.recordID
        email = record["email"]
        if let data = record["name_first"] {
            nameFirst = data.description
        }
        if let data = record["name_last"] {
            nameLast = data.description
        }
        if let data = record["info"] {
            info = data.description
        }
        let file : CKAsset? = record["picture"]
        if let file = file {
            if let data = NSData(contentsOf: file.fileURL!) {
                picture = UIImage(data: data as Data)
            }
        }
        if let data = record["ride_joined_id"] {
            joinedRideID = data.description
        }
        if let data = record["ride_joined_level"] {
            joinedRideLevel = data.description
        }
        //if let data = record["ride_joined_date"] {
            //joinedRideDate = data.description
        //}
    }
    
    init(user:User) {
        self.recordId = user.recordId
        self.email = user.email
        self.nameFirst = user.nameFirst
        self.nameLast = user.nameLast
        self.info = user.info
        self.picture = user.picture
        self.joinedRideID = user.joinedRideID
        self.joinedRideLevel = user.joinedRideLevel
        self.joinedRideDate = user.joinedRideDate
    }
        
    // -------------------- local state ---------------------
    
    func saveLocalUserState() { //email:String?, nameLast:String?, nameFirst:String?) {
        UserModel.defaults.set(email, forKey: "email")
        // save names redundantly for ride stats display to avoid Cloudkit lookup for stats
        UserModel.defaults.set(nameFirst, forKey: "name_first")
        UserModel.defaults.set(nameLast, forKey: "name_last")
    }
        
    func removeLocalSiteData() {
        email = nil
        nameFirst = nil
        nameLast = nil
        picture = nil
        info = ""
        saveLocalUserState() //email: email, nameLast: nameLast, nameFirst: nameFirst)
    }
    
    func saveProfile() {
        guard let email = email else {
            os_log("attempt to save profile nil user", log: Log.User, type: .error, "")
            return
        }
        self.saveLocalUserState()
        DispatchQueue.main.async {
            UserModel.userModel.fetchedUser = UserModel.userModel.currentUser
        }

        let pred = NSPredicate(format: "email == %@", email)
        self.recordId = nil
        UserModel.userModel.remoteQuery(pred: pred, fields: ["email"],
            fetch: { rec in
                self.recordId = rec.recordID
            },
            completion: {
                //if self.queryCount == 0 {
                if self.recordId == nil {
                    self.remoteAdd(completion: {recordId in
                        self.recordId = recordId
                        for _ in 1...3 {
                            UserModel.userModel.loadAllUsers()
                            sleep(1) //dont remove, despite loadUsers coming after the completion of add the new record is not loaded (unless there is a s.leep). No idea why...
                        }
                    })
                }
                else {
                    //self.remoteModify(completion: {self.loadAllUsers()})
                    self.remoteModify(completion: {
                        UserModel.userModel.loadAllUsers()
                    })
                }
            }
        )
    }
    
    func deleteProfile() {
        guard let email = email else {
            os_log("attempt to delete profile nil user", log: Log.User, type: .error, "")
            return
        }
        DispatchQueue.main.async {
            UserModel.userModel.fetchedUser = nil //UserModel.userModel.currentUser
        }

        let pred = NSPredicate(format: "email == %@", email)
        UserModel.userModel.remoteQuery(pred: pred, fields: ["email"], fetch: { rec in
            self.recordId = rec.recordID
        },
        completion: {
            if self.recordId == nil {
                Util.app().reportError(class_type: type(of: self), usrMsg: "record to delete not found")
            } else {
                self.remoteDelete(completion: {
                    self.recordId = nil
                    UserModel.userModel.loadAllUsers()
                    
                })
            }
        })
    }
    
    // ===================== Cloud Kit ============================
    
    func remoteAdd(completion: @escaping (CKRecord.ID) -> Void) {
        guard let email = email else {
            os_log("attempt to add nil user", log: Log.User, type: .error, "")
            return
        }
        let ck_record = CKRecord(recordType: "People")
        ck_record["email"] = email as CKRecordValue
        if let name = self.nameFirst {
            ck_record["name_first"] = name as CKRecordValue
        }
        if let name = self.nameLast {
            ck_record["name_last"] = name as CKRecordValue
        }
        if let info = self.info {
            ck_record["info"] = info as CKRecordValue
        }
        // cannot find any other way other than to construct the asset from a file
        // user jpeg, not png since png looses the orientation
        if let pic = self.picture, let data = pic.jpegData(compressionQuality: 1.0) {
            let fileURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(NSUUID().uuidString+".dat")
            try? data.write(to: fileURL!)
            ck_record["picture"] = CKAsset(fileURL: fileURL!)
        }

        CKContainer.default().publicCloudDatabase.save(ck_record) { (record, err) in
            if let err = err {
                Util.app().reportError(class_type: type(of: self), usrMsg: "remote add", error: err.localizedDescription)
                return
            }
            guard let record = record else {
                Util.app().reportError(class_type: type(of: self), usrMsg: "remote add, nil record", error: err?.localizedDescription)
                return
            }
            guard (record["email"] as? String) != nil else {
                Util.app().reportError(class_type: type(of: self), usrMsg: "remote add no email stored", error: err?.localizedDescription)
                return
            }
            completion(record.recordID)
        }
    }

    public func remoteModify(completion: @escaping () -> Void) {
        guard let email = email else {
            os_log("attempt to modify nil user", log: Log.User, type: .error, "")
            return
        }
        let ck_record = CKRecord(recordType: "People", recordID: self.recordId!)
        ck_record["email"] = email as CKRecordValue
        if let data = self.nameFirst {
            ck_record["name_first"] = data as CKRecordValue
        }
        if let data = self.nameLast {
            ck_record["name_last"] = data as CKRecordValue
        }
        if let data = self.info {
            ck_record["info"] = data as CKRecordValue
        }
        if let data = self.joinedRideID {
            ck_record["ride_joined_id"] = data as CKRecordValue
        }
        else {
            ck_record["ride_joined_id"] = ""
        }
        if let data = self.joinedRideLevel {
            ck_record["ride_joined_level"] = data as CKRecordValue
        }
        else {
            ck_record["ride_joined_level"] = ""
        }
        if let data = self.joinedRideDate{
            ck_record["ride_joined_date"] = data as CKRecordValue
        }

        // user jpeg, not png since png looses the orientation
        if let pic = self.picture, let data = pic.jpegData(compressionQuality: 1.0) {
            let fileURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(NSUUID().uuidString+".dat")
            try? data.write(to: fileURL!)
            ck_record["picture"] = CKAsset(fileURL: fileURL!)
        }
        else {
            ck_record["picture"] = nil
        }
        
        let op = CKModifyRecordsOperation(recordsToSave: [ck_record], recordIDsToDelete: [])
        op.savePolicy = .allKeys  //2 hours later ... required otherwise it does NOTHING :( :(
        op.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            if error != nil || savedRecords?.count != 1 {
                Util.app().reportError(class_type: type(of: self), usrMsg: "Cannot modify record", error: error?.localizedDescription ?? "")
            }
            else {
                completion()
            }
        }
        CKContainer.default().publicCloudDatabase.add(op)
    }
    
    private func remoteDelete(completion: @escaping () -> Void) {
        let op = CKModifyRecordsOperation(recordsToSave: [], recordIDsToDelete: [self.recordId!])
        op.savePolicy = .allKeys  //2 hours later ... required otherwwise it does NOTHING :( :(
        op.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            if error != nil || deletedRecordIDs?.count != 1 {
                Util.app().reportError(class_type: type(of: self), usrMsg: "Cannot delete record", error: error?.localizedDescription ?? "")
            }
            else {
                completion()
            }
        }
        CKContainer.default().publicCloudDatabase.add(op)
    }

    // -------------------- ride state ---------------------
    
    func sendLocationMessage(msg: String) {
        self.location_message = msg
        remoteModify(completion: {
            //self.location_message = "" //not nil since nil does not update remote
        })
    }
    
    func joinRide(ride: Ride) {
        // only create a server record when user joins a ride, otherwise no need
        //??? if the local storage has a remote_id then we know the user exists on the server
        //joinedRideID = ride
        joinedRideDate = Date()
        //locationUpdateCount = 0
        //saveLocalRideState(ride: joined_ride)
        CloudKitManager.manager.loadGlobalSettings()
        //DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .seconds(10)) {
    }
    
    func leaveRide(left_ride: Ride) {
        self.joinedRideID = nil
        //self.saveLocalRideState(ride: nil)
        //LocationManager.lm().stop_updating_location()
    
        // tell others not to show me
        self.location_latitude = 0 // not nil which is ignored during save
        self.location_longitude = 0 // not nil which is ignored during save
        self.remoteModify(completion: {})
            // this screws up refence counting on tracker so it never starts again.
            // Tracker is now only started and stopped using view .onAppear and .onDisappear
            //RidersTracker.tracker.stop_tracking()
        //}
    }
        
    func updateLocation(loc: CLLocation) {
        location_latitude = loc.coordinate.latitude
        location_longitude = loc.coordinate.longitude
        location_last_update = Date()
        //locationUpdateCount += 1
        remoteModify(completion: {})
     }

}

