import SwiftUI
import Foundation
import Combine

class RideSetModel : ObservableObject {
    static var model = RideSetModel()
    //update the view as rides change state - e.g. become underway or end
    @Published private(set) var rideSetList:[Ride]?
    private var loadedRides:[Ride]? = nil
    private var rideListSubscriber:AnyCancellable? = nil
    private var filterLevel:RideLevel?
    private var filterSearchTerm:String?
    
    init() {
        self.rideListSubscriber = Rides.instance().ridesListSubject.sink(receiveValue: { rides in
            self.loadedRides = rides
            self.filterRides()
        })
    }
    
    func setFilter(level:RideLevel?, searchTerm:String?) {
        self.filterLevel = level
        self.filterSearchTerm = searchTerm
        self.loadedRides = Rides.instance().rides
        self.filterRides()
    }
    
    func filterRides () {
        var rides:[Ride] = []
        if loadedRides != nil {
            for ride in loadedRides! {
                if let search = filterSearchTerm {
                    if ride.matchesSearchDescription(searchDesc: search) {
                        rides.append(ride)
                    }
                }
                else {
                    if filterLevel == nil || filterLevel!.name == "All" || ride.getLevels().contains(filterLevel!.name) {
                        rides.append(Ride(from: ride))
                    }
                }
            }
            DispatchQueue.main.async {
                self.rideSetList = rides
            }
        }
    }
}

struct RideSetView: View {
    @ObservedObject var ridesModel = RideSetModel.model
    @State var title: String?

    var level: RideLevel? = nil
    var search:String? = nil
    
    init (rideLevel: RideLevel?, searchTerm: String?) {
        level = rideLevel
        search = searchTerm
    }
    
    func rideFontColor(ride:Ride) -> Color {
        let status = ride.activeStatus()
        if status == Ride.ActiveStatus.RecentlyClosed {
            return Color .gray
        }
        else {
            if status == Ride.ActiveStatus.Active {
                return Color .blue
            }
            else {
                return Color .black
            }
        }
    }
    
    func rideFontWeight(ride:Ride) -> Font.Weight {
        let status = ride.activeStatus()
        if status == Ride.ActiveStatus.Active{
            return Font.Weight.semibold
        }
        else {
            if status == Ride.ActiveStatus.UpComing {
                return Font.Weight.semibold
            }
            else {
                return Font.Weight.regular
            }
        }
    }

    struct RideDetails: View {
        @State var ride:Ride
        var body: some View {
            HStack () {
                Text("\(ride.dateDisp())")
                Spacer()
                if ride.weatherDisp == nil {
                    if ride.activeStatus() == Ride.ActiveStatus.UpComing && ride.isEveningRide() {
                        Text(" Evening ").background(Color(red: 0.96, green:0.96, blue:0.96))
                    }
                }
                else {
                    ride.weatherDisp.map({
                        Text($0).italic().background(Color(red: 1.0, green:1.0, blue:0.8))
                    })
                }
            }

        }
    }
    
    var body: some View {
        VStack {
            if self.ridesModel.rideSetList != nil {
                List(self.ridesModel.rideSetList!) {
                    ride in 
                    VStack {
                        NavigationLink(destination: RideWebView(model: WebViewModel(link: ride.rideUrl()))) {
                            VStack(alignment: HorizontalAlignment.leading) {
                                Text("\(ride.titleFull ?? "no title")")
                                    .font(.system(size: 18, weight: self.rideFontWeight(ride: ride), design: .default))
                                RideDetails(ride: ride)
                                if ride.activeStatus() == Ride.ActiveStatus.Active {
                                    Text("Ride is underway")
                                }
                            }
                            .font(.system(size: 14.0))
                            .foregroundColor(self.rideFontColor(ride: ride))
                        }
                    }
                }
            }
            else {
                Text("no rides")
            }
        }
        .onAppear() {
            self.ridesModel.setFilter(level: self.level, searchTerm: self.search)
            if level == nil {
                self.title = ""
            }
            else {
                self.title = level!.name
            }
        }
        .padding()
    }
}
