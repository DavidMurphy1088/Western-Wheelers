import Foundation
import UIKit

import CoreLocation
import SwiftUI
import os.log
import CloudKit
import Combine

class UserModel : ObservableObject {
    static let defaults = UserDefaults.standard
    static let JOINED_RIDE_KEY = "ww_ride_joined"
    static var userModel = UserModel() //singleton
    
    @Published private(set) var currentUser:User? = nil // created when user signs into WW, exists when apps find data in localUserModel.defaults at startup, ceases to exist when user deletes their profile
    @Published private(set) var fetchedIDUser:User? = nil
    @Published private(set) var emailSearchUser:User? = nil
    private var queryStartTime: Date?
    
    //@Published
    public let userProfileListSubject = PassthroughSubject<[User]?, Never>()

    init() {
        if let _ = UserModel.defaults.string(forKey: "email") {
            currentUser = User(fromLocalSettings: true)
        }
    }
    
    func setCurrentUser(user:User) {
        DispatchQueue.main.async {
            self.currentUser = User(user: user)
        }
    }
    
    func notifyAllLoaded(loaded:[User]) {
        let sortedUsers = loaded.sorted {
            ($0.nameLast ?? "") < ($1.nameLast ?? "")
        }
        //self.userProfileList = sortedUsers
        DispatchQueue.main.async {
            self.userProfileListSubject.send(sortedUsers)
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
        print("= Load all users, warmup", warmup)
        queryStartTime = Date()
        
        //must use cursor since max records is ~100 on Cloudkit
        //https://gist.github.com/felixmariaa/fc7fe3ab78748793146e6450dd8e2c59#file-viewcontroller-swift
        var listAll:[User] = []
        let queryOperation = CKQueryOperation(query: CKQuery(recordType: "People", predicate: NSPredicate(value: true)))
        // specify the zoneID from which the records should be retrieved
        queryOperation.desiredKeys = ["email", "name_last", "name_first", "ride_joined_id", "ride_joined_session", "ride_joined_level", "ride_joined_date"]
        queryOperation.queuePriority = .veryHigh
        queryOperation.qualityOfService = .userInteractive
        
        if warmup {
            //pre-fetch on Cloudkit to make subsequent queries faster - maybe?
            //CKAssets (eg images) are cached locally but there is no guarantee for how long
            //so dont cache images here since it just thrashes the small local cache,
            //but hopefully the other (small size) fields of the user records are cached.
            queryOperation.recordFetchedBlock = {record in
                //let user = User(record: record)
                //self.fetchUser(recordId: user.recordId!, notify: false)
            }
        } else {
            queryOperation.recordFetchedBlock = {record in
                listAll.append(User(record: record))
            }
        }
        
        if warmup {
            queryOperation.queryCompletionBlock = { (cursor : CKQueryOperation.Cursor?, error : Error?) -> Void in
                let tm = Date().timeIntervalSince1970 - self.queryStartTime!.timeIntervalSince1970
                print("= Load all users, warmup complete. secs:", tm)
            }

        } else {
            queryOperation.completionBlock = {
                self.notifyAllLoaded(loaded: listAll)
            }
            queryOperation.queryCompletionBlock = { [weak self] (cursor : CKQueryOperation.Cursor?, error : Error?) -> Void in
                // Continue if there are no errors
                guard error == nil else {
                    Util.app().reportError(class_type: type(of: self!), context: "Cannot load users", error: error?.localizedDescription ?? "")
                    //completion(error)
                    return
                }
                // Invoke completion if there is no cursor
                guard cursor != nil else {
                    return
                }
                // Add another operation to fetch remaining records using cursor
                let nextOperation = CKQueryOperation(cursor: cursor!)
                nextOperation.queuePriority = .veryHigh
                nextOperation.qualityOfService = .userInteractive

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
        operation.queuePriority = .veryHigh
        operation.qualityOfService = .userInteractive //see https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/PrioritizeWorkWithQoS.html
        operation.recordFetchedBlock = { record in
            fetch(record)
        }
        
        operation.queryCompletionBlock = {(cursor, error) in //{ [unowned self] (cursor, error) in
            if error == nil {
                completion()
            } else {
                Util.app().reportError(class_type: type(of: self), context: "Cannot remote query users", error: error?.localizedDescription ?? "")
            }
        }
        CKContainer.default().publicCloudDatabase.add(operation)
    }
        
    func getUserById(recordId : CKRecord.ID, notify:Bool = true) {
        let fetchOperation = CKFetchRecordsOperation(recordIDs: [recordId])
        fetchOperation.queuePriority = .veryHigh
        fetchOperation.qualityOfService = .userInteractive
        fetchOperation.perRecordCompletionBlock = { (record: CKRecord?, recordID: CKRecord.ID?, error: Error?) -> Void in
            // Continue if there are no errors
            guard error == nil else {
                DispatchQueue.main.async {
                    Util.app().reportError(class_type: type(of: self), context: "Cannot fetch user record", error: error?.localizedDescription ?? "")
                }
                return
            }
            if let record = record {
                if notify {
                    DispatchQueue.main.async {
                        self.fetchedIDUser = User(record: record)
                    }
                }
            }
        }
        self.fetchedIDUser = nil
        CKContainer.default().publicCloudDatabase.add(fetchOperation)
    }

    
    func searchUserByEmail(email: String) {
        var queryUser:User? = nil
        let pred = NSPredicate(format: "email == %@", email)
        self.remoteQuery(pred: pred, fields: ["email", "info", "picture", "name_last", "name_first", "ride_joined_id", "ride_joined_session", "ride_joined_level"],
        fetch: {record in
            queryUser = User(record: record)
        },
        completion: {
            DispatchQueue.main.async {
                if let user = queryUser  {
                    if let eventId = user.joinedRideEventId {
                        //check user was on ride that finished
                        var fnd = false
                        for ride in Rides.instance().rides {
                            if ride.eventId == eventId && ride.sessionId == user.joinedRideSessionId {
                                fnd = true
                                break
                            }
                        }
                        if !fnd {
                            user.joinedRideEventId = nil
                            user.joinedRideSessionId = 0
                            user.joinedRideLevel = nil
                        }
                    }
                    self.emailSearchUser = user
                }
                else {
                    self.emailSearchUser = nil
                }
            }
        })
    }
    
}

extension UIImage {
    func resized(withPercentage percentage: CGFloat, isOpaque: Bool = true) -> UIImage? {
        let canvas = CGSize(width: size.width * percentage, height: size.height * percentage)
        let format = imageRendererFormat
        format.opaque = isOpaque
        return UIGraphicsImageRenderer(size: canvas, format: format).image {
            _ in draw(in: CGRect(origin: .zero, size: canvas))
        }
    }
}

class User : ObservableObject, Identifiable { 
    
    // The value of identifierForVendor is the same for apps that come from the same vendor running on the same device
    // e.g. if the app is deleted and re-installed the device id changes..
    //var deviceId: String dont use device ID as a record key since it changes on every install of the app
    private(set) var email:String? = nil
    private(set) var recordId: CKRecord.ID? = nil
    
    var nameFirst: String? = nil
    var nameLast: String? = nil
    var info: String? = nil
    var picture: UIImage? = nil

    // joined ride
    var joinedRideEventId: String? = nil
    var joinedRideSessionId: Int = 0
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
    
    init(email: String) {
        self.email = email
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
        if let data = record["ride_joined_id"] {
            joinedRideEventId = data.description
        }
        if let data = record["ride_joined_session"] {
            joinedRideSessionId = Int(data.description) ?? 0
        }
        if let data = record["ride_joined_level"] {
            joinedRideLevel = data.description
        }
        
        let image : CKAsset? = record["picture"]
        if let image = image {
            if let imageURL = image.fileURL {
                if let data = NSData(contentsOf: imageURL) {
                    picture = UIImage(data: data as Data)
                    //let data1 = picture!.jpegData(compressionQuality: 1.0)
                    //picture = picture!.resized(withPercentage: 1.0)
                }
            }
        }
    }
    
    init(user:User) {
        self.recordId = user.recordId
        self.email = user.email
        self.nameFirst = user.nameFirst
        self.nameLast = user.nameLast
        self.info = user.info
        self.picture = user.picture
        self.joinedRideEventId = user.joinedRideEventId
        self.joinedRideSessionId = user.joinedRideSessionId
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
                            sleep(1) //dont remove, despite loadUsers coming after the completion of add the new record is not loaded (unless there is a sleep). No idea why...
                            UserModel.userModel.loadAllUsers()
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

        let pred = NSPredicate(format: "email == %@", email)
        UserModel.userModel.remoteQuery(pred: pred, fields: ["email"], fetch: { rec in
            self.recordId = rec.recordID
        },
        completion: {
            if self.recordId == nil {
                Util.app().reportError(class_type: type(of: self), context: "user record to delete not found")
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
        let ckRecord = CKRecord(recordType: "People")
        ckRecord["email"] = email as CKRecordValue
        if let name = self.nameFirst {
            ckRecord["name_first"] = name as CKRecordValue
        }
        if let name = self.nameLast {
            ckRecord["name_last"] = name as CKRecordValue
        }
        if let info = self.info {
            ckRecord["info"] = info as CKRecordValue
        }
        ckRecord["picture"] = picData(img: self.picture)

        let op = CKModifyRecordsOperation(recordsToSave: [ckRecord], recordIDsToDelete: [])
        op.queuePriority = .veryHigh
        op.qualityOfService = .userInteractive

        op.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            if error != nil || savedRecords == nil || savedRecords?.count != 1 {
                Util.app().reportError(class_type: type(of: self), context: "Cannot add user record", error: error?.localizedDescription ?? "")
                return
            }
            guard let records = savedRecords else {
                Util.app().reportError(class_type: type(of: self), context: "add user, nil record")
                return
            }
            let record = records[0]
            guard (record["email"] as? String) != nil else {
                Util.app().reportError(class_type: type(of: self), context: "add user but no email stored")
                return
            }
            completion(record.recordID)
        }
        CKContainer.default().publicCloudDatabase.add(op)
    }
    
    private func picData(img : UIImage?) -> CKAsset? {
        guard let img = img else {
            return nil
        }
        // cannot find any other way other than to construct the asset from a file
        // user jpeg, not png since png looses the orientation
        let imgData = img.jpegData(compressionQuality: 1.0)
        guard var data = imgData else {
            return nil
        }
        let orgSizeBytes = data.count
        var compRatio = 1.0
        let maxSizeBytes = 512 * 1024
        if orgSizeBytes > maxSizeBytes {
            compRatio = Double(maxSizeBytes) / Double(orgSizeBytes)
            data = img.jpegData(compressionQuality: CGFloat(compRatio))!
        }
        let fileURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(NSUUID().uuidString+".dat")
        try? data.write(to: fileURL!)
        return CKAsset(fileURL: fileURL!)
    }
    
    public func remoteModify(completion: @escaping () -> Void) {
        guard let email = email else {
            os_log("attempt to modify nil user", log: Log.User, type: .error, "")
            return
        }
        let ckRecord = CKRecord(recordType: "People", recordID: self.recordId!)
        ckRecord["email"] = email as CKRecordValue
        if let data = self.nameFirst {
            ckRecord["name_first"] = data as CKRecordValue
        }
        if let data = self.nameLast {
            ckRecord["name_last"] = data as CKRecordValue
        }
        if let data = self.info {
            ckRecord["info"] = data as CKRecordValue
        }
        if let data = self.joinedRideEventId {
            ckRecord["ride_joined_id"] = data as CKRecordValue
            ckRecord["ride_joined_session"] = self.joinedRideSessionId
        }
        else {
            ckRecord["ride_joined_id"] = ""
            ckRecord["ride_joined_session"] = 0
        }
        if let data = self.joinedRideLevel {
            ckRecord["ride_joined_level"] = data as CKRecordValue
        }
        else {
            ckRecord["ride_joined_level"] = ""
        }
        if let data = self.joinedRideDate{
            ckRecord["ride_joined_date"] = data as CKRecordValue
        }

        ckRecord["picture"] = picData(img: self.picture)
        
        let op = CKModifyRecordsOperation(recordsToSave: [ckRecord], recordIDsToDelete: [])
        op.queuePriority = .veryHigh
        op.qualityOfService = .userInteractive
        op.savePolicy = .allKeys  //2 hours later ... required otherwise it does NOTHING :( :(
        op.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            if error != nil || savedRecords?.count != 1 {
                Util.app().reportError(class_type: type(of: self), context: "Cannot modify user record", error: error?.localizedDescription ?? "")
            }
            else {
                completion()
            }
        }
        CKContainer.default().publicCloudDatabase.add(op)
    }
    
    private func remoteDelete(completion: @escaping () -> Void) {
        let op = CKModifyRecordsOperation(recordsToSave: [], recordIDsToDelete: [self.recordId!])
        op.queuePriority = .veryHigh
        op.qualityOfService = .userInteractive
        op.savePolicy = .allKeys  //2 hours later ... required otherwwise it does NOTHING :( :(
        op.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            if error != nil || deletedRecordIDs?.count != 1 {
                Util.app().reportError(class_type: type(of: self), context: "Cannot delete user record", error: error?.localizedDescription ?? "")
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
        
    func leaveRide(left_ride: Ride) {
        self.joinedRideEventId = nil
        self.joinedRideSessionId = 0
    
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

