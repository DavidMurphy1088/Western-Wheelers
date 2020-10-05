import UIKit
import CloudKit
import CoreLocation
import Combine
import os.log
import UserNotifications
import MapKit
import CoreData
import FBSDKCoreKit

class AppClass :ObservableObject {
    static var instance = AppClass()
    @Published var userMessage: String! = nil
    static func app() -> AppClass {
            //Thread 2: UIApplication.delegate must be used from main thread only
            //return UIApplication.shared.delegate as! AppDelegate *** BAD
            return instance
    }
    
    func reportError(class_type: CFTypeRef, usrMsg:String?, error: String? = nil, tellUsers:Bool = true) {
        let detailedMsg = "ERROR class:\(class_type) usr:[\(usrMsg ?? "")] err:[\(error ?? "nil")]"
        os_log("ERROR err:[%s] usrMsg:[%s]", log: Log.App, type: .error, "\(error ?? "nil")", "\(usrMsg ?? "nil")", "tell users:", tellUsers)
        print("===================ERROR", detailedMsg)
        if tellUsers {
            DispatchQueue.main.async {
                self.userMessage = "\(usrMsg ?? "") \n\(error ?? "")"
            }
        }
    }
    func clearError() {
        os_log("Last error cleared", log: Log.App, type: .error)
        DispatchQueue.main.async {
            self.userMessage = nil
        }
    }

}
