import SwiftUI
import Combine
import os.log

import UIKit

struct QuizView: View {
    @ObservedObject var quizModel = QuizModel()
    @State var restartConfirm = false
    @State var loaded = false
    @State var pickSelection = 0
    @State var asking = true
    @State var imageLoading : Image = Image(systemName: "antenna.radiowaves.left.and.right")
    @State var imageQuiz : Image? = nil
    @State var answerCorrect = false
    @State var msg : String = ""
    @State var numCorrect = 0
    @State var numTries = 0
    @State var showInfo = false
    @State var info:String? = nil
    @State var errorMsg: String? = nil
    @State var compact = false
    @State var optionFontSize = 36.0
    @State var correctHistory : [Bool] = []
    @State var ansCount = 0
    @State var msgColor: Color = Color.black
    
    init() {
        // runs once when app loads, not multiple times each time quiz view appears
        // speed up (hopefully) CloudKit query when the quiz view appers
        self.quizModel.initModel(inView: false) 
    }
    
    func imgNum() -> Int? {
        return self.quizModel.getImageNum()
    }
    
    func performanceText() -> String {
        //http://grumdrig.com/emoji-list/
        var score_char = ""
        var score = 1.0
        if self.numTries > 0 {
            score = double_t(self.numCorrect) / double_t(self.numTries)
        }
        if score >= 0.75 {
            score_char = "\u{1f600}" //happy
        }
        else {
            if score >= 0.50 {
                score_char = "\u{1f60c}" //releived
            }
            else {
                if score > 0.25 {
                    score_char = "\u{1f611}" //confoudned
                }
                else {
                    score_char = "\u{1f616}" //confoudned
                }
            }
        }

        score *= 100
        if self.numTries == 0 {
            return ""
        }
        else {
            return  String(Int(score)) + "% " + score_char
        }
    }
    
    var ans_button: some View {
        VStack {
            HStack {
                Button(action: {
                    if self.asking {
                        self.answerCorrect = self.pickSelection == self.quizModel.correctOption
                        self.numTries += 1
                        if self.answerCorrect {
                            self.numCorrect += 1
                            self.msg = "Correct " //+ String(self.num_correct) + " out of " + String(self.num_tries) + " tries"
                            self.correctHistory.append(true)
                            self.msgColor = Color.green
                        }
                        else {
                            self.msg = "The road is " + self.quizModel.correctDescription
                            self.correctHistory.append(false)
                            self.msgColor = Color.red
                        }                        
                    }
                    else {
                        self.quizModel.loadNextImage()
                        self.imageQuiz = Image(uiImage: self.quizModel.image!)
                        self.msg = String(self.numCorrect) + " out of " + String(self.numTries) + " tries"
                        self.msgColor = Color.black
                    }
                    self.asking = !self.asking
                    self.ansCount += 1
                }) {
                    if self.asking {
                        Text("Check Answer").font(.system(size:20, weight: .bold, design: .default))
                    }
                    else {
                        Text("Next Ride Location").font(.system(size:20, weight: .bold, design: .default))
                    }
                }
                Spacer()
                
                Button(action: {
                    self.showInfo = true
                }) {
                    Image(systemName: "info.circle.fill").resizable().frame(width:30.0, height: 30.0)
                }
            }
            HStack {
                Text(self.msg).foregroundColor(self.msgColor)
                Spacer()
                Text(self.performanceText()).font(.system(size:30, weight: .bold, design: .default))
                Button(action: {
                    self.restartConfirm = true
                }) {
                    Text("Start Over")
                }
            }
        }
    }
    
