import Foundation
import Combine

class LeaderStats : Identifiable {
    var id = UUID()
    var name_first: String?
    var name_last: String?
    
    var total_led = 0
    var total_coled = 0
    var total_rides = 0
}

class LeadersStats : ObservableObject {
    public static let instance = LeadersStats();
    var stats_by_leader = [LeaderStats]()
    var stats_loaded_notified:AnyCancellable? = nil
    let stats_loader = LeaderStatsLoader.instance
    @Published var published_total_stats: Int? = nil
    @Published var published_sorted: Int? = nil
    @Published var stats_for_me: [RiderStats]?

    func load_stats() {
        // called by loader when its done
        self.stats_loaded_notified = stats_loader.data_was_loaded.sink(receiveValue: { value in
            //self.pick_rider(search_name: Util.current_user().site_name_last)
            
            DispatchQueue.main.async {
                self.published_total_stats = self.stats_by_leader.count
                self.published_sorted = self.stats_by_leader.count
            }
        })
        LeaderStatsLoader.instance.loadStats(year_for_stats: Calendar.current.component(.year, from: Date()))
    }
    
    func sort(by_column:Int) {
        DispatchQueue.main.async {
            self.published_sorted = 0
        }
        DispatchQueue.global().async {
            if by_column == 1 {
                self.stats_by_leader = self.stats_by_leader.sorted(by: { $0.name_last! < $1.name_last! })
            }
            if by_column == 2 {
                self.stats_by_leader = self.stats_by_leader.sorted(by: { $0.total_led > $1.total_led })
            }
            if by_column == 3 {
                self.stats_by_leader = self.stats_by_leader.sorted(by: { $0.total_coled > $1.total_coled })
            }
            if by_column == 4 {
                self.stats_by_leader = self.stats_by_leader.sorted(by: { $0.total_rides > $1.total_rides })
            }
            DispatchQueue.main.async {
                self.published_sorted = self.stats_by_leader.count
            }
        }
    }
}
