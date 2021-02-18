import Foundation
import Combine
import WebKit
import SwiftSoup

class StatsLoader: ObservableObject {
    public static let instance = StatsLoader();
    //var error_msg: String? = nil
    static var first_ride = true
    public let data_was_loaded = PassthroughSubject<Int?, Never>()
    
    func notifyObservers(count: Int? = nil, context: String, error: String? = nil) { //}, informUsers: Bool = false) {
        if count != nil {
            data_was_loaded.send(count!)
        }
        else {
            data_was_loaded.send(nil)
            //self.error_msg = userMsg
            Util.app().reportError(class_type: type(of: self), context: context, error: error) //, tellUsers: informUsers)
        }
    }
    
    public func loadStats(year_for_stats: Int) {
        let fmt = DateFormatter()
        fmt.dateFormat = "yy"
        
    // look back to previous year if no stats for this year yet
        //let year = fmt.string(from: Date())
        let year_century_str = String(year_for_stats)
        let year_str = String(year_century_str.suffix(2))

        //let url_str = "http://www.westernwheelers.org/main/stats/20\(year_str)/wwstat\(year_str).htm"
        let url_str = "http://www.westernwheelers.org/main/stats/\(year_century_str)/wwstat\(year_str).htm"
        let requestUrl = URL(string: url_str)
        var request = URLRequest(url: requestUrl!)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            
            if error != nil {
                self.notifyObservers(context: "Internet connection not available", error: "\(String(describing: error))")
                return
            }
            
            if let response = response as? HTTPURLResponse {
                let status = response.statusCode
                if status != 200 {
                    self.notifyObservers(context: "Stats web site not available")
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
                        self.notifyObservers(count: count, context: "load stats", error: nil)
                    }
                    else {
                        if (year_for_stats == Calendar.current.component(.year, from: Date())) {
                            self.loadStats(year_for_stats: year_for_stats-1)
                        }
                        else {
                            let msg = "zero rows of rider stats"
                            self.notifyObservers(count: nil, context: msg)
                        }
                    }

                } catch Exception.Error( _, _) {
                    self.notifyObservers(count: nil, context: "Cannot load stats data")
                }
                catch {
                    self.notifyObservers(count: nil, context: "cannot parse stats html")
                }
            }
            else {
                self.notifyObservers(context: "cannot parse html")
            }
        }
        task.resume()
    }
}
