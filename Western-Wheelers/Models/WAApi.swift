
import Foundation
import os.log

// Wild Apricot user

class WAApi : ObservableObject {
    @Published var errMsg: String! = nil

    static private var wwApi:WAApi! = nil
    private var WAUser:String
    private var WAPwd:String
    private var token: String! = nil
    private var nameLast:String? = nil
    private var nameFirst:String? = nil
    
    enum ApiType {
        case LoadRides, AuthenticateUser, None
    }
    var apiType = ApiType.None
    
    static func instance() -> WAApi {
        if WAApi.wwApi == nil {
            WAApi.wwApi = WAApi()
        }
        return WAApi.wwApi
    }
    
    init() {
        self.WAUser = Util.apiKey(key: "WA_username")
        //self.WAUser = "davidm@benetech.org"
        //self.WAUser = "sample@member.wa"
        let pwd = Util.apiKey(key: "WA_pwd")

        self.WAPwd = pwd+pwd+pwd
    }
    
    static func hexToStr(hex:String) -> String {
        let regex = try! NSRegularExpression(pattern: "(0x)?([0-9A-Fa-f]{2})", options: .caseInsensitive)
        let textNS = hex as NSString
        let matchesArray = regex.matches(in: textNS as String, options: [], range: NSMakeRange(0, textNS.length))
        let characters = matchesArray.map {
            Character(UnicodeScalar(UInt32(textNS.substring(with: $0.range(at: 2)), radix: 16)!)!)
        }
        return (String(characters))
    }
    
    func publishError(error:String) {
        DispatchQueue.main.async {
            self.errMsg = error
        }
    }
    
    func loadRides () {
        self.errMsg = nil
        let url = "https://oauth.wildapricot.org/auth/token"
        apiCall(path: url, withToken: false, usrMsg: "Loading Rides", completion: parseAccessToken, apiType: ApiType.LoadRides, tellUsers: true)
    }

    func authenticateUserFromWASite (user: String, pwd: String) {
        self.errMsg = nil
        self.WAUser = user
        self.WAPwd = pwd
        let url = "https://oauth.wildapricot.org/auth/token"
        // tellUsers: false view has custom message for failed authentication
        apiCall(path: url, withToken: false, usrMsg: "Authenticating Wild Apricot Account", completion: parseAccessToken, apiType: ApiType.AuthenticateUser, tellUsers: false)
    }
    
    func parseAccessToken(json: Any, raw: Any, apiType: ApiType, usrMsg:String, tellUsers:Bool) {
        if let data = json as? [String: Any] {
            if let tk = data["access_token"] as? String {
                self.token = tk
            }
            if let perms = data["Permissions"] as? [[String: Any]] {
                //for perm in perms {
                    let id = perms[0]["AccountId"] as! NSNumber
                    //let id = 123
                    var url = ""
                    if apiType == ApiType.LoadRides {
                        //url = "https://api.wildapricot.org/publicview/v1/accounts/\(id)/events"
                        // https://gethelp.wildapricot.com/en/articles/484
                        // https://gethelp.wildapricot.com/en/articles/180
                        // client id and client secret - https://davidpmurphy24414.wildapricot.org/admin/settings/integration/authorized-applications/
                        
                        //2020-Oct-28 WA finally acknowledged this is broken -
                        //A past date returns only future events. A future date shows all events after that date
                        
                        //A past date returns only future evetns. A future date shows all events after that date
                        //2020-Nov WA emailed saying this filter should now work
                        //2021-01-24 The date filter is still broken. Different filter dates appear to drop records that should be present.

                        //Feb 8 2021, they say V2 solves it but it gives 403 permission err. account does not have perm 'event_view'
                        //Feb 12 2021 - making the user account admin gives the account 'events_view' perms which is now required for V2
                        //Feb 17 2021 - WA said filter applies to series start date, not event start date. So set filter to 01Jan of current year and tell
                        //WW admins not to list ride series than span and end of year.

                        url = "https://api.wildapricot.org/v2/accounts/\(id)/events"
                        let formatter = DateFormatter()
                        
                        //let startDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
                        //The date must be Jan 01 of the current year.
                        //The date filter causes rides in a series to be filtered by the start of their ride series date, not the rride data
                        //formatter.dateFormat = "yyyy-MM-dd"
                        let startDate = Calendar.current.date(byAdding: .day, value: 0, to: Date())!
                        formatter.dateFormat = "yyyy-01-01"

                        let startDateStr = formatter.string(from: startDate)
                        print("API Filter date", startDateStr)
                        url = url + "?%24filter=StartDate%20gt%20\(startDateStr)"

                        apiCall(path: url, withToken: true, usrMsg: usrMsg, completion: parseRides, apiType: apiType, tellUsers: tellUsers)
                    }
                    if apiType == ApiType.AuthenticateUser {
                        url = "https://api.wildapricot.org/publicview/v1/accounts/\(id)/contacts/me"
                        apiCall(path: url, withToken: true, usrMsg: usrMsg, completion: parseUser, apiType: apiType, tellUsers: tellUsers)
                    }
                }
            //}
        }
    }
    
