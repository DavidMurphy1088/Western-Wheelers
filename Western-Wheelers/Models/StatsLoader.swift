import Foundation
import Combine
import WebKit
import SwiftSoup

class StatsLoader: ObservableObject {
    public static let instance = StatsLoader();
    var error_msg: String? = nil
    static var first_ride = true
    public let data_was_loaded = PassthroughSubject<Int?, Never>()
    
    func notifyObservers(count: Int? = nil, userMsg: String? = nil, error: String? = nil, tellUsers:Bool = false) {
        if count != nil {
            data_was_loaded.send(count!)
        }
        else {
            data_was_loaded.send(nil)
            self.error_msg = userMsg
            Util.app().reportError(class_type: type(of: self), usrMsg: userMsg, error: error, tellUsers: tellUsers)
        }
    }
    
    public func load_stats() {
        let fmt = DateFormatter()
        fmt.dateFormat = "yy"
        let year = fmt.string(from: Date())
        let url_str = "http://www.westernwheelers.org/main/stats/20\(year)/wwstat\(year).htm"

        let requestUrl = URL(string: url_str)
        var request = URLRequest(url: requestUrl!)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            
            if error != nil {
                self.notifyObservers(userMsg: "Internet connection not available", error: "\(String(describing: error))", tellUsers: true)
                return
            }
            
            if let response = response as? HTTPURLResponse {
                if response.statusCode != 200 {
                    self.notifyObservers(userMsg: "Web site not available")
                    return
                }
            }
            
            if let data = data, let _ = String(data: data, encoding: .utf8) {
                let http_str = String(data: data, encoding: .utf8)!
                var table_num = 0
                do {
                    let doc: Document = try SwiftSoup.parse(http_str)
                    for table in try! doc.select("table") {
                        table_num += 1
                        if (table_num == 2) {
                            for row in try! table.select("tr") {
                                var col_num = 0
                                let stats = RiderStats()
                                for col in try! row.select("td") {
                                    let str = try? col.text()
                                    if str != nil {
                                        switch (col_num) {
                                        case 1: stats.name_first = str; break
                                        case 2: stats.name_last = str; break
                                        case 3: stats.total_miles = Int(str!) ?? 0; break
                                        case 4: stats.total_rides = Int(str!) ?? 0; break
                                        case 5: stats.feet_climbed = Int(str!) ?? 0; break
                                        case 7: stats.feet_per_mile = Int(str!) ?? 0; break
                                        default: break
                                        }
                                    }
                                    col_num += 1
                                }
                                if stats.name_first !=  nil{ //} && RidersStats.instance.stats_by_rider.count < 5 {
                                    RidersStats.instance.stats_by_rider.append(stats)
                                }
                            }
                        }
                    }
                    let count = RidersStats.instance.stats_by_rider.count
                    if count > 0 {
                        self.notifyObservers(count: count, userMsg: nil)
                    }
                    else {
                        let msg = "zero rows of rider stats"
                        self.notifyObservers(count: nil, userMsg: msg)
                    }

                } catch Exception.Error( _, _) {
                    self.notifyObservers(count: nil, userMsg: "Cannot load stats data")
                }
                catch {
                    self.notifyObservers(count: nil, userMsg: "cannot parse stats html")
                }
            }
            else {
                self.notifyObservers(userMsg: "cannot parse html")
            }
        }
        task.resume()
    }
}
