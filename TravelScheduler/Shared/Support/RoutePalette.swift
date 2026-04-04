import SwiftUI

enum RoutePalette {
    private static let colors: [Color] = [
        Color(red: 0.30, green: 0.47, blue: 0.63),
        Color(red: 0.35, green: 0.58, blue: 0.52),
        Color(red: 0.67, green: 0.55, blue: 0.41),
        Color(red: 0.57, green: 0.49, blue: 0.65),
        Color(red: 0.44, green: 0.54, blue: 0.56),
        Color(red: 0.63, green: 0.48, blue: 0.52),
        Color(red: 0.52, green: 0.60, blue: 0.42),
        Color(red: 0.40, green: 0.49, blue: 0.57)
    ]

    static func color(at index: Int) -> Color {
        colors[index % colors.count]
    }
}
