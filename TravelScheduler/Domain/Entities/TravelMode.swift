import MapKit

enum TravelMode: String, CaseIterable, Identifiable {
    case driving = "驾车"
    case walking = "步行"

    var id: String { rawValue }

    var transportType: MKDirectionsTransportType {
        switch self {
        case .driving:
            return .automobile
        case .walking:
            return .walking
        }
    }
}
