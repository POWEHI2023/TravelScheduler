import Foundation
import MapKit

struct RouteSegment: Identifiable {
    enum Representation {
        case inAppRoute
        case externalTransit(TransitRouteReference)
    }

    enum MapRenderStyle {
        case solid
        case connector
    }

    struct Detail: Identifiable {
        enum Kind {
            case step
            case warning
        }

        let id: UUID
        let kind: Kind
        let transportDescription: String
        let instruction: String
        let notice: String?
        let distance: CLLocationDistance

        init(
            id: UUID = UUID(),
            kind: Kind = .step,
            transportDescription: String,
            instruction: String,
            notice: String? = nil,
            distance: CLLocationDistance
        ) {
            self.id = id
            self.kind = kind
            self.transportDescription = transportDescription
            self.instruction = instruction
            self.notice = notice
            self.distance = distance
        }
    }

    let id: UUID
    let from: TripStop
    let to: TripStop
    let requestedTravelMode: TravelMode
    let travelMode: TravelMode
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let polyline: MKPolyline
    let routeName: String?
    let details: [Detail]
    let representation: Representation
    let mapRenderStyle: MapRenderStyle

    var hasWarnings: Bool {
        details.contains { $0.kind == .warning }
    }

    var transitRouteReference: TransitRouteReference? {
        guard case .externalTransit(let reference) = representation else { return nil }
        return reference
    }

    var isExternalTransit: Bool {
        transitRouteReference != nil
    }

    var showsOnMap: Bool {
        !isExternalTransit
    }

    var isTransitFallback: Bool {
        requestedTravelMode == .transit && travelMode != .transit
    }

    init(
        id: UUID = UUID(),
        from: TripStop,
        to: TripStop,
        requestedTravelMode: TravelMode? = nil,
        travelMode: TravelMode,
        distance: CLLocationDistance,
        expectedTravelTime: TimeInterval,
        polyline: MKPolyline,
        routeName: String? = nil,
        details: [Detail] = [],
        representation: Representation = .inAppRoute,
        mapRenderStyle: MapRenderStyle = .solid
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.requestedTravelMode = requestedTravelMode ?? travelMode
        self.travelMode = travelMode
        self.distance = distance
        self.expectedTravelTime = expectedTravelTime
        self.polyline = polyline
        self.routeName = routeName
        self.details = details
        self.representation = representation
        self.mapRenderStyle = mapRenderStyle
    }
}
