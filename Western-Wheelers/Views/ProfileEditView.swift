import SwiftUI
import SwiftUI
import UIKit
import Combine
import os.log
import FBSDKLoginKit
import FBSDKShareKit
import FBSDKCoreKit
import CloudKit

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

class KeyboardHeightHelper: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    init() {
        self.listenForKeyboardNotifications()
    }
    private func listenForKeyboardNotifications() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardDidShowNotification,
                                               object: nil,
                                               queue: .main) { (notification) in
                                                guard let userInfo = notification.userInfo,
                                                    let keyboardRect = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                                                
                                                self.keyboardHeight = keyboardRect.height
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardDidHideNotification,
                                               object: nil,
                                               queue: .main) { (notification) in
                                                self.keyboardHeight = 0
        }
    }
}

extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIApplication.keyboardWillShowNotification)
            .map { $0.keyboardHeight }

        let willHide = NotificationCenter.default.publisher(for: UIApplication.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }

        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

extension Notification {
    var keyboardHeight: CGFloat {
        return (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
    }
}

class UserLoginManager: UIViewController, ObservableObject  {
    let loginManager = LoginManager()
    
    func facebookLogin(imageLoader: ImageLoader)  {
        let fbLoginManager : LoginManager = LoginManager()
        //https://stackoverflow.com/questions/29152500/get-real-profile-url-from-facebook-graph-api-user ==> "user_link" for their home page
        fbLoginManager.logIn(permissions: ["email"], from: self) { (result, error) -> Void in //, "user_link" needs app review
            if (error == nil) {
                let fbloginresult : LoginManagerLoginResult = result!
                if (result?.isCancelled)!{
                    return
                }
                if (fbloginresult.grantedPermissions.contains("email")) {
                    self.getFBUserData(imageLoader: imageLoader)
                }
            }
        }
    }
    
    func getFBUserData(imageLoader: ImageLoader)  {
        if((AccessToken.current) != nil){
            let graphRequest = GraphRequest(graphPath: "me",
                         parameters: ["fields": "id, name, first_name, last_name, picture.type(large), email"])
                
//            graphRequest.start(completionHandler: { (connection, result, error) -> Void in
//                if (error == nil){
//                    guard let userDict = result as? [String:Any] else {
//                        return
//                    }
//                    if let picture = userDict["picture"] as? [String:Any] ,
//                        let imgData = picture["data"] as? [String:Any] ,
//                        let url = imgData["url"] as? String {
//                        imageLoader.loadImage(url: url)
//                    }
//                 }
//            })
            graphRequest.start { (connection, result, error) in
                if (error == nil){
                    guard let userDict = result as? [String:Any] else {
                        return
                    }
                    if let picture = userDict["picture"] as? [String:Any] ,
                        let imgData = picture["data"] as? [String:Any] ,
                        let url = imgData["url"] as? String {
                        imageLoader.loadImage(url: url)
                    }
                 }
            }

        }
    }
}

// --------------------- Camera Images -----------------

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @State var par:ProfileEditView
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            guard let unwrapImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
                return
            }
            //parent.user!.picture = unwrapImage
            parent.par.setImage(image: unwrapImage)
            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {
    }
}

struct ProfileEditView: View {
    @Binding var isPresented:Bool
    @Binding var onRideFilterOn:Bool
    @ObservedObject var model = UserModel.userModel
    @ObservedObject var app = Util.app()
    @ObservedObject var fbmanager = UserLoginManager()
    @ObservedObject var imageLoader = ImageLoader()
    @ObservedObject var keyboardHeightHelper = KeyboardHeightHelper()
    
    //@State var keyboardHeight: CGFloat = 0
    @State var infoInFocus = false
    @State var queryRunning = false //View will refresh iff var is @State AND it's used the body AND its state changes in an .onNotify

    @State private var showAlert = false
    enum AlertType {
        case none, confirmDelete, emptyProfile, noUser
    }
    @State var alertType:AlertType = .none
    
    @State var showCameraSheet = false
    @State var userInfo = ""
    
    //needed to dismiss keyboard - UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

    func setImage(image:UIImage) {
        let user = UserModel.userModel.currentUser
        if let u = user {
            //force view to refresh from observed object
            u.picture = image
            UserModel.userModel.setCurrentUser(user: u)
        }
    }
    
