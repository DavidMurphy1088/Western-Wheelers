import SwiftUI
import Foundation

struct RideSetView: View {
    @State var rides: [Ride]?
    @State var title: String?

    var level: RideLevel? = nil
    var search:String? = nil
    
    init (ride_level: RideLevel?, search_term: String?) {
        level = ride_level
        search = search_term
    }

    func getRides () {
        if let ride_level = level {
            rides = Rides.instance().getRidesByLevel(level: ride_level.name == "All" ? nil : ride_level.name)
            title = ride_level.name
        }
        else {
            if let search_term = search {
                rides = Rides.instance().getRidesByDescription(search_desc: search_term)
                title = search ?? ""
            }
            else {
                rides = Rides.instance().getRidesByLevel(level: nil)
                title = ""
            }
        }
    }
    
    func rideColor(ride:Ride) -> Color {
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
    
    func rideWeight(ride:Ride) -> Font.Weight {
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

    func rideList() -> [Ride]? {
        guard let ridesLoaded = self.rides else {
            return nil
        }
        var ridesToShow:[Ride] = []
        for ride in ridesLoaded {
            if ride.activeStatus() != Ride.ActiveStatus.Past && ride.activeStatus() != Ride.ActiveStatus.RecentlyClosed {
                ridesToShow.append(ride)
            }
        }
        return ridesToShow
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
            if self.rides != nil {
                List(self.rideList()!) {
                    ride in 
                    VStack {
                        NavigationLink(destination: RideWebView(model: WebViewModel(link: ride.rideUrl()))) {
                            VStack(alignment: HorizontalAlignment.leading) {
                                Text("\(ride.titleFull ?? "no title")")
                                    .font(.system(size: 18, weight: self.rideWeight(ride: ride), design: .default))
                                RideDetails(ride: ride)
                                if ride.activeStatus() == Ride.ActiveStatus.Active {
                                    Text("Ride is underway")
                                }
                            }
                            .font(.system(size: 14.0))
                            .foregroundColor(self.rideColor(ride: ride))
                        }
                    }
                }
            }
            else {
                Text("no rides")
            }
        }
        .onAppear() {
            self.getRides()
        }
        .padding()
    }
}
