import SwiftUI

struct UITextViewWrapper: UIViewRepresentable {
    typealias UIViewType = UITextView
    @Binding var text: String
    var onFocus: (() -> Void)
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
        
    // Updates the state of the specified view with new information from SwiftUI.
    func updateUIView(_ uiView: UITextView, context: UIViewRepresentableContext<UITextViewWrapper>) {
        if uiView.text != self.text {
            uiView.text = self.text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onDone: onDone, onFocus: onFocus)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var onFocus: (() -> Void)?
        var onDone: (() -> Void)?

        init(text: Binding<String>, onDone: (() -> Void)? = nil, onFocus: (() -> Void)? = nil) {
            self.text = text
            self.onDone = onDone
            self.onFocus = onFocus
        }

        func textViewDidBeginEditing(_ uiView: UITextView) {
            //right after user clicks in field and keyboard appears
            onFocus!()
        }
        
        func textViewDidChange(_ uiView: UITextView) {
            //after user types character
            text.wrappedValue = uiView.text
        }
        func textViewShouldEndEditing(_ uiView: UITextView) {
            //after user leaves field
            onDone!()
        }
        func textViewDidEndEditing(_ uiView: UITextView) {
            //after user leaves field
            onDone!()
        }

    }

}
