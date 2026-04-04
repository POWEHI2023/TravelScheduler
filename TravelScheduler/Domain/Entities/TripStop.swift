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

    func isSemanticallyDuplicate(of other: TripStop) -> Bool {
        name == other.name &&
        abs(coordinate.latitude - other.coordinate.latitude) < 0.0001 &&
        abs(coordinate.longitude - other.coordinate.longitude) < 0.0001
    }
}
