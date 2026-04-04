import Foundation

enum TransitRouteProvider: String, Hashable {
    case appleMaps

    var displayName: String { L10n.transitProviderName(self) }
}

enum TransitPreference: String, CaseIterable, Hashable {
    case bus
    case subway
    case commuter
    case ferry

    var displayName: String {
        L10n.transitPreferenceName(self)
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
        ListFormatter.localizedString(byJoining: preferredModes.map(\.displayName))
    }
}
