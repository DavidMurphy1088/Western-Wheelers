import SwiftUI

struct MultilineTextField: View {    
    
    private var placeholder: String
    private var onFocus: (() -> Void)?
    private var onDone: (() -> Void)?

    var text: String
    var user: User
    
    init (_ placeholder: String = "", textIn: String, onFocus: (() -> Void)? = nil, onDone: (() -> Void)? = nil, user:User) {
        self.placeholder = placeholder
        self.onDone = onDone
        self.onFocus = onFocus
        self.text = textIn
        self.user = user
        //self.viewHeight = height
        //self._shouldShowPlaceholder = State<Bool>(initialValue: self.text.isEmpty)
    }

    private var internalText: Binding<String> {
        Binding<String>(get: { self.text } ) {
            user.info = $0
            //The string that is displayed when there is no other text in the text field.
            //self.shouldShowPlaceholder = $0.isEmpty
        }
    }

    var body: some View {
        UITextViewWrapper(text: self.internalText, onDone: onDone) //, calculatedHeight: $viewHeight
            //.frame(minHeight: viewHeight, maxHeight: viewHeight)
            //.border(Color.pink)
            //.background(placeholderView, alignment: .topLeading)
            .onTapGesture {
                self.onFocus!()
            }
    }
}

private struct UITextViewWrapper: UIViewRepresentable {
    typealias UIViewType = UITextView
    @Binding var text: String
    var onFocus: (() -> Void)?
    var onDone: (() -> Void)?
    var onLeave: (() -> Void)?

    func makeUIView(context: UIViewRepresentableContext<UITextViewWrapper>) -> UITextView {
        let textField = UITextView()
        textField.delegate = context.coordinator
        textField.isEditable = true
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.isSelectable = true
        textField.isUserInteractionEnabled = true
        textField.isScrollEnabled = true
        textField.backgroundColor = UIColor.clear
        //textField.returnKeyType = .continue
//        if nil != onDone {
//            textField.returnKeyType = .done
//        }
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textField
    }
    
    //When the state of your app changes, SwiftUI updates the portions of your interface affected by those changes.
    //SwiftUI calls this method for any changes affecting the corresponding UIKit view. Use this method to update the configuration of your view to match
    //the new state information provided in the context parameter.
    //first click in field to position generates updateUIView and brings up the KB
    //first character typed - Connection to daemon was invalidated and cursor is set to end of text (even if uiView.text = self.text commented)
    
//    https://forums.raywenderlich.com/t/your-first-ios-app-43-wkwebview/77031/2
//    proposes an explanation (could not check) to the loss of connection:
//    The ‘processAssertionWasInvalidated’ comes after the ‘WKWebView’ object is released from memory. Retaining a reference (for example, by reusing the view controller that
//    contains it instead of creating a new one) avoids this warning. Apparently something is trying to communicate with web view and has not been told it has been released.
    
    func updateUIView(_ uiView: UITextView, context: UIViewRepresentableContext<UITextViewWrapper>) {
        
        if uiView.text != self.text {
            //CGSize newSize = [uiView sizeThatFits:CGSizeMake(fixedWidth, MAXFLOAT)];

            uiView.isScrollEnabled = false;
            uiView.text = self.text
            uiView.isScrollEnabled = true;
        }
    }
    
    func makeCoordinator() -> Coordinator {
        //return Coordinator(text: $text, height: $calculatedHeight, onDone: onDone)
        return Coordinator(text: $text, onDone: onDone)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        //var calculatedHeight: Binding<CGFloat>
        var onDone: (() -> Void)?

        //init(text: Binding<String>, height: Binding<CGFloat>, onDone: (() -> Void)? = nil) {
        init(text: Binding<String>, onDone: (() -> Void)? = nil) {
            self.text = text
            self.onDone = onDone
        }

        func textViewDidBeginEditing(_ uiView: UITextView) {
            //right after user clicks in field and keyboard appears
        }
        func textViewDidChange(_ uiView: UITextView) {
            //after user types character
            text.wrappedValue = uiView.text
        }
        
        func textViewDidEndEditing(_ uiView: UITextView) {
            //after user leaves field
        }

    }

}
