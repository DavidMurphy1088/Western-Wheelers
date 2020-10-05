import Foundation

struct RideLevel: Identifiable {
    var id = UUID()
    var name: String
    init(label: String) {
        name = label
    }
}
