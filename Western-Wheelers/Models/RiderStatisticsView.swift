import SwiftUI
import Combine

struct RiderStatisticsView: View {
    @ObservedObject var statsModel = RidersStats.instance
    
    let len_name = CGFloat(130)
    let len_miles_total = CGFloat(50)
    let len_rides_total = CGFloat(50)
    let len_feet_total = CGFloat(50)
    let len_feet_per = CGFloat(50)
    let is_showing = true
    
    var body: some View {
        VStack {
            if statsModel.published_total_stats == 0 {
                VStack {
                    ActivityIndicator().frame(width: 50, height: 50)
                }.foregroundColor(Color.blue)
            }
            else {
                VStack {
                    Text("Rider Statistics").font(.title)//.foregroundColor(Color.blue)
                    Text("Year To Date")

                    VStack (alignment: .leading) {
                        HStack {
                            Text(" ").frame(alignment: .leading)
                            Text("Rider name").frame(width: self.len_name, alignment: .leading)
                            Text("Miles").frame(width: self.len_miles_total)
                            Text("Rides").frame(width: self.len_rides_total)
                            Text("Climbed").frame(width: self.len_feet_total)
                            Text("Feet/Mile").frame(width: self.len_feet_per)
                        }.background(Color(red: 0.85, green: 0.85, blue: 0.85)).padding().font(.footnote)
                        
                        if statsModel.published_sorted == 0 {
                            Text("    ... sorting " + String(self.statsModel.published_total_stats ?? 0) + " riders ...").foregroundColor(Color.blue)
                        }
                        else {
                            HStack {
                                Text(" ").frame(alignment: .leading)
                                Button(action: {self.statsModel.sort(by_column: 1)}) {Image("col-sort-icon")}.frame(width: self.len_name, alignment:.leading)
                                Button(action: {self.statsModel.sort(by_column: 2)}) {Image("col-sort-icon")}.frame(width: self.len_miles_total, alignment:.trailing)
                                Button(action: {self.statsModel.sort(by_column: 3)}) {Image("col-sort-icon")}.frame(width: self.len_rides_total, alignment: .trailing)
                                Button(action: {self.statsModel.sort(by_column: 4)}) {Image("col-sort-icon")}.frame(width: self.len_feet_total, alignment: .trailing)
                                Button(action: {self.statsModel.sort(by_column: 5)}) {Image("col-sort-icon")}.frame(width: self.len_feet_per, alignment: .trailing)
                            }.frame(height: 5)
                        }
                        
                        if RidersStats.instance.stats_for_me == nil {
                            Text("      When you create your profile your stats show here").foregroundColor(Color .gray).font(.footnote)
                        }
                        else {
                            List(RidersStats.instance.stats_for_me!) {
                                rider in
                                Text("\(rider.name_first ?? "") \(rider.name_last ?? "")").frame(width: self.len_name, alignment: .leading)
                                Text("\(rider.total_miles)").frame(width: self.len_miles_total).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue, lineWidth: 1))
                                Text("\(rider.total_rides)").frame(width: self.len_rides_total).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue, lineWidth: 1))
                                Text("\(rider.feet_climbed)").frame(width: self.len_feet_total).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue, lineWidth: 1))
                                Text("\(rider.feet_per_mile)").frame(width: self.len_feet_per).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue, lineWidth: 1))
                            }.font(.footnote).frame(height: 40).border(Color.gray)
                        }
                    
                        if RidersStats.instance.published_total_stats == nil {
                            VStack {
                                ActivityIndicator().frame(width: 50, height: 50)
                            }.foregroundColor(Color.blue)
                        }
                        else {
                            List(RidersStats.instance.stats_by_rider) {
                                rider in
                                Text("\(rider.name_first ?? "") \(rider.name_last ?? "")").frame(width: self.len_name, alignment: .leading)
                                Text("\(rider.total_miles)").frame(width: self.len_miles_total)
                                Text("\(rider.total_rides)").frame(width: self.len_rides_total)
                                Text("\(rider.feet_climbed)").frame(width: self.len_feet_total)
                                Text("\(rider.feet_per_mile)").frame(width: self.len_feet_per)
                            }.font(.footnote)
                        }
                    }
                }
            }
        }
        .onAppear() {
            if self.statsModel.stats_by_rider.count == 0 {
                // for some reason this init is called > 1
                self.statsModel.load_stats()
            }
            if let user = UserModel.userModel.currentUser {
                self.statsModel.pickRider(name_last: user.nameLast, name_first: user.nameFirst)
            }
        }
        .onReceive(statsModel.$published_total_stats) { input in
            if let user = UserModel.userModel.currentUser {
                self.statsModel.pickRider(name_last: user.nameLast, name_first: user.nameFirst)
            }
        }
    }
}
