import Foundation
import Combine
import SwiftUI


class ImageLoader : ObservableObject {
    var image:UIImage? = nil
    @Published var dataWasLoaded = false
    private var image_url: String?

    func notify(err_msg: String?) {
        DispatchQueue.main.async {
            self.dataWasLoaded = true
        }
    }
    
    func setImage(pic: UIImage) {
        self.image = pic
        DispatchQueue.main.async {
            self.dataWasLoaded = true
        }
    }
    
    func loadImage(url : String) {
        image_url = url
        guard let imageURL = URL(string: url) else {
            fatalError("ImageURL is not correct!")
        }
        URLSession.shared.dataTask(with: imageURL) { data, response, error in
            guard let data = data, error == nil else {
                self.notify(err_msg: "\(String(describing: error))")
                return
            }
            let im = UIImage(data: data)
            if let im_opt = im {
                //self.image = Image(uiImage: im_opt)
                self.image = im_opt
                self.notify(err_msg: nil)
            }
            else {
                self.image = nil
                // e.g. from AWS <Code>AccessDenied</Code>
                self.notify(err_msg: "bad image data")
            }
        }.resume()
    }
}
