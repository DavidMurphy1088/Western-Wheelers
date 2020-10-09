import Foundation
import Combine
import os.log

extension RidesLoader: XMLParserDelegate {

    func parserDidStartDocument(_ parser: XMLParser) {
        parse_level = 0
    }

    // start element
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        parse_level = parse_level + 1
        current_value = ""
        if elementName == "item" {
            current_ride = Ride()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        current_value? += string
    }

    // end element
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        parse_level = parse_level - 1
        
        if elementName == "pubDate" {
            if let new_ride = current_ride {
                // ww XML format = Sat, 09 May 2020 16:15:00 GMT
                if let date_str = current_value {
                    let p1 = date_str.firstIndex(of: " ")
                    let p2 = date_str.lastIndex(of: " ")
                    if let p3 = p1, let p4 = p2 {
                        let si = date_str.index(p3, offsetBy: 1)
                        let li = date_str.index(p4, offsetBy: 0)
                        let ds = date_str[si..<li]
                        let formatter = DateFormatter()
                        formatter.timeZone = TimeZone(secondsFromGMT: 0) // RSS dates are in UTC
                        formatter.dateFormat = "dd MMM yyyy HH:mm:ss"
                        formatter.timeZone = TimeZone(abbreviation: "UTC") // rides in ww XML are always UTC
                        new_ride.dateTime = formatter.date(from: String(ds))!
                     }
                }
            }
        }
        if elementName == "lastBuildDate" {
            last_build_date = current_value
        }
        
        if elementName == "guid" {
            if let new_ride = current_ride {
                if let ride_guid = current_value {
                    //new_ride.rideUrl = ride_guid
                    var ride_id = ""
                    var after = false
                    for ch in ride_guid {
                        if ch == "-" {
                            after = true
                            continue
                        }
                        if after {
                            ride_id += "\(ch)"
                        }
                    }
                    new_ride.rideId = ride_id
                }
            }
        }
        
        func validate_and_prepare_ride(ride: Ride) -> Bool {
            if ride.titleFull == nil {return false}
            if ride.url == nil {return false}
            //if ride.rideId == Ride.NOT_SET {return false}
            let title = ride.titleFull!
            let last_paren = title.range(of: "(", options: .backwards)?.lowerBound
            if last_paren == nil {
                return false
            }
            let title_str = title[..<last_paren!]
            ride.titleFull = String(title_str)
            
            // examples levels
            // B/4(4700’)/45; C/4(5000’)/52; D/4(7000’)/60
            // BCD/1/26
            // A/0/15
            // B/2/30-50
            // B/B+/2/30
            // C+/3/42
            // C/3/15 D/4/15
            
            //ride.titleShort = ""
            //ride.levels = Ride.parseLevels(ride.titleFull)

            let formatter = DateFormatter() // this formats the day,time according to users local timezone
            formatter.dateFormat = "EEEE MMM d"
            let rideDate = formatter.string(from: ride.dateTime)
            ride.rideId = rideDate + "-" + ride.rideId

            return true
        }
        
        if elementName == "item" {
            if let ride = current_ride {
                if validate_and_prepare_ride(ride: ride) {
                    let ride_added = false
//                    if ride.rideIsOpen() && !ride.rideHasEnded() {
//                        // make individual rides for an open ride so riders can join a specific level of the ride
//                        let levels = ride.levels.components(separatedBy: ",")
//                        if levels.count > 1 {
//                            for level in levels {
//                                let level_ride:Ride = ride.copyRide()
//                                level_ride.rideId = ride.rideId + ", " + level
//                                level_ride.rideIdDisplay = ride.rideIdDisplay + ", " + level
//                                level_ride.levels = level
//                                ride.wasRssLoaded = true
//                                Rides.rides().rides.append(level_ride)
//                                ride_added = true
//                            }
//                        }
//                    }
                    if !ride_added {
                        Rides.instance().rides.append(ride)
//                        if ride.rideIsOpen() && !ride.rideHasEnded() {
//                            //if the ride will soon end save it in cloud in case people want to join after it starts - at which time it wont load from RSS
//
//                            //let formatter = DateFormatter()
//                            //formatter.dateFormat = "yyyy MM dd HH:mm:ss"
//                            //let ss = formatter.string(from: ride.dateTime)
//                            let endTime = ride.dateTime.addingTimeInterval(Ride.MAX_RIDE_DURATION_HOURS * 60.0 * 60)
//                            //let ee = formatter.string(from: endTime)
//                            //let start = ride.dateTime.addingTimeInterval(Ride.MAX_RIDE_DURATION_HOURS * 24.0 * 60.0)
//                            let currentRide = RideCurrentInfo(id: ride.rideId, start:ride.dateTime, end: endTime, dateDisp: ride.dateDisp,
//                                                              url: ride.rideUrl ?? "", full: ride.titleFull ?? "", short:ride.titleShort() ?? "")
//                            currentRide.remoteAdd(completion: {id in
//                            })
//                        }
                    }
                }
            }
            current_ride = Ride()
        }

        if elementName == "title" {
            if let r = current_ride {
                r.titleFull = current_value
            }
        }
        if elementName == "link" {
            if let r = current_ride {
                r.url = current_value
            }
        }
        if elementName == "description" {
            if let r = current_ride {
                r.description_html = current_value
            }
        }
        current_value = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        Util.app().reportError(class_type: type(of: self), context: "XML parsing error", error: "parse error")
    }
}

class RidesLoader : NSObject {
    var current_value: String?
    var debug = false
    var parse_level: Int = 0
    var last_build_date: String? = nil
    var ride_guid: String? = nil
    var current_ride : Ride?
    static var first_ride = true

    func parseRides(xmlStr : String) {
        // fix their broken XML
        let xml_good = xmlStr.replacingOccurrences(of: "<description><p><br></p></description>", with: "<description><br></br></description>")
        let parser = XMLParser(data: Data(xml_good.utf8))
        parser.delegate = self as XMLParserDelegate
        parser.parse()
    }

    public func loadRides() {
        let requestUrl =  URL(string: "https://westernwheelersbicycleclub.memberlodge.com/ride_calendar/RSS")
        var request = URLRequest(url: requestUrl!)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if error == nil {
                // tell users = false. Better they get the more user friendly msg they have no internet from the ride view
                //self.notifyObservers(userMsg: "Error loading rides", error: error.localizedDescription, tellUsers: false)
                return
            }
            
            // Read HTTP Response Status code
            if let response = response as? HTTPURLResponse {
                if response.statusCode != 200 {
                    //self.notifyObservers(userMsg: "Web site not available \(response.statusCode)", error: "\(response)")
                    return
                }
            }
            
            // Convert HTTP Response Data to a simple String
            if let data = data, let _ = String(data: data, encoding: .utf8) {
                let xmlStr = String(data: data, encoding: .utf8)!
                self.parseRides(xmlStr: xmlStr)
                if Rides.instance().rides.count == 0 {
                    //self.notifyObservers(userMsg: "Cannot parse site RSS XML data", error: nil)
                }
                else {
                    //self.notifyObservers(count: Rides.instance().rides.count)
                }
            }
            else {
                //self.notifyObservers(userMsg: "Cannot load site RSS data")
            }
        }
        
        task.resume()
    }
}

