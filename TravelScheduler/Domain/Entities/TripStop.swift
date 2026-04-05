import Foundation
import MapKit

struct TripStop: Identifiable {
    private static let coordinateIdentityScale = 100_000.0

    let id: UUID
    let name: String
    let subtitle: String
    let mapItem: MKMapItem

    init(id: UUID = UUID(), name: String, subtitle: String, mapItem: MKMapItem) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.mapItem = mapItem
    }

    var coordinate: CLLocationCoordinate2D {
        mapItem.location.coordinate
    }

    var routeCacheKey: String {
        semanticIdentityKey
    }

    var mapsCoordinateQueryValue: String {
        String(
            format: "%.6f,%.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            coordinate.latitude,
            coordinate.longitude
        )
    }

    func isSemanticallyDuplicate(of other: TripStop) -> Bool {
        semanticIdentityKey == other.semanticIdentityKey
    }

    private var semanticIdentityKey: String {
        "\(normalizedName)|\(coordinateIdentityComponent)"
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var coordinateIdentityComponent: String {
        let latitude = Int((coordinate.latitude * Self.coordinateIdentityScale).rounded())
        let longitude = Int((coordinate.longitude * Self.coordinateIdentityScale).rounded())
        return "\(latitude)|\(longitude)"
    }
}
