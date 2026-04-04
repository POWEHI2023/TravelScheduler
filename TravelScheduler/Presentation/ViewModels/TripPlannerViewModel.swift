import Foundation
import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class TripPlannerViewModel {
    var cameraPosition: MapCameraPosition = .automatic
    var searchText = ""
    private(set) var searchResults: [MKMapItem] = []
    private(set) var plannedStops: [TripStop] = []
    private(set) var routeSegments: [RouteSegment] = []
    private(set) var hiddenSegmentIDs: Set<UUID> = []

    var selectedMode: TravelMode = .driving
    private(set) var isSearching = false
    private(set) var isPlanningRoute = false
    var statusMessage: String?

    var startStopID: UUID?
    var endStopID: UUID?
    var loopToStart = false

    var totalDistance: CLLocationDistance {
        routeSegments.reduce(0) { $0 + $1.distance }
    }

    var totalTravelTime: TimeInterval {
        routeSegments.reduce(0) { $0 + $1.expectedTravelTime }
    }

    var travelSuggestion: String {
        guard !routeSegments.isEmpty else { return "添加至少两个地点后可生成路线建议" }

        let hours = totalTravelTime / 3600
        switch hours {
        case ..<2:
            return "建议：这条路线适合半日轻量行程。"
        case 2..<6:
            return "建议：这条路线适合一天内完成。"
        default:
            return "建议：这条路线较长，建议分两天或增加中途休息点。"
        }
    }

    var canGenerateRoute: Bool {
        guard let start = resolvedStartStop, let end = resolvedEndStop else { return false }
        if plannedStops.count >= 2 { return true }
        return plannedStops.count == 1 && start.id == end.id
    }

    private var resolvedStartStop: TripStop? {
        if let startStopID,
           let matched = plannedStops.first(where: { $0.id == startStopID }) {
            return matched
        }
        return plannedStops.first
    }

    private var resolvedEndStop: TripStop? {
        if loopToStart {
            return resolvedStartStop
        }

        if let endStopID,
           let matched = plannedStops.first(where: { $0.id == endStopID }) {
            return matched
        }
        return plannedStops.last
    }

    private let placeSearchService: PlaceSearchServing
    private let routePlanningService: RoutePlanningServing

    private var pendingSearchTask: Task<Void, Never>?
    private var activeSearchKeyword: String?

    init(
        placeSearchService: PlaceSearchServing? = nil,
        routePlanningService: RoutePlanningServing? = nil
    ) {
        self.placeSearchService = placeSearchService ?? MapKitPlaceSearchService()
        self.routePlanningService = routePlanningService ?? MapKitRoutePlanningService()
    }

    func onDisappear() {
        pendingSearchTask?.cancel()
    }

    func handleStartStopChanged(_ newStartID: UUID?) {
        if loopToStart {
            endStopID = newStartID
        }
    }

    func handleLoopChange(_ enabled: Bool) {
        if enabled {
            endStopID = startStopID
        }
    }

    func toggleSegmentVisibility(_ segmentID: UUID) {
        if hiddenSegmentIDs.contains(segmentID) {
            hiddenSegmentIDs.remove(segmentID)
        } else {
            hiddenSegmentIDs.insert(segmentID)
        }
    }

    func colorForStop(at index: Int) -> Color {
        RoutePalette.color(at: index)
    }

    func colorForSegment(at index: Int) -> Color {
        RoutePalette.color(at: index)
    }

    func syncRouteEndpointsWithStops() {
        guard !plannedStops.isEmpty else {
            startStopID = nil
            endStopID = nil
            return
        }

        if startStopID == nil || !plannedStops.contains(where: { $0.id == startStopID }) {
            startStopID = plannedStops.first?.id
        }

        if loopToStart {
            endStopID = startStopID
        } else if endStopID == nil || !plannedStops.contains(where: { $0.id == endStopID }) {
            endStopID = plannedStops.last?.id
        }
    }

    func scheduleAutoSearch(for rawText: String) {
        let keyword = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingSearchTask?.cancel()

        guard !keyword.isEmpty else {
            activeSearchKeyword = nil
            searchResults = []
            isSearching = false
            return
        }

        activeSearchKeyword = keyword
        pendingSearchTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.performSearch(keyword: keyword)
        }
    }

    func addStop(from item: MKMapItem) {
        let newStop = TripStop(
            name: item.name ?? "未命名地点",
            subtitle: item.displayAddress,
            mapItem: item
        )

        let isDuplicate = plannedStops.contains { $0.isSemanticallyDuplicate(of: newStop) }
        guard !isDuplicate else {
            statusMessage = "该地点已在行程中。"
            return
        }

        plannedStops.append(newStop)
        clearComputedRoute(message: "已添加：\(newStop.name)。请在设置中调整起终点与顺序。")

        cameraPosition = .region(
            MKCoordinateRegion(
                center: newStop.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
            )
        )
    }

    func moveStops(from source: IndexSet, to destination: Int) {
        plannedStops.move(fromOffsets: source, toOffset: destination)
        clearComputedRoute(message: "顺序已更新，请重新生成路线。")
    }

    func deleteStops(at offsets: IndexSet) {
        plannedStops.remove(atOffsets: offsets)
        clearComputedRoute(message: "已删除地点，请重新生成路线。")
    }

    func generateRoutePlan() async {
        let routeStops = buildRouteStopsInOrder()
        guard routeStops.count >= 2 else {
            statusMessage = "请至少设置一个起点和一个终点。"
            return
        }

        isPlanningRoute = true
        statusMessage = nil

        do {
            let segments = try await routePlanningService.makeSegments(for: routeStops, mode: selectedMode)
            routeSegments = segments
            hiddenSegmentIDs.removeAll()

            if segments.isEmpty {
                statusMessage = "无法计算路线，请尝试更换地点或出行方式。"
            } else {
                statusMessage = "路线已更新，共 \(segments.count) 段。"
                fitMapToPlannedContent()
            }
        } catch {
            routeSegments = []
            hiddenSegmentIDs.removeAll()
            statusMessage = "路线计算失败：\(error.localizedDescription)"
        }

        isPlanningRoute = false
    }

    func fitMapToPlannedContent() {
        var rect = MKMapRect.null

        for stop in plannedStops {
            let point = MKMapPoint(stop.coordinate)
            let stopRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
            rect = rect.isNull ? stopRect : rect.union(stopRect)
        }

        for segment in routeSegments {
            rect = rect.isNull ? segment.polyline.boundingMapRect : rect.union(segment.polyline.boundingMapRect)
        }

        guard !rect.isNull else { return }

        let paddedRect = rect.insetBy(
            dx: -max(rect.size.width * 0.2, 2000),
            dy: -max(rect.size.height * 0.2, 2000)
        )
        cameraPosition = .rect(paddedRect)
    }

    private func performSearch(keyword: String) async {
        isSearching = true
        statusMessage = nil

        defer {
            if activeSearchKeyword == keyword {
                isSearching = false
            }
        }

        do {
            let items = try await placeSearchService.search(keyword: keyword, limit: 12)
            guard activeSearchKeyword == keyword else { return }
            searchResults = items
            if items.isEmpty {
                statusMessage = "未找到相关地点，请尝试更具体的关键词。"
            }
        } catch {
            guard !Task.isCancelled else { return }
            guard activeSearchKeyword == keyword else { return }
            searchResults = []
            statusMessage = "搜索失败：\(error.localizedDescription)"
        }
    }

    private func buildRouteStopsInOrder() -> [TripStop] {
        guard let start = resolvedStartStop, let end = resolvedEndStop else { return [] }

        var ordered: [TripStop] = [start]
        ordered.append(contentsOf: plannedStops.filter { $0.id != start.id && $0.id != end.id })

        if ordered.last?.id != end.id || start.id == end.id {
            ordered.append(end)
        }

        return ordered
    }

    private func clearComputedRoute(message: String) {
        routeSegments = []
        hiddenSegmentIDs.removeAll()
        statusMessage = message
    }
}
