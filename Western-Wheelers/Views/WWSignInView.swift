import SwiftUI
import UIKit
import Combine
import os.log

struct WWSignInView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var api = WAApi.instance()
    @State private var username = "" //daxvixdp.murphy@sbcglobal.net" //TxODO
    @State private var password = ""
    @State private var failedSigin = false
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        VStack  {
            if self.keyboardHeight == 0 {
//                Text("To create an app profile you need to to authenticate one-time on the Western Wheelers (Wild Apricot) web site so we know its really you.").font(.footnote).padding().fixedSize(horizontal: false, vertical: true)
                Text("Please use the email and password you use to sign into the Western Wheelers site as illustrated.").font(.footnote).padding().fixedSize(horizontal: false, vertical: true)
                Image("Image-example_signin").resizable().frame(width: 180, height: 180)
            }
            Text("Western Wheelers Sign In").font(.title)
            Text("")
            Text("Email")//.frame(width: 150, height: nil)
            TextField("email", text: self.$username, onEditingChanged: {_ in}, onCommit: {})
                .frame(width: 300, height: nil)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
        
            Text("Password")//.frame(width: 150, height: nil)
            SecureField("Password", text: $password, onCommit: {
                self.failedSigin = false
                self.api.authenticateUserFromWASite(user: self.username, pwd: self.password)
            })
            .frame(width: 300, height: nil)
            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
            HStack {
                Button(action: {
                    self.failedSigin = false
                    self.api.authenticateUserFromWASite(user: self.username, pwd: self.password)
                }) {
                    Text("Sign In")
                }
            }
        }
        .padding()
        
        .onAppear() {
            self.failedSigin = false
        }
        .onDisappear() {
            self.failedSigin = false
        }
        .onReceive(self.api.$errMsg) {msg in
            if msg != nil {
                self.failedSigin = true
            }
        }
        .onReceive(UserModel.userModel.$currentUser) {user in
            // current user was created by WA api
            if user != nil {
                self.failedSigin = false
                self.isPresented = false
            }
        }
        .actionSheet(isPresented: $failedSigin) {
            ActionSheet(title: Text("Cannot sign in, \(self.api.errMsg)"))
        }
        .padding(.bottom, self.keyboardHeight)
        .onReceive(Publishers.keyboardHeight) {
            self.keyboardHeight = 1.0 * $0
        }
    }
}
