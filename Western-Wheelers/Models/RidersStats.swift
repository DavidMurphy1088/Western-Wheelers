import Foundation
import Combine

class RiderStats : Identifiable {
    var id = UUID()
    var name_first: String?
    var name_last: String?
    var total_miles = 0
    var total_rides = 0
    var feet_climbed = 0
    var feet_per_mile = 0
}

class RidersStats : ObservableObject {
    public static let instance = RidersStats();
    var stats_by_rider = [RiderStats]()
    var stats_loaded_notified:AnyCancellable? = nil
    let stats_loader = StatsLoader.instance
    
    @Published var published_total_stats: Int? = nil
    @Published var published_sorted: Int? = nil
    @Published var stats_for_me: [RiderStats]?

    func load_stats() {
        // called by loader when its done
        self.stats_loaded_notified = stats_loader.data_was_loaded.sink(receiveValue: { value in
            //self.pick_rider(search_name: Util.current_user().site_name_last)
            
            DispatchQueue.main.async {
                self.published_total_stats = self.stats_by_rider.count
                self.published_sorted = self.stats_by_rider.count
            }
        })
        StatsLoader.instance.load_stats()
    }
    
    func sort(by_column:Int) {
        DispatchQueue.main.async {
            self.published_sorted = 0
        }
        DispatchQueue.global().async {
            if by_column == 1 {
                self.stats_by_rider = self.stats_by_rider.sorted(by: { $0.name_last! < $1.name_last! })
            }
            if by_column == 2 {
                self.stats_by_rider = self.stats_by_rider.sorted(by: { $0.total_miles > $1.total_miles })
            }
            if by_column == 3 {
                self.stats_by_rider = self.stats_by_rider.sorted(by: { $0.total_rides > $1.total_rides })
            }
            if by_column == 4 {
                self.stats_by_rider = self.stats_by_rider.sorted(by: { $0.feet_climbed > $1.feet_climbed })
            }
            if by_column == 5 {
                self.stats_by_rider = self.stats_by_rider.sorted(by: { $0.feet_per_mile > $1.feet_per_mile })
            }
            DispatchQueue.main.async {
                self.published_sorted = self.stats_by_rider.count
            }
        }
    }
    
    func pickRider(name_last: String?, name_first: String?)  {
        if name_last == nil || name_first == nil {
            return
        }
        let name_last_upper = name_last!.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let name_first_upper = name_first!.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        for rider_stats in self.stats_by_rider {
            let last_rs = (rider_stats.name_last ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let first_rs = (rider_stats.name_first ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            if last_rs == name_last_upper && first_rs == name_first_upper {
                DispatchQueue.main.async {
                    self.stats_for_me = [RiderStats]()
                    self.stats_for_me!.append(rider_stats)
                }
                break
            }
        }
    }    
    
}