    func dateFromJSON(dateStr:String) -> Date {
        let index = dateStr.index(dateStr.startIndex, offsetBy: 16)
        let dateHHmm = String(dateStr[..<index])

        let LocalDateFormat = DateFormatter()
        LocalDateFormat.timeZone = TimeZone(secondsFromGMT: 0)
        LocalDateFormat.dateFormat = "yyyy-MM-dd'T'HH:mm"
        // if not specified this formatter's time zone is GMT
        //UTCDateFormat.timeZone = TimeZone(abbreviation: "")

        let InputDateFormat = DateFormatter()
        InputDateFormat.timeZone = TimeZone(secondsFromGMT: 0)
        InputDateFormat.dateFormat = "yyyy-MM-dd'T'HH:mm"
        // The app stores ride dates as expressed in UTC
        // However, the raw date string coming from the WA API is expressed in PDT time, so the input formatter needs to know to parse the raw date as being expressed in the PDT format
        // if not specified this formatter's time zone is GMT
        InputDateFormat.timeZone = TimeZone(abbreviation: "PDT") //

        let utcRideDate = InputDateFormat.date(from: String(dateHHmm))
        if let rideDate = utcRideDate {
            return rideDate
        }
        else {
            return Date(timeIntervalSince1970: 0)
        }
    }
    
    func parseRides(jsonData: Any, raw: Data, apiType: ApiType, usrMsg:String, tellUsers:Bool) {
        var rideList = [Ride]()
        
        if let events = try! JSONSerialization.jsonObject(with: raw, options: []) as? [String: Any] {

            //dict with one entry for 'events'
            for (_, val) in events {
                let rides = val as! NSArray
                for rideData in rides {
                    let rideDict = rideData as! NSDictionary
                    let ride = Ride()
                    ride.titleFull = ""
                    //some rides have an array of sessions. Each must be listed separately in the app
                    var sessions:[Ride] = []
                    for (attr, value) in rideDict {
                        let key = attr as! String
                        if key == "Name" {
                            let title = value as! String
                            ride.titleFull = title
                        }

                        if key == "StartDate" {
                            if let speced = rideDict["StartTimeSpecified"] {
                                let on = speced as! Int
                                if on == 0 {
                                    ride.timeWasSpecified = false
                                }
                            }
                            ride.dateTime = self.dateFromJSON(dateStr: value as! String)
                        }
                        if key == "Url" {
                            ride.url = value as? String
                        }
                        if key == "Sessions" {
                            let eventSessions = value as! NSArray
                            for sess in eventSessions {
                                let sessRide = Ride()
                                let sessionAttributes = sess as! NSDictionary
                                for (sAttr, sValue) in sessionAttributes {
                                    let skey = sAttr as! String
                                    if skey == "StartDate" {
                                        sessRide.dateTime = self.dateFromJSON(dateStr: sValue as! String)
                                    }
                                }
                                sessions.append(sessRide)
                            }
                        }
                        if key == "Id" {
                            ride.eventId = "\(value)"
                        }
                    }
                    if sessions.count > 0 {
                        var sessionNum = 0
                        for session in sessions {
                            session.titleFull = ride.titleFull
                            session.eventId = ride.eventId
                            session.sessionId = sessionNum
                            rideList.append(session)
                            sessionNum += 1
                        }
                    }
                    else {
                        rideList.append(ride)
                    }
                }
            }
        }
        print ("Rides count from API:", rideList.count)

        //debug api results ...
        if false {
            print ("===>raw (but sorted) ride list from API:", rideList.count)
            var index = 0
            let delta = 200
            let sortedRides = rideList.sorted(by: {
                $0.dateTime < $1.dateTime
            })
            for ride in sortedRides {
                if index < delta  || index > sortedRides.count-delta {
                    print (index, ride.dateTime, "url", ride.rideUrl())
                }
                index += 1
            }
        }
        
        var filteredRides:[Ride] = []
        for ride in rideList {
            if ride.activeStatus() != Ride.ActiveStatus.Past {//} && ride.activeStatus() != Ride.ActiveStatus.RecentlyClosed {
                filteredRides.append(ride)
            }
        }

        let sortedRides = filteredRides.sorted(by: {
            $0.dateTime < $1.dateTime
        })

        print ("Ride count after filter:", sortedRides.count, ", First event[", sortedRides[0].dateTime, "], Last event[", sortedRides[sortedRides.count-1].dateTime,"]")
        Rides.instance().setRideList(rideList: sortedRides)
    }

