import Foundation
import SwiftUI
import SwiftSoup
import os.log

class Ride : Identifiable, Equatable, ObservableObject  {
    //static let MAX_RIDE_DURATION_HOURS = 12.0 // (12.0 * 60.0 * 60.0) // hours after which ride is considered ended, 7 hrs
    static let EARLIEST_JOIN_HOURS = 24.0 //  number of hours before ride start when a rider can join
    static let DAYS_HILIGHTED_AS_NEARBY = 24.0 //  number of hours before ride start when a rider can join
    static let LONGEST_RIDE_IN_HOURS = 8.0 //asume max ride length of 8 hrs
    
    //Can't be optional. Loaded from the WA API. For events 'series' the Wild Apricot id is the same for each instance of the event.
    //So for event uniqueness with event series instances, the rideID is the 'event ID' + the instance number. e.g. event = 12345, instance 15 the id is 12345-15
    //For a ride not in a series the instance number is omitted. e.g. 12345
    var eventId: String = ""
    var sessionId: Int = 0

    @Published var htmlDetailWasLoaded = false // true => ride details were loaded from the WW site

    var dateTime: Date = Date()          // ride must have date and this date is always GMT. This date is the ride date AND start time
    var url: String?
    var titleFull: String?
    var weatherDisp: String? = nil
    var rideWithGpsLink: String? = nil
        
    enum ActiveStatus {
        case Past, RecentlyClosed, Active, UpComing, Future
    }
    
    init () {
    }

    init (from:Ride) {
        self.eventId = from.eventId
        self.sessionId = from.sessionId
        self.htmlDetailWasLoaded = from.htmlDetailWasLoaded
        self.dateTime = from.dateTime
        self.url = from.url
        self.titleFull = from.titleFull
        self.weatherDisp = from.weatherDisp
        self.rideWithGpsLink = from.rideWithGpsLink
    }
    
    func activeStatus() -> ActiveStatus {
        let seconds = Date().timeIntervalSince(self.dateTime) // > 0 => ride start in past
        let minutes = seconds / 60.0
        let startHours = minutes / 60
        let endHours = startHours - Ride.LONGEST_RIDE_IN_HOURS
        
        if endHours > 16.0 {
            return ActiveStatus.Past
        }
        else {
            if endHours > 0 {
                return ActiveStatus.RecentlyClosed
            }
            else {
                if startHours > 0 {
                    return ActiveStatus.Active
                }
                else {
                    if abs(startHours) < 24.0 {
                        return ActiveStatus.UpComing
                    }
                    else {
                        return ActiveStatus.Future
                    }
                }
            }
        }
    }

    func rideUrl() -> String {
        let url = "https://westernwheelersbicycleclub.wildapricot.org/event-\(eventId)"
        return url
    }
    
    func titleWithoutLevels() -> String? {
        guard let titleFull = titleFull else {
            return nil
        }
        var title = ""
        let words = titleFull.components(separatedBy: " ")
        for word in words {
            if !wordIsLevels(word: word) {
                title += word + " "
            }
        }
        return title
    }
    
    func titleWithLevel(level:String, maxLen: Int = 20) -> String? {
        guard var title = titleWithoutLevels() else {
            return nil
        }
        if maxLen > 0 && title.count > maxLen {
            let index = title.index(title.startIndex, offsetBy: maxLen)
            title = String(title[..<index])
        }
        return "\(level) Ride, \(title)\n\(self.dateDisp())" 
    }

    func dateDisp() -> String {
        let formatter = DateFormatter() // this formats the day,time according to users local timezone
        formatter.dateFormat = "EEEE MMM d"
        let dayDisp = formatter.string(from: self.dateTime)
        
        // force 12-hour format even if they have 24 hour set on phone
        let timeFmt = "h:mm a"
        formatter.setLocalizedDateFormatFromTemplate(timeFmt)
        formatter.dateFormat = timeFmt
        formatter.locale = Locale(identifier: "en_US")
        let timeDisp = formatter.string(from: self.dateTime)
        return dayDisp + ", " + timeDisp
    }
    
    func startHour() -> Int {
        let formatter = DateFormatter() // this formats the day,time according to users local timezone
        formatter.dateFormat = "HH"
        let timeDisp = formatter.string(from: self.dateTime)
        return Int(timeDisp)!
    }
    
    func isEveningRide() -> Bool {
        return startHour() >= 16
    }

    static func == (lhs: Ride, rhs: Ride) -> Bool {
        return lhs.id == rhs.id
    }
    
    class HTMLLinkedObject {
        var name = ""
        var url = ""
        var type = ""
        var id = 0
        init(type_in: String, name_in: String, url_in: String) {
            name = name_in
            url = url_in
            type = type_in
        }
    }
    
