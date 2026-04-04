enum TravelMode: String, CaseIterable, Identifiable {
    case driving
    case walking
    case transit

    var id: String { rawValue }

    var localizedName: String {
        L10n.travelModeName(self)
    }
}
