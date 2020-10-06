
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
    //TEST11
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
                for perm in perms {
                    let id = perm["AccountId"] as! NSNumber
                    //let url = "https://api.wildapricot.org/publicview/v1/accounts/\(id)/contacts/me"
                    //let url = "https://api.wildapricot.org/v2.2/accounts/\(id)/events" //?%24async=true"
                    //let url = "https://api.wildapricot.org/v2.2/accounts/41275/events?%24async=true"
                    //let url = "https://api.wildapricot.org/publicview/v1/accounts/41275/eventregistrations"
                    //let url = "https://api.wildapricot.org/publicview/v1/accounts/41275/contactfields"
                    //url = "https://api.wildapricot.org/v2.2/accounts/\(id)/events"
                    var url = ""
                    if apiType == ApiType.LoadRides {
                        // FROM their support https://api.wildapricot.org/v2.1/accounts/{ACCOUNT_ID}/contacts?$async=false&$filter='Membership level ID' eq {LEVEL_ID}
                        // from Swagger https://api.wildapricot.org/publicview/v1/accounts/41275/events?%24filter=%24filter%3DIsUpcoming%20eq%20false

                        //url = "https://api.wildapricot.org/publicview/v1/accounts/41275/events?%24filter=%24filter%3DIsUpcoming%20eq%20false"
                        //url = "https://api.wildapricot.org/publicview/v1/accounts/\(id)/events" //?%24filter=%24filter%3DIsUpcoming%20eq%20false"
                        url = "https://api.wildapricot.org/publicview/v1/accounts/\(id)/events" //?%24filter=%24filter%3DStartDate%20gt%202016-011-02"
                        apiCall(path: url, withToken: true, usrMsg: usrMsg, completion: parseRides, apiType: apiType, tellUsers: tellUsers)
                    }
                    if apiType == ApiType.AuthenticateUser {
                        url = "https://api.wildapricot.org/publicview/v1/accounts/\(id)/contacts/me"
                        apiCall(path: url, withToken: true, usrMsg: usrMsg, completion: parseUser, apiType: apiType, tellUsers: tellUsers)
                    }
                }
            }
        }
    }
    
    func dateFromJSON(dateStr:String, debug:Bool=false) -> Date {
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
        var debug = false
        
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
                        debug = ride.titleFull!.contains("HAMILTON")

                        if key == "Name" {
                            let title = value as! String
                            ride.titleFull = title
                        }
                        if key == "StartDate" {
                            ride.dateTime = self.dateFromJSON(dateStr: value as! String, debug: debug)
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
                            ride.rideId = "\(value)"
                        }
                    }
                    if sessions.count > 0 {
                        var sessionNum = 0
                        for session in sessions {
                            session.titleFull = ride.titleFull
                            session.rideId = "\(ride.rideId)-\(sessionNum)"
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
        
        var filteredRides:[Ride] = []
        for ride in rideList {
            if ride.activeStatus() != Ride.ActiveStatus.Past {
                filteredRides.append(ride)
            }
        }
        
        if false {
            //let testRide = Ride()
//            let startDate = Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
//            testRide.dateTime = startDate
//            testRide.titleFull="BCD/1/26 TEST ACTIVE RIDE ONLY"
//            testRide.rideId = "10000"
//            filteredRides.append(testRide)
            
            let testRide = Ride()
            let startDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date())!
            testRide.dateTime = startDate
            testRide.titleFull="CD/1/36 TEST UPCOMING RIDE ONLY"
            testRide.rideId = "10001"
            filteredRides.append(testRide)
        }

        let sortedRides = filteredRides.sorted(by: {
            $0.dateTime < $1.dateTime
        })
        Rides.instance().setRideList(ridesLoaded: sortedRides)
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
            Util.app().reportError(class_type: type(of: self), usrMsg: "cannot parse json user data")
        }
    }

    func apiCall(path: String, withToken:Bool, usrMsg:String, completion: @escaping (Any, Data, ApiType, String, Bool) -> (), apiType: ApiType, tellUsers:Bool) {
    //func apiCall(path: String, with_token:Bool, completion: @escaping (Data) -> ()) {
        //self.errorMsg = nil
        let url = URL(string: path)
        var request = URLRequest(url: url!)

        if withToken {
            request.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        }
        else {
            let auth = "Basic aXNleTBqYWZwOTplYzMxdDN1Zjl1dWFha2h6cXB3NXFsYWF1ZTFnaTY="
            request.setValue(auth, forHTTPHeaderField: "Authorization")
            request.httpMethod = "POST"
            let postString = "grant_type=password&username=\(self.WAUser)&password=\(self.WAPwd)&scope=auto"
            request.httpBody = postString.data(using: String.Encoding.utf8);
        }
        
        let task = URLSession.shared.dataTask(with: request) { rawData, response, error in
            guard let rawData = rawData, let response = response as? HTTPURLResponse, error == nil else {
                let msg = usrMsg
                Util.app().reportError(class_type: type(of: self), usrMsg: msg, error: error?.localizedDescription)
                self.publishError(error: msg)
                return
            }
            guard (200 ... 299) ~= response.statusCode else {
                // check for http errors. 400 if authenctication fails
                let msg = "Unexpected Wild Apricot HTTP Status:\(response.statusCode)"
                // failed user or pwd
                Util.app().reportError(class_type: type(of: self), usrMsg: msg, error: error?.localizedDescription, tellUsers: tellUsers)
                self.publishError(error: msg)
                return
            }
            do {
                if let jsonData = try JSONSerialization.jsonObject(with: rawData, options: []) as? [String: Any] {
                    completion(jsonData, rawData, apiType, usrMsg, tellUsers)
                }
            } catch let error as NSError {
                let msg = "Cannot parse json"
                Util.app().reportError(class_type: type(of: self), usrMsg: msg, error: error.localizedDescription)
                self.publishError(error: msg)
            }
        }
        task.resume()
    }
}
