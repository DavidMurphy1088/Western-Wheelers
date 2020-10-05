import SwiftUI
//https://jetrockets.pro/blog/activity-indicator-in-swiftui

struct ActivityIndicator: View {
    @State private var isAnimating: Bool = false
    var body1: some View {
        Text("wait...")
    }

//    func scaleEffect(geometry: GeometryProxy) -> View {
//        return scaleEffect(!self.isAnimating ? 1 - CGFloat(index) / 5 : 0.2 + CGFloat(index) / 5)
//    }
    
    var body: some View {
        GeometryReader { (geometry: GeometryProxy) in
            ForEach(0..<5) { index in
                Group {
                    //test()
                    Circle()
                    .frame(width: geometry.size.width / 5, height: geometry.size.height / 5)
                    .scaleEffect(!self.isAnimating ? 1 - CGFloat(index) / 5 : 0.2 + CGFloat(index) / 5)
                    .offset(y: geometry.size.width / 10 - geometry.size.height / 2)
                }
                //Text("WESTERN WHEELERS")
                //self.group(geometry: geometry)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .rotationEffect(!self.isAnimating ? .degrees(0) : .degrees(360))
                .animation(Animation
                .timingCurve(0.5, 0.15 + Double(index) / 5, 0.25, 1, duration: 1.5)
                .repeatForever(autoreverses: false))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
        self.isAnimating = true
        }
    }
}
