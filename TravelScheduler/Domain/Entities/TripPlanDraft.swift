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
    let selectedStartStopID: UUID?
    let selectedEndStopID: UUID?
    let loopToStart: Bool

    var normalizedStartStop: TripStop? {
        stop(matching: selectedStartStopID) ?? plannedStops.first
    }

    var normalizedEndStop: TripStop? {
        if loopToStart {
            return normalizedStartStop
        }

        return stop(matching: selectedEndStopID) ?? plannedStops.last
    }

    var normalizedStartStopID: UUID? {
        normalizedStartStop?.id
    }

    var normalizedEndStopID: UUID? {
        normalizedEndStop?.id
    }

    var orderedStops: [TripStop] {
        guard plannedStops.count >= 2,
              let start = normalizedStartStop,
              let end = normalizedEndStop else {
            return []
        }

        var orderedStops = [start]
        let excludedIDs: Set<UUID> = [start.id, end.id]
        orderedStops.append(contentsOf: plannedStops.filter { !excludedIDs.contains($0.id) })

        if start.id != end.id || plannedStops.count > 1 {
            orderedStops.append(end)
        }

        return orderedStops
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

    private func stop(matching stopID: UUID?) -> TripStop? {
        guard let stopID else { return nil }
        return plannedStops.first(where: { $0.id == stopID })
    }
}
