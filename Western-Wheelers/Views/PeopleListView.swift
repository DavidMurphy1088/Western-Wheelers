import SwiftUI
import UIKit
import Combine
import os.log
import CloudKit

class ProfileListModel : ObservableObject {
    static var model = ProfileListModel() //singleton
    
    //the list published to views
    @Published var profileList:[User]? // = []
    
    //subscribe to changes in the profile list
    //user may have saved or deleted their profile (which causes the model to reload all users. e.g to have the new profile show if the user added one profile)
    private var profileListSubscriber:AnyCancellable? = nil
    
    private var profiles:[User]? = nil
    private var searchTerm:String?
    private var searchRideId:String?
    private var searchRideLevel:String?
    private var refreshEnabled = false
    private var loadNum = 0
    
    let refreshQueue = DispatchQueue(label: "profile.loader")
    
    init () {
        //preload query to speed up Cloudkit. Its sometimes unusable slow for profiles
        //this query runs when app loads so before the view appears
        UserModel.userModel.loadAllUsers(warmup: true)
        
        //listen for profile changes
        self.profileListSubscriber = UserModel.userModel.userProfileListSubject.sink(receiveValue: { profilesSink in
            self.profiles = profilesSink
            self.filterUserList()
        })
        
        refreshQueue.async {
            let refreshMinutes = 5
            let refreshSeconds = refreshMinutes * 60
            while true {
                if self.refreshEnabled {
                    UserModel.userModel.loadAllUsers()
                    self.loadNum += 1
                }
                sleep(UInt32(refreshSeconds)) //dont remove sleep
            }
        }
    }
    
    func loadProfiles() {
        UserModel.userModel.loadAllUsers()
    }
    
    func enableRefresh(way:Bool) {
        self.refreshEnabled = way
    }
    
    func setFilter(searchTerm: String, searchRideId: String?, searchRideLevel:String?) {
        self.searchTerm = searchTerm
        self.searchRideId = searchRideId
        self.searchRideLevel = searchRideLevel
    }
    
    func clearRideFilter() {
        self.searchRideId = nil
        self.searchRideLevel = nil
        self.refreshEnabled = false
    }

    func filterUserList() {
        guard let profiles = self.profiles else {
            return
        }
        var filterList:[User] = []
        for user in profiles {
            if let searchId = searchRideId {
                if user.joinedRideID != searchId {
                    continue
                }
            }
            if let level = searchRideLevel {
                if user.joinedRideLevel != level {
                    continue
                }
            }

            var show = true
            if let term = searchTerm {
                if term != "" {
                    show = false
                    if (user.nameFirst?.uppercased().contains(term.uppercased()))! {
                        show = true
                    }
                    if (user.nameLast?.uppercased().contains(term.uppercased()))! {
                        show = true
                    }
                }
            }
            if show {
                filterList.append(user)
            }
        }
        DispatchQueue.main.async {
            self.profileList = filterList
        }
    }
}

struct PeopleListView: View {
    @ObservedObject var userModel = UserModel.userModel
    @ObservedObject var profileListModel = ProfileListModel.model
    @ObservedObject var app = Util.app()

    @State var searchTerm = ""
    @State var sheetError = false
    @State var sheetProfile = false
    @State var info = ""
    @State var infoShow = false
    @State var iCloudAlertShow = false
    @State var showWWSiginIn = false
    @State var showProfile = false
    @State var showJoinRide = false
    @State var onMyRide = false
    
    func rideTitle(id: String) -> String {
        for ride in Rides.instance().rides {
            if ride.rideId == id {
                return ride.titleWithoutLevels() ?? ""
            }
        }
        return ""
    }
    
    func userHasProfile() -> Bool {
        guard let user = UserModel.userModel.currentUser else {
            return false
        }
        return !((user.info == nil || user.info == "") && user.picture == nil)
    }
    
