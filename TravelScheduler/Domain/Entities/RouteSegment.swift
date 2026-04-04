import Foundation
import MapKit

struct RouteSegment: Identifiable {
    let id: UUID
    let from: TripStop
    let to: TripStop
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let polyline: MKPolyline

    init(
        id: UUID = UUID(),
        from: TripStop,
        to: TripStop,
        distance: CLLocationDistance,
        expectedTravelTime: TimeInterval,
        polyline: MKPolyline
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.distance = distance
        self.expectedTravelTime = expectedTravelTime
        self.polyline = polyline
    }
}
