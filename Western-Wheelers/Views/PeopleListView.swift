import SwiftUI
import UIKit
import Combine
import os.log
//import FBSDKLoginKit
//import FBSDKShareKit
//import FBSDKCoreKit
import CloudKit

class PeopleListModel : ObservableObject {
    static var model = PeopleListModel() //singleton
    @Published var viewUserList:[User] = []
    
    init () {
        //preload query to speed up Cloudkit. Its sometimes unusable slow for profiles
        //this query runs when app loads so before the view appears
        UserModel.userModel.loadAllUsers(warmup: true)
    }
    
    func filterUserList(userList: [User], searchTerm: String, searchRideId: String?, searchRideLevel:String?) {
        var filterList:[User] = []
        for user in userList {
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
            if searchTerm != "" {
                show = false
                if (user.nameFirst?.uppercased().contains(searchTerm.uppercased()))! {
                    show = true
                }
                if (user.nameLast?.uppercased().contains(searchTerm.uppercased()))! {
                    show = true
                }
            }
            if show {
                filterList.append(user)
            }
        }
        self.viewUserList = filterList
    }
}

struct PeopleListView: View {
    @ObservedObject var model = UserModel.userModel
    @ObservedObject var viewModel = PeopleListModel.model
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
    @State var userHasProfile = false
    
    func rideTitle(id: String) -> String {
        for ride in Rides.instance().rides {
            if ride.rideId == id {
                return ride.titleWithoutLevels() ?? ""
            }
        }
        return ""
    }
    
    func getJoinEnabled() -> Bool {
        return UserModel.userModel.fetchedUser != nil
    }
    
    var body: some View {
        // users not signed with Apple ID can read the Cloudkit List, i.e. no need to be signed in
        let searchBinding = Binding<String>(get: {
            self.searchTerm
        }, set: {
            self.searchTerm = $0
            viewModel.filterUserList(userList: UserModel.userModel.userProfileList!, searchTerm: self.searchTerm,
                                     searchRideId: self.onMyRide ? UserModel.userModel.currentUser!.joinedRideID : nil,
                                     searchRideLevel: self.onMyRide ? UserModel.userModel.currentUser!.joinedRideLevel : nil)
        })

        let onMyRide = Binding<Bool>(get: {
            self.onMyRide
        }, set: {
            self.onMyRide = $0
            viewModel.filterUserList(userList: UserModel.userModel.userProfileList!, searchTerm: self.searchTerm,
                                     searchRideId: self.onMyRide ? UserModel.userModel.currentUser!.joinedRideID : nil,
                                     searchRideLevel: self.onMyRide ? UserModel.userModel.currentUser!.joinedRideLevel : nil)
        })

        //must be navigation view to allow NAv links below to work
        return NavigationView {
            GeometryReader { geometry in
                VStack {
                    if UserModel.userModel.userProfileList == nil  {
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
                            Text("Seach")
                            TextField("", text: searchBinding, onEditingChanged: {(editingChanged) in})
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: geometry.size.width * 0.5)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                            //.returnKeyType = .next
                        }
                        Toggle("On My Ride", isOn: onMyRide).disabled(UserModel.userModel.currentUser == nil || UserModel.userModel.currentUser?.joinedRideID == nil || UserModel.userModel.currentUser!.joinedRideID == "")
                        .frame(width: geometry.size.width * 0.5)
                        
                        //sometimes the email search results after the list results and so the current user show blank in the list - this attempts to fix that
                        //List(self.filteredUsers()) { user in
                        List(self.viewModel.viewUserList) { user in
                            //ForEach(UserModel.userModel.userList!) { user in

                            if let recId = user.recordId {
                                NavigationLink(destination: PersonView(recordId: recId)) {
                                    Text("\((user.nameFirst ?? UserModel.userModel.currentUser?.nameFirst)!) \(user.nameLast ?? "")")
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

                            NavigationLink(destination: ProfileEditView(isPresented: $showProfile), isActive: $showProfile) {
                                Text("My Profile")
                            }
                            .padding()
                            //.disabled(UserModel.userModel.currentUser == nil)
                            .disabled(model.currentUser == nil)

                            NavigationLink(destination: RideJoinView(
                                                                     joinedRide: UserModel.userModel.currentUser?.joinedRideID,
                                                                     joinedRideLevel: UserModel.userModel.currentUser?.joinedRideLevel), isActive: $showJoinRide) {
                                Text("Join/Leave Ride")
                            }
                            .padding()
                            //only enabled if user has profile
                            //also check current user in case they they
                            .disabled(UserModel.userModel.fetchedUser == nil ||
                                        UserModel.userModel.fetchedUser?.email != UserModel.userModel.currentUser?.email)
                            //.hiddenNavigationBarStyle()

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
            userHasProfile = false
            if let user = UserModel.userModel.currentUser {
                //do they have a profile?
                UserModel.userModel.searchUserByEmail(email: user.email!)
                // for some unfathomable reason the .onrec from the 1st has a userlist = nil (but the users coming back >0 users)
                //UserModel.userModel.searchUserByEmail(email: user.email!)
            }
            // do it every time the view appears to get latest data
            UserModel.userModel.loadAllUsers()
        }
        
        .onReceive(UserModel.userModel.$fetchedUser) {user in
            // called when a user is fetched with non nil user => they have a profile when the view appeared
            // called with a nill user when this view navigates to the profile edit subview
            if let user = user {
                // this record may have been fetched by another view. e.g. the person view
                if user.email == UserModel.userModel.currentUser?.email {
                    self.userHasProfile = true
                    UserModel.userModel.currentUser = User(user: user)
                }
            }
            else {
                self.userHasProfile = false
            }
        }
        
        .onReceive(UserModel.userModel.$userProfileList) {users in
            guard let users = users else {
                return
            }
            viewModel.filterUserList(userList: users, searchTerm: "", searchRideId: nil, searchRideLevel: nil)
        }
                        
        .onReceive(app.$userMessage) {msg in
            if msg != nil {
                self.sheetError = true
            }
        }
        
    }
}

