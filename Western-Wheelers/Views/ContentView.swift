import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var ridesModel = Rides.instance()
    @ObservedObject var app = Util.app()
    @State private var errShowing = false
    @State var searchActive = false
    
    init () {
        ridesModel.loadRides()
    }

    var contents: some View {
        TabView {

//            TestView().tabItem { VStack {
//                Text("Rides")
//                Image("tab-icon-bike")
//            }}//.padding().tag(1)

            RideLevelsView(searchActive: searchActive).tabItem { VStack {
                Text("Rides")
                Image("tab-icon-bike")
            }}//.padding().tag(1)
            
            PeopleListView()
            .tabItem { VStack {
                Text("People")
                Image("tab-icon-people")
                }}//.padding().tag(1)
            
//            TestView().tabItem { VStack {
//                Text("Rider Stats")
//                Image("tab-icon-stats")
//            }}//.padding().tag(2)
            
            RiderStatisticsView().tabItem { VStack {
                Text("Rider Stats")
                Image("tab-icon-stats")
            }}//.padding().tag(2)

            QuizView().tabItem { VStack {
                Text("Game")
                Image("tab-icon-quiz")
                }}//.padding().tag(3)

            LeaderStatisticsView().tabItem { VStack {
                Text("Leader Stats")
                Image("tab-icon-leader-stats")
            }}//.padding().tag(4)
         }
    }

    var body: some View {
        ZStack {
            if ridesModel.publishedTotalRides == nil {
                VStack {
                    ActivityIndicator().frame(width: 50, height: 50)
                }.foregroundColor(Color.blue)
            }
            else {
                if ridesModel.publishedTotalRides ?? -1 >= 0 {
                    contents
                }
                else {
                    VStack {
                        Text("Sorry, cannot load any rides.")
                        Text("Maybe you have no internet connection?")
                        Image(systemName: "wifi.exclamationmark").resizable().frame(width:60.0, height: 60.0)
                    }
                }
            }
        }
        .onReceive(app.$userMessage) {msg in
            if msg != nil {
                self.errShowing = true
            }
        }
        .sheet(isPresented: self.$errShowing) {
            Button(action: {
                self.app.clearError()
                self.errShowing.toggle()
            }) {
                VStack {
                    Text("An unexpected error occured").font(.headline)
                    Text("Please restart the app and/or check your internet connection").font(Font .footnote).foregroundColor(Color .black)
                    Text("")
                    Text("\(Util.app().userMessage ?? "")").font(Font .footnote).foregroundColor(Color .black)
                    Text("OK")
                }
            }
        }
    }

}


