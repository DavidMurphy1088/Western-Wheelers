import Foundation
import UIKit
import CloudKit
import CoreLocation
import os.log

class Util {
    static var appDelegate: AppDelegate? = nil
    
    static func app() -> AppDelegate {
        //Thread 2: UIApplication.delegate must be used from main thread only
        //return UIApplication.shared.delegate as! AppDelegate *** BAD
        return Util.appDelegate!
    }

    static func apiKey(key:String) -> String {
        let path = Bundle.main.path(forResource: "api_keys.txt", ofType: nil)!
        do {
            let fileData = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
            let dict = try JSONSerialization.jsonObject(with: fileData.data(using: .utf8)!, options: []) as? [String:String]
            return dict?[key] ?? ""
        } catch {
            return ""
        }
    }
    
//    static func ql_date(date: Date?) -> String! {
//        guard let date = date else {
//            return nil
//        }
//        // graphQL formatted date
//        let formatter = DateFormatter()
//        formatter.timeZone = TimeZone(secondsFromGMT: 0) // RSS dates are in UTC
//        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
//        return formatter.string(from: date)
//    }
    
    static func formatDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // RSS dates are in UTC
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.timeZone = TimeZone(abbreviation: "PDT")
        let day_date_pdt = formatter.string(from: date)
        return  "PDT:\(day_date_pdt)" //"  gmt:\(day_date_gmt)"
    }
    
    static func formatTime(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // RSS dates are in UTC
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "PDT")
        let day_date_pdt = formatter.string(from: date)
        return  "PDT:\(day_date_pdt)"
    }


}
