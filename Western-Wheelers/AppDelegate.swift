
import UIKit
import CloudKit
import CoreLocation
import Combine
import os.log
import UserNotifications
import MapKit
import CoreData
import FBSDKCoreKit
import UIKit
import FBSDKCoreKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, ObservableObject {
    
    @Published var userMessage: String! = nil
    var cloudKitStatus:String = "not connected"
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        /*
         The persistent container for the application. This implementation creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentCloudKitContainer(name: "Western_Wheelers")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    //func reportError(class_type: CFTypeRef, context: String, usrMsg:String, error: String? = nil, tellUsers:Bool = true) {
    func reportError(class_type: CFTypeRef, context: String, error: String? = nil, informUsers:Bool = true) {
        let detailedMsg = "ERROR class:\(class_type) ctx:[\(context)] err:[\(error ?? "nil")]"
        //os_log("ERROR err:[%s] usrMsg:[%s]", log: Log.App, type: .error, "\(error ?? "nil")", "\(usrMsg)", "tell users:", tellUsers)
        os_log("ERROR err:[%s] usrMsg:[%s]", log: Log.App, type: .error, "\(error ?? "nil")", "\(context)")
        print("===================ERROR", detailedMsg)
        if informUsers {
            DispatchQueue.main.async {
                self.userMessage = "\(context)\n\n\(error ?? "")"
            }
        }
    }
    
    func clearError() {
        os_log("Last error cleared", log: Log.App, type: .error)
        DispatchQueue.main.async {
            self.userMessage = nil
        }
    }

    // ================================ Notifcations =================================
    // One of the main differences between Local notification and a Push notification is that local notifications are created, scheduled and are sent from a user iOS device. Push notifications are created and are sent from a remote server.
    // http://www.appsdeveloperblog.com/local-user-notifications-with-unusernotificationcenter/
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Get the meeting ID from the original notification.
        //let userInfo = response.notification.request.content.userInfo

        // Handle other notification types...
        // Always call the completion handler when done.
        completionHandler()
    }

    // ================================  AppDelegate =================================

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        //let auth = LocationManager.lm().location_authorized_msg()
        Util.appDelegate = self

        //establish user's remote id
        //User.user.remote_load()

        // Facebook
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        CKContainer.default().accountStatus { status, error in
            if let error = error {
                self.cloudKitStatus = error.localizedDescription
            } else {
                switch status {
                case .available:
                    self.cloudKitStatus = ""
                case .noAccount:
                    self.cloudKitStatus = "\nYou need to be signed in on your phone with your Apple ID\n"
                case .couldNotDetermine:
                    self.cloudKitStatus = "Could not determine"
                case .restricted:
                    self.cloudKitStatus = "Restricted Access"
                @unknown default:
                    self.cloudKitStatus = "Unknown"
                }
            }
            if self.cloudKitStatus != "" {
                self.cloudKitStatus = "Apple sign in status: " + self.cloudKitStatus
                Util.app().reportError(class_type: type(of: self), context: self.cloudKitStatus, error: nil)
            }
        }
        return false
    }
    
    func saveContext () {
//        let context = persistentContainer.viewContext
//        if context.hasChanges {
//            do {
//                try context.save()
//            } catch {
//                // Replace this implementation with code to handle the error appropriately.
//                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//                let nserror = error as NSError
//                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
//            }
//        }
    }
    
    // Facebook
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
    }
    
}