    func parseUser(jsonData: Any, raw: Data, apiType: ApiType, usrMsg:String, tellUsers:Bool) {
        var email: String? = nil
        var nameLast: String? = nil
        var nameFirst: String? = nil
        if let data = jsonData as? [String: Any] {
            if let data = data["Email"] {
                email = "\(data)"
            }
            if let data = data["LastName"] {
                nameLast = "\(data)"
            }
            if let data = data["FirstName"] {
                nameFirst = "\(data)"
            }
        }
        if let email = email {
            let user = User(email: email)
            //user.email = email
            user.nameFirst = nameFirst
            user.nameLast = nameLast
            user.saveLocalUserState()
            DispatchQueue.main.async {
                UserModel.userModel.setCurrentUser(user: user)
            }
        }
        else {
            Util.app().reportError(class_type: type(of: self), context: "cannot parse WA json user data")
        }
    }

    func apiCall(path: String, withToken:Bool, usrMsg:String, completion: @escaping (Any, Data, ApiType, String, Bool) -> (), apiType: ApiType, tellUsers:Bool) {
        let url = URL(string: path)
        var request = URLRequest(url: url!)

        if withToken {
            let tokenAuth = "Bearer \(token ?? "")"
            request.setValue(tokenAuth, forHTTPHeaderField: "Authorization")
        }
        else {
            //decoded test client_id:client_secret  = 7iodf6rtnq:8bhj038pmzv9fcvwqtg2931c1wixtv
            let testAuth = "Basic N2lvZGY2cnRucTo4YmhqMDM4cG16djlmY3Z3cXRnMjkzMWMxd2l4dHY="
            
            //decoded client_id:client_secret  = isey0jafp9:ec31t3uf9uuaakhzqpw5qlaaue1gi6
            let wwAuth = "Basic aXNleTBqYWZwOTplYzMxdDN1Zjl1dWFha2h6cXB3NXFsYWF1ZTFnaTY="
            
            request.setValue(wwAuth, forHTTPHeaderField: "Authorization")
            request.httpMethod = "POST"
            let postString = "grant_type=password&username=\(self.WAUser)&password=\(self.WAPwd)&scope=auto"
            request.httpBody = postString.data(using: String.Encoding.utf8);
        }
        
        let task = URLSession.shared.dataTask(with: request) { rawData, response, error in
            guard let rawData = rawData, let response = response as? HTTPURLResponse, error == nil else {
                let msg = usrMsg
                Util.app().reportError(class_type: type(of: self), context: msg, error: error?.localizedDescription)
                self.publishError(error: msg)
                return
            }
            guard (200 ... 299) ~= response.statusCode else {
                // check for http errors. 400 if authenctication fails
                var msg = ""
                if response.statusCode == 400 && apiType == ApiType.AuthenticateUser {
                    msg = "Please double check you are using the correct user and password for your WW account. (Status\(response.statusCode))"
                }
                else {
                    msg = "Unexpected Wild Apricot HTTP Status:\(response.statusCode)"
                }
                // failed user or pwd
                
                Util.app().reportError(class_type: type(of: self), context: msg, error: error?.localizedDescription)
                self.publishError(error: msg)
                return
            }
            do {
                if let jsonData = try JSONSerialization.jsonObject(with: rawData, options: []) as? [String: Any] {
//                    let str = String(decoding: rawData, as: UTF8.self)
//                    do {
//                        let path = URL(fileURLWithPath: "///Users/davidm")
//                        let filename = path.appendingPathComponent("output.txt")
//                        try str.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
//                    } catch {
//                    }
                    completion(jsonData, rawData, apiType, usrMsg, tellUsers)
                }
            } catch let error as NSError {
                let msg = "Cannot parse json"
                Util.app().reportError(class_type: type(of: self), context: msg, error: error.localizedDescription)
                self.publishError(error: msg)
            }
        }
        task.resume()
    }
}