    var body: some View {
        VStack {
            if self.errorMsg != nil  {
                Image(systemName: "wifi.exclamationmark").resizable().frame(width:50, height: 50)
                if self.errorMsg != nil {
                    Text("Error occurred: "+self.errorMsg!)
                }
            }
            else {
                if self.imageQuiz == nil {
                    VStack {
                        ActivityIndicator().frame(width: 50, height: 50)
                    }.foregroundColor(Color.blue)
                    Text("Loaded images: \(self.quizModel.indexLoaded)")
                }
                else {
                    Text("Where is this ride?")
                    if self.ansCount == 0 {
                        Text("Select from the scrolling")
                        Text("list in the image below.")
                    }
                    ZStack {
                        //self.image_quiz!.resizable().aspectRatio(contentMode: .fit)
                        self.imageQuiz!.resizable()
                        if !self.asking {
                            if self.answerCorrect {
                                Image(systemName: "checkmark.circle").resizable().frame(width:140.0, height: 140.0).foregroundColor(.green)
                            }
                            else {
                                Image(systemName: "xmark.octagon").resizable().frame(width:70.0, height: 70.0).foregroundColor(.red)
                            }
                        }
                        //https://developer.apple.com/documentation/swiftui/picker
                        if self.imgNum() != nil {
                            Picker(selection: $pickSelection, label: Text("")) {
                                ForEach(0 ..< self.quizModel.imageRecords[self.imgNum()!].answerOptions.count) { index in
                                    //Text(self.quiz_model.image_records[self.img_num()].answer_options[index]).tag(index).foregroundColor(.white).font(.largeTitle).lineSpacing(50)
                                    Text(self.quizModel.imageRecords[self.imgNum()!].answerOptions[index]).tag(index)
                                    //.foregroundColor(.white)
                                        .foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0))
                                    //.font(.headline)
                                    //.font(.largeTitle)
                                        .font(.system(size:CGFloat(self.optionFontSize), weight: .bold, design: .default))
                                    //.frame(minWidth: 0, maxWidth: 400, minHeight: 400, maxHeight: 400)
                                    //.background(Color.black)
                                    //.padding(.vertical, 100.0)
                                    //.fixedSize()
                                    //.frame()
                                    if self.compact {
                                        Spacer()
                                    }
                                }
                            }
                            .id(self.imgNum()) //Dont remove - required to make picker refresh for each new image
                            .labelsHidden()
                            //.frame(height: 180)
                            //.clipped()
                            .fixedSize()
                                .fixedSize(horizontal: true, vertical: true)
                                .frame(height: 90)
                                .frame(width: 50, height: 200, alignment: .center)
                                //.pickerStyle(SegmentedPickerStyle())
                                //.scaledToFit()
                                //.scaleEffect(CGSize(width: 1.5, height: 1.5))
                                //.lineSpacing(.greatestFiniteMagnitude)
                                //.scaledToFit()
                                //.scaledToFill()
                                //.lineSpacing(10.0 as! CGFloat)
                                //.pickerStyle(SegmentedPickerStyle()) // horizontal row of options, but descriptions truncated, other styles not in iOS
                        }
                    }
                    self.ans_button
                }
                
            }
        }.onAppear() {
            //occurs every time view appears
            if !self.loaded {
                self.quizModel.initModel(inView: true)
                self.loaded = true
            }
            if self.info == nil {
                if let fileURL = Bundle.main.url(forResource: "doc_quiz_info", withExtension: "txt") {
                    if let fileContents = try? String(contentsOf: fileURL) {
                        self.info = fileContents
                    }
                }
            }
            self.ansCount = 0
        }
        .onReceive(self.quizModel.$imageLoaded) {_ in
            if self.quizModel.imageLoaded {
                self.imageQuiz = Image(uiImage: self.quizModel.image!)
            }
        }
        .onReceive(self.quizModel.$modelError) {_ in
            if let err = self.self.quizModel.modelError {
                self.errorMsg = err
            }
        }

        .alert(isPresented:self.$restartConfirm) {
            Alert(title: Text("Start the quiz over?"),  primaryButton: .destructive(Text("Yes")) {
                //self.textView = nil
                self.restartConfirm.toggle()
                self.quizModel.loadNextImage()
                self.asking = true
                self.msg = ""
                self.numTries = 0
                self.numCorrect = 0
            }, secondaryButton: .cancel())
        }
            
        .actionSheet(isPresented: $showInfo) {
            var info:String = self.info ?? ""
            if self.imgNum() != nil {
                info = info + "\nImage:\(self.quizModel.imageRecords[self.imgNum()!].imageNum ?? "")"
            }
            return ActionSheet(
                title: Text("Quiz Information"),
                message: Text(info),
                buttons: [
                    .cancel {  },
                ]
            )
        }
    }
}


