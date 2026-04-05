import Foundation

struct TripPlanDraft {
    struct RouteLeg: Hashable, Identifiable {
        let fromStopID: UUID
        let toStopID: UUID

        var id: String {
            "\(fromStopID.uuidString)->\(toStopID.uuidString)"
        }
    }

    let plannedStops: [TripStop]
    let loopToStart: Bool

    var normalizedStartStop: TripStop? {
        plannedStops.first
    }

    var normalizedEndStop: TripStop? {
        if loopToStart {
            return normalizedStartStop
        }

        return plannedStops.last
    }

    var normalizedStartStopID: UUID? {
        normalizedStartStop?.id
    }

    var normalizedEndStopID: UUID? {
        normalizedEndStop?.id
    }

    var orderedStops: [TripStop] {
        guard plannedStops.count >= 2 else {
            return []
        }

        if loopToStart, let start = normalizedStartStop {
            var orderedStops = plannedStops
            orderedStops.append(start)
            return orderedStops
        }

        return plannedStops
    }

    var routeLegs: [RouteLeg] {
        let orderedStops = orderedStops
        guard orderedStops.count >= 2 else { return [] }

        return (0..<(orderedStops.count - 1)).map { index in
            RouteLeg(
                fromStopID: orderedStops[index].id,
                toStopID: orderedStops[index + 1].id
            )
        }
    }

    var canGenerateRoute: Bool {
        orderedStops.count >= 2
    }

    var routeOrderDescription: String? {
        let names = orderedStops.map(\.name)
        guard names.count >= 2 else { return nil }
        return names.joined(separator: " → ")
    }
}
