import SwiftUI
import Combine
import os.log
import CloudKit

struct PersonView: View {
    @ObservedObject var model = UserModel.userModel
    @State var recordId:CKRecord.ID
    @State var userForView:User?
    
    func getImage() -> UIImage? {
        guard let user = self.userForView else {
            return nil
        }
        let im = user.picture
        return im
    }
    
    func getImageAspectRatio() -> CGFloat {
        guard let user = self.userForView else {
            return 0
        }
        guard let im = user.picture else {
            return 0.0
        }
        let h = im.size.height
        if h == 0 {
            return 0.0
        }
        else {
            return im.size.width / im.size.height
        }
    }
    
    func textLen(text:String?) -> Int {
        guard let text = text else {
            return 0
        }
        let trim = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trim.count
    }
    
    func textHeight(geoHeight:CGFloat, textLen:Int, imgExists:Bool) -> CGFloat {
        if imgExists {
            if textLen < 30 {
                return 0.1 * geoHeight
            }
            else {
                return 0.3 * geoHeight
            }
        }
        else {
            return 0.9 * geoHeight
        }
    }

    var body: some View {
        //NavigationView creates yet more unwanted space at top of view
        //without nv app frequently gives :precondition failure: attribute failed to set an initial value: 197
        //After adding the.navBarTitle the precondition error mysteriously disappeared ????.
        //So take the risk of no Navview, since having the NavView wastes a lot of space at the top
        //It should not be required.
        //NavigationView {
            GeometryReader { geometry in
                VStack() {
                    if self.userForView != nil {
                        //Text("\(self.userForView!.nameFirst!) \(self.userForView!.nameLast!)").font(.title)
                        if self.userForView!.picture != nil {
                            Image(uiImage: (self.getImage())!)
                                .resizable()
                                .aspectRatio(self.getImageAspectRatio(), contentMode: .fit)
                                .frame(width: geometry.size.width * 0.95)
                        }
                        
                        //if self.textLen(text: self.userForView?.info) > 0 {
                            ScrollView{
                                Text(self.userForView!.info ?? "")
                                    .padding(.horizontal)
                            }
                            .frame(height: self.textHeight(geoHeight: geometry.size.height, textLen: self.textLen(text: self.userForView?.info),
                                                           imgExists: self.userForView!.picture != nil))
                        //}
                    }
                    else {
                        ActivityIndicator().frame(width: 50, height: 50)
                        .foregroundColor(Color.blue)
                    }
                }
            }
        //}
        .navigationBarTitle(Text("\(self.userForView?.nameFirst ?? "") \(self.userForView?.nameLast ?? "")"), displayMode: .inline)
        .onAppear() {
            self.userForView = nil
            self.model.getUserById(recordId: self.recordId)
        }
        .onReceive(UserModel.userModel.$fetchedIDUser) {fetchedUser in
            if fetchedUser != nil {
                self.userForView = fetchedUser
            }
        }
    }
}