    func htmlLoad() {
        if htmlDetailWasLoaded {
            return
        }
        DispatchQueue.global().async {
            self.htmlParse()
        }
    }
    
    func htmlAnalyse() {
        DispatchQueue.main.async { // publishing cannot come from background thread
            self.htmlDetailWasLoaded = true
        }
    }

    public func htmlParse() {
        let requestUrl = URL(string: "")
        var request = URLRequest(url: requestUrl!)
        request.httpMethod = "GET"

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                Util.app().reportError(class_type: type(of: self), context: "Cannot parse rides HTML", error: "\(error)")
                return
            }
            
            // Read HTTP Response Status code
            if let response = response as? HTTPURLResponse {
                if response.statusCode != 200 {
                    Util.app().reportError(class_type: type(of: self), context: "Bad HTTP response \(response.statusCode)", error: "\(response.statusCode)")
                    return
                }
            }
            
            // Convert HTTP Response Data to a simple String
            if let data = data, let _ = String(data: data, encoding: .utf8) {
                //https://www.w3schools.com/cssref/css_selectors.asp
                //https://swiftsoup.herokuapp.com/
                let http_str = String(data: data, encoding: .utf8)!

                // parse through Wild Apricot stuff
                
                do {
                    //let doc: Document = try SwiftSoup.parse(http_str)
                    let doc: Document = try SwiftSoup.parseBodyFragment(http_str)
                    let doc_body = doc.body()
                    //let info_header: Elements? = try! doc_body!.select(".boxBodyInfoOuterContainer")
                    let body: Elements = try! doc_body!.select(".boxBodyContentOuterContainer")
                    if body.count > 0 {
                        let inner: Elements = try! body.select(".inner")
                        if inner.count > 0 {
                            let paras: Elements = try! inner.select("p")
                            if paras.count > 0 {
                                //self.html_info(paragraphs: paras)
                                //self.html_analyse()
                            }
                        }
                    }

                } catch Exception.Error(_, _) {
                    Util.app().reportError(class_type: type(of: self), context: "Cannot parse rides HTML data")
                }
                catch {
                    Util.app().reportError(class_type: type(of: self), context: "cannot parse html")
                }
            }
            else {
                let msg = "cannot parse html"
                Util.app().reportError(class_type: type(of: self), context: "No ride HTML data", error: msg)
            }
            
            self.htmlAnalyse()
        }
        task.resume()
    }

    // find any useful, identifiable data in the ride listing
//    func html_info(paragraphs: Elements) {
//        do {
//            let filter = "a[href]" // links with an href
//            let links:Elements = try! paragraphs.select(filter)
//            for link in links {
//                let href = try link.attr("href")
//                var type = "link"
//                if href.lowercased().contains("mailto:") {
//                    type = "mail"
//                }
//                let obj = HTMLLinkedObject(type_in: type, name_in: try link.text(), url_in: href)
//                //self.htmlLinkableObs.append(obj)
//            }
//        } catch Exception.Error( _, let message) {
//            Util.app().reportError(class_type: type(of: self), usrMsg: "Cannot parse ride", error: message)
//        }
//        catch {
//            Util.app().reportError(class_type: type(of: self), usrMsg: "Cannot parse ride")
//        }
//    }
    

    func wordIsLevels(word: String) -> Bool{
        let wordParts = word.components(separatedBy: "/")
        var wordIsLevels = false
        if wordParts.count > 1 {
            var part_num = 0
            for wordPart in wordParts {
                if part_num > 0 {
                    let first_char = wordPart.prefix(1)
                    if first_char >= "0" && first_char <= "9" {
                        wordIsLevels = true
                        break
                    }
                }
                part_num += 1
            }
        }
        return wordIsLevels
    }
    
    func getLevels() -> [String] {
        var levels:[String] = []
        guard let titleFull = titleFull else {
            return levels
        }
        let words = titleFull.components(separatedBy: " ")
        
        // parse ride levels
        for word in words {
            //must be a word with at least one '/' where the first character of some part is numeric
            if wordIsLevels(word: word) {
                let wordParts = word.components(separatedBy: "/")
                for wordPart in wordParts {
                    var partIsLevels = true
                    for char in wordPart {
                        if (char < "A" || char > "E") {
                            if (char != "+" && char != "-") {
                                partIsLevels = false
                                break
                            }
                        }
                    }
                    if !partIsLevels {
                        continue
                    }

                    for char in wordPart {

                        if char >= "A" && char <= "E" {
                            levels.append(String(char))
                        }
                    }
                }
            }
        }
        return levels
    }
    
    func matchesSearchDescription(searchDesc: String) -> Bool {
        let search = searchDesc.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if var title = titleFull {
            title = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if title.contains(search) {
                return true
            }
        }
        return false
    }

}