    func turnOffOnRideFilter() {
        //turn off onRide filter UI toggle and model filter when profile deleted
        onRideFilterOn = false
        ProfileListModel.model.clearRideFilter()
    }
    
    var isLandscape: Bool {
        return UIApplication.shared.windows
            .first?
            .windowScene?
            .interfaceOrientation
            .isLandscape ?? false
    }
    
    var pictureButtons: some View {
        VStack {
            Text("")
            Text("Picture From")
            HStack {
                Spacer()
                Button(action: {
                    self.fbmanager.facebookLogin(imageLoader: self.imageLoader)
                }) {
                    HStack {
                        Text("Facebook")
                    }
                }
                Spacer()
                Button(action: {
                    self.showCameraSheet = true
                    //self.sheetType = .imageCapture
                    
                }) {
                    Text("Camera")
                }
                Spacer()
            }
            if let user = UserModel.userModel.currentUser {
                Button(action: {
                    //force view refresh - but there has to be a better way :(
                    let user = User(user: user)
//                    user.email = self.profileUser.email
//                    user.nameLast = self.profileUser.nameLast
//                    user.nameFirst = self.profileUser.nameFirst
//                    user.info = self.profileUser.profileInfo
//                    user.profileInfo = self.profileUser.profileInfo
                    user.picture = nil
                    //UserModel.userModel.currentUser = user
                    UserModel.userModel.setCurrentUser(user: user)
                 }) {
                    Text("Remove Picture")
                }
            }
        }
    }
    
    var saveButton: some View {
        return Button(action: {
            if (UserModel.userModel.currentUser!.info == nil || UserModel.userModel.currentUser!.info!.trimmingCharacters(in: .whitespacesAndNewlines) == "") &&
                (UserModel.userModel.currentUser!.picture == nil) {
                self.showAlert = true
                self.alertType = .emptyProfile
            }
            else {
                UserModel.userModel.currentUser!.saveProfile()
                self.isPresented = false
            }
        }) {
            Text("Save")
        }

    }
    var actionButtons: some View  {
        HStack {
            Spacer()
            self.saveButton
            if UserModel.userModel.currentUser!.recordId != nil {
                Spacer()
                //user has a Cloudkit record to delete
                Button(action: {
                    self.showAlert = true
                    self.alertType = .confirmDelete
                }) {
                    Text("Delete").foregroundColor(.red)
                }
            }
            Spacer()
        }
    }

    func editHeight(screenHeight: CGFloat, hasFocus: Bool, kbHeight:CGFloat) -> CGFloat {
        var res:CGFloat = 0.0
        if hasFocus {
            res = screenHeight * 0.5 //minus kbHeight - the screen height passed from the geometry reader already appears to be adjusted for kb height
        }
        else {
            res = screenHeight * 0.3
        }
        return res
    }
    
    func getImage() -> UIImage? {
        let image = UserModel.userModel.currentUser!.picture
        return image
    }
    
    var editor: some View {
        GeometryReader { geometry in
            VStack {
                //Text("\(profileUser.nameFirst!) \(profileUser.nameLast!)")

                if !self.infoInFocus {
                    if keyboardHeightHelper.keyboardHeight == 0 && !self.isLandscape {
                        self.pictureButtons
                        if !self.isLandscape {
                            if let pic = self.getImage() {
                                Image(uiImage:pic) //.fixOrientation()!)
                                    .resizable()
                                    .scaledToFit()
                            }
                            else {
                                Image("no-pic").resizable().scaledToFit()
                            }
                        }
                    }
                    Text("Narrative for your profile. For example, when not riding, what are your other interests?")
                        //.foregroundColor(.blue)
                        .font(.footnote)
                        .padding()
                        //wrap text if required
                        .fixedSize(horizontal: false, vertical: true)
                }
                    

                if keyboardHeightHelper.keyboardHeight != 0 {
                    Text("")
                    Spacer()
                }
                VStack {
                    UITextViewWrapper(text: self.$userInfo,
                        onFocus: {
                            self.infoInFocus = true
                        },
                        onDone: {
                            self.infoInFocus = false
                            if let user = UserModel.userModel.currentUser {
                                user.info = self.userInfo
                            }
                        })
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
                }

                //.overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.red))
                .frame(width: 0.9 *  geometry.size.width,
                       height: self.editHeight(screenHeight: geometry.size.height, hasFocus: self.infoInFocus, kbHeight: keyboardHeightHelper.keyboardHeight))
                //.border(Color.blue)

                if keyboardHeightHelper.keyboardHeight != 0 {
                    //keyboard is editing profile and user can end edit with DONE on keyboard
                    if keyboardHeightHelper.keyboardHeight != 0 {
                        HStack {
                            Spacer()
                            self.saveButton
                            Spacer()
                            Button("Hide Keyboard") {
                                self.infoInFocus = false
                                self.hideKeyboard()
                            }
                            Spacer()
                        }
                    }
                    Spacer().frame(height: 1.0 * keyboardHeightHelper.keyboardHeight)
                }
                else {
                    self.actionButtons
                    Text("")
                }
            }
        }
    }

