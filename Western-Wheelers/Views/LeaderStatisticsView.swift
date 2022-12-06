import SwiftUI
import Combine

struct LeaderStatisticsView: View {
    @ObservedObject var stats_model = LeadersStats.instance

    let len_name = CGFloat(130)
    let len_led = CGFloat(50)
    let len_coled = CGFloat(50)
    let len_total = CGFloat(50)
    let hilite = Color( .green)
    let is_showing = true
    
    //pretty sure this does not show the navigation bar title becuase no views can be navigated from it
    var body: some View {
        VStack {
            if stats_model.published_total_stats == 0 {
                VStack {
                    VStack {
                        ActivityIndicator().frame(width: 50, height: 50)
                    }.foregroundColor(Color.blue)
                }
            }
            else {
                VStack {
                    // title centered
                    Text("Leader Statistics").font(.title)//.foregroundColor(Color.blue)
                    Text("Year To Date")
                    Text("")

                    VStack (alignment: .leading) {
                        HStack {
                            Text("  ").frame(alignment: .leading)
                            Text("Leader name").frame(width: self.len_name, alignment: .leading)
                            Text("Led").frame(width: self.len_led, alignment: .trailing)
                            Text("Co-Led").frame(width: self.len_coled, alignment: .trailing)
                            Text("Total").frame(width: self.len_total, alignment: .trailing)
                        }.background(Color(red: 0.85, green: 0.85, blue: 0.85)).font(.footnote)
                        
                        if stats_model.published_sorted == 0 {
                            Text("Sorting ...").foregroundColor(Color.blue)
                        }
                        else {
                            HStack {
                                Text("  ").frame(alignment: .leading)
                                Button(action: {self.stats_model.sort(by_column: 1)}) {Image("col-sort-icon")}.frame(width: self.len_name, alignment:.leading)
                                Button(action: {self.stats_model.sort(by_column: 2)}) {Image("col-sort-icon")}.frame(width: self.len_led, alignment:.trailing)
                                Button(action: {self.stats_model.sort(by_column: 3)}) {Image("col-sort-icon")}.frame(width: self.len_coled, alignment: .trailing)
                                Button(action: {self.stats_model.sort(by_column: 4)}) {Image("col-sort-icon")}.frame(width: self.len_total, alignment: .trailing)
                            }.frame(height: 5, alignment: .leading)
                        }
        
                        
                        if LeadersStats.instance.published_total_stats == nil {
                            VStack {
                                ActivityIndicator().frame(width: 50, height: 50)
                            }.foregroundColor(Color.blue)
                        }
                        else {
                            List(LeadersStats.instance.stats_by_leader) {
                                rider in
                                    HStack {
                                        Text("\(rider.name_first ?? "") \(rider.name_last ?? "")").frame(width: self.len_name, alignment: .leading)
                                        Text("\(rider.total_led)").frame(width: self.len_led, alignment:.trailing)
                                        Text("\(rider.total_coled)").frame(width: self.len_coled, alignment:.trailing)
                                        Text("\(rider.total_rides)").frame(width: self.len_total, alignment:.trailing)
                                    }
                                }
                                //.font(.footnote)
                                .listStyle(PlainListStyle())
                        }
                    }
                }
            }
        }
        .onAppear() {
            if self.stats_model.stats_by_leader.count == 0 {
                // for some reason this init is called > 1
                self.stats_model.load_stats()
            }
        }

    }
}
