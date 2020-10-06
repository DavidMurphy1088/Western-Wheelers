import SwiftUI
import Combine
import os.log
import CloudKit

class JoinedRide : Identifiable {
    var level: String
    var desc: String
    var ride: Ride
    
    init (rideIn:Ride, lvl:String, descr: String) {
        self.ride = rideIn
        level = lvl
        desc = descr
    }
}

class JoinModel: ObservableObject {
    @Published var joinableRides:[JoinedRide] = []
    
    func rideColor(ride:Ride) -> Color {
        let status = ride.activeStatus()
        if status == Ride.ActiveStatus.RecentlyClosed {
            return Color .gray
        }
        else {
            if status == Ride.ActiveStatus.Active {
                return Color .green
            }
            else {
                return Color .black
            }
        }
    }
    
    func refresh(rideList:[Ride], joinedId:String?, joinedLvl:String?) -> Int {
        joinableRides = []
        var list:[JoinedRide] = []
        var selected = -1
        var index = 0
        for ride in rideList {
            let status = ride.activeStatus()
            if status == Ride.ActiveStatus.Active || status == Ride.ActiveStatus.UpComing {
                for level in ride.getLevels() {
                    list.append(JoinedRide(rideIn: ride, lvl: level, descr: ride.titleWithLevel(level: level)!))
                    if ride.rideId == joinedId && level == joinedLvl {
                        selected = index
                    }
                    index += 1
               }
            }
        }
        let res = self.joinableRides + list
        self.joinableRides = res
        return selected
    }
}

struct RideJoinView: View {
    @ObservedObject var model = UserModel.userModel
    @ObservedObject var joinModel = JoinModel()
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    @State var appearCount = 0
    @State var joinedRide:String?
    @State var joinedRideLevel:String?
    @State var selectedIndex:Int = -1
    
    func saveJoin(ride: JoinedRide?) {
        let user = User(user: UserModel.userModel.currentUser!)
        if let ride = ride {
            //let ride = self.joinModel.joinRides[index]
            user.joinedRideID = ride.ride.rideId
            user.joinedRideLevel = ride.level
            user.joinedRideDate = Date()
        }
        else {
            user.joinedRideID = nil
            user.joinedRideLevel = nil
            user.joinedRideDate = Date()
        }

        UserModel.userModel.setCurrentUser(user: user)
        user.saveProfile()
        //self.isPresented = false
        self.presentationMode.wrappedValue.dismiss()
    }
    
    func desc(ride: JoinedRide) -> String {
        return ride.desc
    }
    
    func listCount() -> Int {
        return joinModel.joinableRides.count
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

    var body: some View {
        GeometryReader { geometry in
            VStack {
                //Section {
                Spacer()
                Text("Select from the rides coming up").foregroundColor(Color .blue)
                Text("or already under way that you can join").foregroundColor(Color .blue)
                Form {
                    Picker(selection: Binding(           // << proxy binding
                                    get: {
                                        self.selectedIndex },
                                    set: { self.selectedIndex = $0
                                    })
                        , label: Text("Selected Ride")) {
                        ForEach(0 ..< listCount()) {
                            //Question Why this test required? - without get sporadic index out of range error :(
                            if $0 < joinModel.joinableRides.count {
                                Text(self.desc(ride: joinModel.joinableRides[$0])).tag($0)
                                    .foregroundColor(self.rideColor(ride: joinModel.joinableRides[$0].ride))
                            }
                        }
                    }
                }
                .background(Color.yellow)
                .frame(height: geometry.size.height * 0.25)
                Spacer()
                HStack {
                    Spacer()
                    if selectedIndex >= 0 {
                        Button(action: {
                            saveJoin(ride: joinModel.joinableRides[selectedIndex])
                        }) {
                            Text("Join Ride")
                        }
                    }
                    
                    if UserModel.userModel.currentUser?.joinedRideID != nil {
                        Spacer()
                        Button(action: {
                            //self.selectedIndex = -1
                            self.saveJoin(ride: nil)
                        }) {
                            Text("Leave Ride")
                        }
                    }
                    Spacer()
                }
                Spacer()
            }
        }

        .onAppear() {
            if appearCount == 0 {
                //this is called EVERY time the view appears, specifically - when returning from selecting an item in the picker
                let index = self.joinModel.refresh(rideList: Rides.instance().rides, joinedId: joinedRide, joinedLvl: joinedRideLevel)
                if selectedIndex < 0 {
                    selectedIndex = index
                }
                else {
                    //selectedIndex = 0
                }
            }
            appearCount += 1
        }

    }

}