    var body: some View {
        //Dont even think about not having this as a Nav View.
        //It seems to be the only way to stop numerous, unpredictable and frequent types of runtime crashes
        //e.g. precondition failure: attribute failed to set an initial value: 355 which crashes the app
        NavigationView {
            VStack {
                if self.queryRunning {
                    VStack {
                        Text("\(UserModel.userModel.currentUser!.nameFirst!) \(UserModel.userModel.currentUser!.nameLast!)")
                        ActivityIndicator().frame(width: 50, height: 50).foregroundColor(Color.blue)
                    }
                }
                else {
                    editor
                }
            }
        }
        
        .sheet(isPresented: self.$showCameraSheet) {
            //let im = UserModel.userModel.currentUser.picture
            ImagePicker(par: self)//.frame(width: 200, height: 200)
        }
        
        .alert(isPresented:self.$showAlert) {
            if self.alertType == .emptyProfile {
                return Alert(title: Text("Empty Profile"),
                             message: Text("Your profile can't be empty. You need either a picture or info but preferably both please."),
                             dismissButton: .default(Text("Ok")){
                                self.showAlert = false
                                self.alertType = .none
                    })
            }
            if self.alertType == .confirmDelete {
                return Alert(title: Text("Delete your profile?"),
                    primaryButton: .destructive(Text("Delete")) {
                        UserModel.userModel.currentUser!.info = nil
                        UserModel.userModel.currentUser!.picture = nil
                        UserModel.userModel.currentUser!.joinedRideEventId = nil
                        UserModel.userModel.currentUser!.joinedRideLevel = nil
                        UserModel.userModel.currentUser!.deleteProfile()
                        //can keep local email, name etc to save them signing into WW again
                        self.showAlert = false
                        self.alertType = .none
                        self.turnOffOnRideFilter()
                        self.isPresented = false
                    }, secondaryButton: .cancel(){
                        self.showAlert = false
                        self.alertType = .none
                    })
            }
            return Alert(title: Text("No alert"))
        }

        .onAppear() {
            if let user = UserModel.userModel.currentUser {
                self.queryRunning = true
                UserModel.userModel.searchUserByEmail(email: user.email!)
            }
            else {
                self.showAlert = true
                self.alertType = .noUser
            }
            //the current user may not yet have the Cloudkit profile data so .anAppear fetches it
            //sequence is
            //.onReceive nil - only(?) becuase I'm subscribed to fetched user? (i.e. dont set fetchedRecord to nil before fetch step in model)
            //.onAppear - view becomes visible, every time it becomes visible, not just one
            //.onReceive - if a record was received, it will never be nil
        }
            
        .onReceive(UserModel.userModel.$emailSearchUser) {searchedUser in
            if !self.queryRunning {
                //view gets nil .onReceive of fetched user before it calls.onAppear
                return
            }
            self.queryRunning = false
            if let user = searchedUser {
                UserModel.userModel.setCurrentUser(user: user)
                self.userInfo = user.info ?? ""
            }
        }
            
        .onReceive(self.imageLoader.$dataWasLoaded) {_ in
            // loaded from FB
            if let im = self.imageLoader.image {
                UserModel.userModel.currentUser!.picture = im
            }
        }
    }
}

