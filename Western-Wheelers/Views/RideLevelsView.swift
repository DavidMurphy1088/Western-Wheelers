import SwiftUI
import Combine
import os.log

struct RideLevelsView: View {
    @State var searchValue: String = ""
    @State var showInfo = false
    @State var info = ""
    @State var searchActive: Bool
    
    let ride_levels = [RideLevel(label: "A"), RideLevel(label: "B"), RideLevel(label: "C"), RideLevel(label: "D"), RideLevel(label: "E"), RideLevel(label: "All")]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .center) {
                TextField("search", text: $searchValue, onEditingChanged: {_ in
                }, onCommit: {
                    if self.searchValue != "" {
                        self.searchActive = true
                    }
                }
                ).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 300) //, height: 50)
                //this nav link needs to be in the view for the onCommit
                NavigationLink(destination: RideSetView(ride_level: nil, search_term: self.searchValue), isActive: $searchActive) {
                    Text("Search Rides")
                }
                .hidden()
                .frame(width: 0, height: 0)

                List(ride_levels) {level in
                    NavigationLink(destination: RideSetView(ride_level: RideLevel(label: level.name), search_term: nil)) {
                       Text("\(level.name) Rides")
                    }
                }.padding()
                
                Button(action: {
                    self.showInfo = true
                }) {
                    Image(systemName: "info.circle.fill").resizable().frame(width:30.0, height: 30.0)
                }
                Spacer()
            }
            .navigationBarTitle("Ride Levels", displayMode: .inline)
            .actionSheet(isPresented: self.$showInfo) {
                ActionSheet(
                    title: Text("App Info"),
                    //message: Text(" ,
                    message: Text(self.info),
                    buttons: [
                        .cancel {  },
                    ]
                )
            }
            //hoping this would avoid the initial blank screen on iPad (as Stack Overlfow reccommneded) but it does not
            .navigationViewStyle(StackNavigationViewStyle())
        }
        .onAppear() {
            self.info = "Western Wheelers App Version "
            self.info += Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            self.info += ", Build:" + (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")
            if let rideCount = Rides.instance().publishedTotalRides {
                self.info += "\n\nRides loaded "+String(rideCount)
            }
            if RidersStats.instance.published_total_stats != nil {
                self.info += "\nRiders stats "+String(RidersStats.instance.published_total_stats!)
            }
            self.info += "\n\nThanks for using the Western Wheelers app and I hope you find it useful. Feel free to send any suggestions or new ideas to davidp.murphy@sbcglobal.net"
        }
        
    }
}
