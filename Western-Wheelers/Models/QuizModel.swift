import SwiftUI
import Combine
import CloudKit

class ImageRecord {
    var recordId: CKRecord.ID?
    var imageNum: String?
    var description: String?
    var answerOptions : [String] = []
    var image: UIImage?
    var latitude: Double?
    var longitude: Double?
    var distance : Double
    static let OPT_MAX = 5
    
    init(id: CKRecord.ID, im_num:String, desc: String, lat: Double, lon: Double) {
        self.imageNum = im_num
        self.description = desc
        self.recordId = id
        self.latitude = lat
        self.longitude = lon
        self.distance = 0
        for _ in 0..<ImageRecord.OPT_MAX {
            answerOptions.append("")
        }
    }
}

class QuizModel : ObservableObject {
    private var questionIndex = -1
    private var questionIndexOrder : [Int] = []
    var image: UIImage? = nil
    var imageRecords = [ImageRecord]()
    var correctOption = 0
    var correctDescription = ""
    var imageNum = ""
    @Published var imageLoaded = false
    @Published var modelError:String? // = ""
    @Published var indexLoaded = 0

    func notifiyError(fcn: String, usrMsg: String, error:String) {
        Util.app().reportError(class_type: type(of: self), usrMsg:usrMsg, error: error) //, error: "func: " + fcn + "err:" + reason)
        for _ in 0...1 { // for some utterly unknown reason needs 2 attempts else target gets nil
            DispatchQueue.main.async {
                self.modelError = error
            }
        }
    }
    
    func initModel(inView:Bool) {
        //inView: call when app loads to spped up loading the quizView
        let pred = NSPredicate(value: true)
        let query = CKQuery(recordType: "Quiz_Images", predicate: pred)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["image", "image_num", "image_desc", "latitude", "longitude"]
        //operation.queuePriority = .veryHigh
        //if inView {
        operation.qualityOfService = .userInteractive
        
        if inView {
            operation.recordFetchedBlock = { record in
                let image_num = record["image_num"] as! String
                let image_desc = record["image_desc"] as! String
                let lat = record["latitude"] as! Double
                let lon = record["longitude"] as! Double
                let img_record = ImageRecord(id: record.recordID, im_num: image_num, desc: image_desc, lat: lat, lon: lon)
                self.questionIndexOrder.append(self.imageRecords.count)
                self.imageRecords.append(img_record)
                DispatchQueue.main.async {
                    self.indexLoaded = self.imageRecords.count
                }
            }

            operation.queryCompletionBlock = { [unowned self] (cursor, error) in
                if error != nil {
                    self.notifiyError(fcn: "init", usrMsg:"Cannot load quiz images", error: (error?.localizedDescription ?? ""))
                }
                else {
                    if self.imageRecords.count == 0 {
                        self.notifiyError(fcn: "init", usrMsg:"Zero quiz images", error: (error?.localizedDescription ?? ""))
                    }
                    else {
                        self.questionIndexOrder.shuffle()
                        self.loadNextImage()
                        
                    }
                }
            }
        }
        else {
            operation.queryCompletionBlock = { (cursor, error) in 
            }

        }
        CKContainer.default().publicCloudDatabase.add(operation)
    }

    func getImageNum() -> Int? {
        if self.imageRecords.count == 0 {
            return nil
        }
        return self.questionIndexOrder[self.questionIndex]
    }
    
    func dist(lat_o:Double, lon_o: Double, lat: Double, lon: Double) -> Double {
        return (abs(lat_o - lat) * abs(lat_o - lat)) + (abs(lon_o - lon) * abs(lon_o - lon))
    }
    
    func loadNextImage() {
        DispatchQueue.main.async {
            self.imageLoaded = false
        }
        self.questionIndex = (self.questionIndex + 1) % self.questionIndexOrder.count
        let record = self.imageRecords[getImageNum()!]
        self.imageNum = record.imageNum!
        
        // set answer options
        let lat_o = record.latitude
        let lon_o = record.longitude
        for rec in self.imageRecords {
            rec.distance = self.dist(lat_o: lat_o!, lon_o: lon_o!, lat: rec.latitude!, lon: rec.longitude!)
        }
        
        // sort by distance to chosen record
        let sort_dist = self.imageRecords.sorted(by: {
            $0.distance < $1.distance }
        )
        
        var opt_index = 0
        for r in 0..<ImageRecord.OPT_MAX {
            record.answerOptions[r] = ""
        }
        
        // insert non duplicate options closest to the correct answer
        for sorted_rec in sort_dist {
            var duplicate = false
            for opt in record.answerOptions {
                if opt == sorted_rec.description {
                    duplicate = true
                    continue
                }
            }
            if duplicate {
                continue
            }
            record.answerOptions[opt_index] = sorted_rec.description!
            opt_index += 1
            if opt_index >= ImageRecord.OPT_MAX {
                break
            }
        }
        record.answerOptions.shuffle()
        for r in 0..<ImageRecord.OPT_MAX {
            if record.answerOptions[r] == record.description {
                self.correctOption = r
                self.correctDescription = record.description ?? ""
                break
            }
        }
        
        //load the record's image
        let rec = self.imageRecords[getImageNum()!]
        let recordIDs = [rec.recordId!]
        let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
        operation.qualityOfService = .utility

        operation.perRecordCompletionBlock = { record, _, error in
            if error != nil {
                self.notifiyError(fcn: "read image record", usrMsg: "Cannot read image (error?.localizedDescription)", error: error?.localizedDescription ?? "")
            }
            if record != nil {
                let im = record?.object(forKey: "image") as! CKAsset
                let data = try? Data(contentsOf: (im.fileURL!))
                let image = UIImage(data: data!)
                self.image = image
                for _ in 0..<2 { //absolutley no idea why this has to be 2. If only once the view gets the notify but the image_loaded is false
                    DispatchQueue.main.async {
                        self.imageLoaded = true
                    }
                }
            }
        }
        CKContainer.default().publicCloudDatabase.add(operation)
    }
    
}
