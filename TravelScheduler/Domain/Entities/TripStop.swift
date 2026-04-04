import Foundation
import MapKit

struct TripStop: Identifiable {
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
        let latitude = Int((coordinate.latitude * 100_000).rounded())
        let longitude = Int((coordinate.longitude * 100_000).rounded())
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedName)|\(latitude)|\(longitude)"
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
        name == other.name &&
        abs(coordinate.latitude - other.coordinate.latitude) < 0.0001 &&
        abs(coordinate.longitude - other.coordinate.longitude) < 0.0001
    }
}