    var body: some View {
        // users not signed with Apple ID can read the Cloudkit List, i.e. no need to be signed in
        let searchBinding = Binding<String>(get: {
            self.searchTerm
        }, set: {
            self.searchTerm = $0
            profileListModel.setFilter(searchTerm: self.searchTerm,
                                     searchRideId: self.onMyRide ? UserModel.userModel.currentUser!.joinedRideID : nil,
                                     searchRideLevel: self.onMyRide ? UserModel.userModel.currentUser!.joinedRideLevel : nil)
            profileListModel.filterUserList()
        })

        let onMyRide = Binding<Bool>(get: {
            self.onMyRide
        }, set: {
            self.onMyRide = $0
            //get a fresh list of users on this ride, maybe people joined or left
            self.profileListModel.enableRefresh(way: self.onMyRide)
            profileListModel.setFilter(searchTerm: self.searchTerm,
                                     searchRideId: self.onMyRide ? UserModel.userModel.currentUser!.joinedRideID : nil,
                                     searchRideLevel: self.onMyRide ? UserModel.userModel.currentUser!.joinedRideLevel : nil)
            self.profileListModel.loadProfiles()
        })

        //must be navigation view to allow NAv links below to work
        return NavigationView {
            GeometryReader { geometry in
                VStack {
                    if self.profileListModel.profileList == nil  {
                        VStack {
                            ActivityIndicator().frame(width: 50, height: 50)
                        }.foregroundColor(Color.blue)
                    }
                    else {
                        if UserModel.userModel.currentUser?.joinedRideID != nil && UserModel.userModel.currentUser?.joinedRideID != "" {
                            Text("Your Ride").font(.footnote)
                            VStack {
                                Text("\(self.rideTitle(id: (UserModel.userModel.currentUser?.joinedRideID)!))")
                                Text("\(UserModel.userModel.currentUser?.joinedRideLevel ?? "") Ride")
                            }
                            .font(.footnote)
                            .frame(width: geometry.size.width * 0.9)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue, lineWidth: 1))
                        }
                        HStack {
                            Text("Search")
                            TextField("", text: searchBinding, onEditingChanged: {(editingChanged) in})
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: geometry.size.width * 0.5)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                            //.returnKeyType = .next
                        }
                        Toggle("On My Ride", isOn: onMyRide).disabled(
                            UserModel.userModel.currentUser == nil ||
                            UserModel.userModel.currentUser?.joinedRideID == nil ||
                            UserModel.userModel.currentUser!.joinedRideID == "")
                        .frame(width: geometry.size.width * 0.5)
                        
                        //sometimes the email search results come after the list results and so the current user show blank in the list - this attempts to fix that
                        List(self.profileListModel.profileList!, id: \.id) { user in
                        //ForEach(self.profileListModel.profileList!) { user in
                            if let recId = user.recordId {
                                NavigationLink(destination: PersonView(recordId: recId)) {
                                    Text("\(user.nameFirst ?? "") \(user.nameLast ?? "")")
                                }
                            }
                        }

                        HStack {
                            if UserModel.userModel.currentUser == nil {
                                //Spacer()
                                NavigationLink(destination: WWSignInView(isPresented: $showWWSiginIn), isActive: $showWWSiginIn) {
                                    Text("WW SignIn")
                                }
                            }

                            NavigationLink(destination: ProfileEditView(isPresented: $showProfile, onRideFilterOn: $onMyRide), isActive: $showProfile) {
                                Text("My Profile")
                            }
                            .padding()
                            .disabled(userModel.currentUser == nil)

                            NavigationLink(destination: RideJoinView(onRideFilterOn: $onMyRide, joinedRide: UserModel.userModel.currentUser?.joinedRideID,
                                                                     joinedRideLevel: UserModel.userModel.currentUser?.joinedRideLevel),
                                                                     isActive: $showJoinRide) {
                                Text("Join/Leave Ride")
                            }
                            .padding()
                            //only enabled if user has profile
                            .disabled(!self.userHasProfile())

                            Button(action: {
                                if !CloudKitManager.manager.canReadData() {
                                        self.iCloudAlertShow = true
                                }
                                else {
                                    self.infoShow = true
                                }
                            }) {
                                Image(systemName: "info.circle.fill").resizable().frame(width:30.0, height: 30.0)
                            }
                        }
                        .actionSheet(isPresented: self.$infoShow) {
                            return ActionSheet(
                                title: Text("Your Profile"),
                                message: Text("\(self.info)"),
                                buttons: [.cancel {},]
                            )
                        }
                        .alert(isPresented: self.$iCloudAlertShow) {
                            Alert(title: Text("Alert"), message: Text("To use this feature you need to sign in to your iCloud account. On the Home screen, launch Settings, tap iCloud, and enter your Apple ID. Turn iCloud Drive on. If you don't have an iCloud account, tap Create a new Apple ID."), dismissButton: .default(Text("Ok")))
                        }
                    }
                }
            }
            //.inline seems to create marginally less unwanted space on the target view, any other option ie. default or no nav title creates more unwanted space
            .navigationBarTitle("People", displayMode: .inline)
            //.navigationBarTitle("People")
            //.navigationBarHidden(true)
        }
            
        .onAppear() {
            // appears when view appears first time or when navigating from another tab. Therefore may be called > 1.
            // It is *NOT* called when a view navigated to from here returns.
            if let fileURL = Bundle.main.url(forResource: "doc_person_info", withExtension: "txt") {
                if let fileContents = try? String(contentsOf: fileURL) {
                    self.info = fileContents
                }
            }
            self.searchTerm = ""
            if let user = UserModel.userModel.currentUser {
                //do they have a profile?
                UserModel.userModel.searchUserByEmail(email: user.email!)
                // for some unfathomable reason the .onrec from the 1st has a userlist = nil (but the users coming back >0 users)
                //UserModel.userModel.searchUserByEmail(email: user.email!)
            }
            
            self.profileListModel.enableRefresh(way: self.onMyRide)
            // do it every time the view appears to get latest data
            self.profileListModel.loadProfiles()
        }
        
        .onDisappear {
            self.profileListModel.enableRefresh(way: false)
        }
        
        .onReceive(UserModel.userModel.$emailSearchUser) {user in
            // called when a user is returned from the email search => they have a profile when the view appeared
            // called with a nill user before this view navigates to the profile edit subview?
            if let user = user {
                // this record may have been fetched by another view. e.g. the person view
                if user.email == UserModel.userModel.currentUser?.email {
                    UserModel.userModel.setCurrentUser(user: user)
                }
            }
        }
        
        .onReceive(profileListModel.$profileList) {profiles in
            //user may have saved or deleted their profile (which causes the model to reload all users. e.g to have the new profile show if the user added one profile)
//            guard let users = profiles else {
//                return
//            }
            if !self.userHasProfile() {
                self.onMyRide = false
            }
//            var searchRideId:String? = nil
//            if self.onMyRide {
//                searchRideId = UserModel.userModel.currentUser?.joinedRideID
//            }
//            viewModel.filterUserList(userList: users, searchTerm: "", searchRideId: searchRideId, searchRideLevel: nil)
        }
                        
        .onReceive(app.$userMessage) {msg in
            if msg != nil {
                self.sheetError = true
            }
        }
        
    }
}

