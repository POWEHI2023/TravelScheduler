import Foundation
import MapKit

protocol RoutePlanningServing {
    func makeSegments(for stops: [TripStop], mode: TravelMode) async throws -> [RouteSegment]
}

struct MapKitRoutePlanningService: RoutePlanningServing {
    func makeSegments(for stops: [TripStop], mode: TravelMode) async throws -> [RouteSegment] {
        guard stops.count >= 2 else { return [] }

        var segments: [RouteSegment] = []
        segments.reserveCapacity(stops.count - 1)

        for index in 0..<(stops.count - 1) {
            let sourceStop = stops[index]
            let destinationStop = stops[index + 1]

            if sameCoordinate(sourceStop.coordinate, destinationStop.coordinate) {
                let polyline = MKPolyline(coordinates: [sourceStop.coordinate, destinationStop.coordinate], count: 2)
                segments.append(
                    RouteSegment(
                        from: sourceStop,
                        to: destinationStop,
                        distance: 0,
                        expectedTravelTime: 0,
                        polyline: polyline
                    )
                )
                continue
            }

            let request = MKDirections.Request()
            request.source = sourceStop.mapItem
            request.destination = destinationStop.mapItem
            request.transportType = mode.transportType
            request.requestsAlternateRoutes = false

            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else { continue }

            segments.append(
                RouteSegment(
                    from: sourceStop,
                    to: destinationStop,
                    distance: route.distance,
                    expectedTravelTime: route.expectedTravelTime,
                    polyline: route.polyline
                )
            )
        }

        return segments
    }

    private func sameCoordinate(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.00001 && abs(lhs.longitude - rhs.longitude) < 0.00001
    }
}
