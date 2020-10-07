import Foundation
import Combine
import WebKit
import SwiftSoup

class LeaderStatsLoader: ObservableObject {
    public static let instance = LeaderStatsLoader();
    //var error_msg: String? = nil
    public let data_was_loaded = PassthroughSubject<Int?, Never>()
    
    func notifyObservers(count: Int? = nil, context: String? = nil) {
        // nil means not loaded to view, not nil is the number of rides and can be zero
        if (count != nil) {
            data_was_loaded.send(count!)
        } else {
            data_was_loaded.send(nil)
            Util.app().reportError(class_type: type(of: self), context: context ?? "")
        }
    }
    
    public func load_stats() {
        let fmt = DateFormatter()
        fmt.dateFormat = "yy"
        let year = fmt.string(from: Date())
        
        let url_str = "http://www.westernwheelers.org/main/stats/20\(year)/wwstat\(year)leader1.htm"

        let requestUrl = URL(string: url_str)
        var request = URLRequest(url: requestUrl!)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            
            if error != nil {
                self.notifyObservers(context: "Internet connection not available")
                return
            }
            
            // Read HTTP Response Status code
            if let response = response as? HTTPURLResponse {
                if response.statusCode != 200 {
                    self.notifyObservers(context: "Web site not available")
                    return
                }
            }
            
            // Convert HTTP Response Data to a simple String
            if let data = data, let _ = String(data: data, encoding: .utf8) {
                let http_str = String(data: data, encoding: .utf8)!
                var table_num = 0
                do {
                    let doc: Document = try SwiftSoup.parse(http_str)
                    for table in try! doc.select("table") {
                        table_num += 1
                        if (table_num == 1) {
                            for row in try! table.select("tr") {
                                var col_num = 0
                                let stats = LeaderStats()
                                for col in try! row.select("td") {
                                    let str = try? col.text()
                                    if str != nil {
                                        switch (col_num) {
                                        case 1: stats.name_first = str; break
                                        case 2: stats.name_last = str; break
                                        case 3: stats.total_led = Int(str!) ?? 0; break
                                        case 4: stats.total_coled = Int(str!) ?? 0; break
                                        case 5: stats.total_rides = Int(str!) ?? 0; break
                                        default: break
                                        }
                                    }
                                    col_num += 1
                                }
                                if stats.name_first !=  nil{ //} && RidersStats.instance.stats_by_rider.count < 5 {
                                    LeadersStats.instance.stats_by_leader.append(stats)
                                }
                            }
                        }
                    }
                    let count = LeadersStats.instance.stats_by_leader.count
                    if count > 0 {
                        self.notifyObservers(count: count)
                    }
                    else {
                        self.notifyObservers(context: "zero rows of leader stats")
                    }

                } catch Exception.Error( _, let message) {
                    self.notifyObservers(context: message)
                }
                catch {
                    self.notifyObservers(context: "Cannot load leader stats")
                }
            }
            else {
                self.notifyObservers(context: "Cannot parse leader stats html")
            }
        }
        task.resume()
    }
}
