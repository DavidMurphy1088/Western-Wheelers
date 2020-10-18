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

    var body: some View {
        NavigationView { //required but creates yet more unwanted space at top of view
            //Geo reader here seems to force everything left on the screen. Seems like a SwiftUI bug?
            //GeometryReader { geometry in
                VStack() {
                    if self.userForView != nil {
                        Text("\(self.userForView!.nameFirst!) \(self.userForView!.nameLast!)").font(.title)
                        if self.userForView!.picture != nil {
//                            Image(uiImage: (self.getImage())!)
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
                            Image(uiImage: (self.getImage())!)
                                .resizable()
                                .aspectRatio(self.getImageAspectRatio(), contentMode: .fit)
                        }
                        ScrollView{
                            Text(self.userForView!.info ?? "")
                            .padding()
                        }
                    }
                    else {
                        VStack {
                            ActivityIndicator().frame(width: 50, height: 50)
                        }.foregroundColor(Color.blue)
                    }
                }
            //}
        }
        .onAppear() {
            self.userForView = nil
            self.model.fetchUser(recordId: self.recordId)
        }
        .onReceive(UserModel.userModel.$fetchedIDUser) {fetchedUser in
            if fetchedUser != nil {
                self.userForView = fetchedUser
            }
        }
    }
}

