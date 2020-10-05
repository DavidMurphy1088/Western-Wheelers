import SwiftUI
import WebKit
import Combine

class WebViewModel: ObservableObject {
    var link: String
    @Published var didFinishLoading: Bool = false
    init (link: String) {
        self.link = link
    }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var viewModel: WebViewModel
    let webView = WKWebView()

    func makeUIView(context: UIViewRepresentableContext<WebView>) -> WKWebView {
        self.webView.navigationDelegate = context.coordinator
        if let url = URL(string: viewModel.link) {
            self.webView.load(URLRequest(url: url))
        }
        return self.webView
    }

    func updateUIView(_ uiView: WKWebView, context: UIViewRepresentableContext<WebView>) {
        return
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        private var viewModel: WebViewModel
        init(_ viewModel: WebViewModel) {
            self.viewModel = viewModel
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.viewModel.didFinishLoading = true
        }
    }

    func makeCoordinator() -> WebView.Coordinator {
        Coordinator(viewModel)
    }
}

struct RideWebView: View {
    @ObservedObject var model:WebViewModel

    var body: some View {
        VStack {
            VStack {
                if !model.didFinishLoading {
                    Text("Loading ride web site ...")
                    Image(systemName: "antenna.radiowaves.left.and.right").resizable().frame(width:20.0, height: 20.0)
                }
                WebView(viewModel: model)
            }
        }
    }
}
