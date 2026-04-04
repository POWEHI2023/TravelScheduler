import Foundation

enum TransitRouteProvider: String, Hashable {
    case appleMaps = "Apple 地图"

    var displayName: String { rawValue }
}

enum TransitPreference: String, CaseIterable, Hashable {
    case bus
    case subway
    case commuter
    case ferry

    var displayName: String {
        switch self {
        case .bus:
            return "公交"
        case .subway:
            return "地铁"
        case .commuter:
            return "通勤铁路"
        case .ferry:
            return "轮渡"
        }
    }

    var queryValue: String {
        rawValue
    }
}

struct TransitRouteReference: Hashable {
    static let defaultPreferredModes: [TransitPreference] = [.bus, .subway]

    let provider: TransitRouteProvider
    let launchURL: URL
    let preferredModes: [TransitPreference]
    let estimatedTravelTime: TimeInterval?

    init(
        provider: TransitRouteProvider = .appleMaps,
        launchURL: URL,
        preferredModes: [TransitPreference] = TransitRouteReference.defaultPreferredModes,
        estimatedTravelTime: TimeInterval? = nil
    ) {
        self.provider = provider
        self.launchURL = launchURL
        self.preferredModes = preferredModes
        self.estimatedTravelTime = estimatedTravelTime
    }

    var preferredModesDescription: String {
        preferredModes.map(\.displayName).joined(separator: "、")
    }
}
