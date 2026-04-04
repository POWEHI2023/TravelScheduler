import Foundation
import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class TripPlannerViewModel {
    struct StatusMessage: Equatable {
        enum Tone: Equatable {
            case info
            case success
            case warning
            case error
        }

        let tone: Tone
        let message: String
    }

    struct RouteLegPlan: Identifiable {
        let leg: TripPlanDraft.RouteLeg
        let index: Int
        let fromName: String
        let toName: String

        var id: String {
            leg.id
        }
    }

    var cameraPosition: MapCameraPosition = .automatic
    private(set) var searchText = ""
    private(set) var searchResults: [MKMapItem] = []
    private(set) var plannedStops: [TripStop] = []
    private(set) var routeSegments: [RouteSegment] = []
    private(set) var hiddenSegmentIDs: Set<UUID> = []
    private(set) var isSearching = false
    private(set) var isPlanningRoute = false
    private(set) var searchStatus: StatusMessage?
    private(set) var routeStatus: StatusMessage?
    private(set) var startStopID: UUID?
    private(set) var endStopID: UUID?
    private(set) var loopToStart = false

    private let defaultSegmentMode: TravelMode = .driving
    private let placeSearchService: PlaceSearchServing
    private let routePlanningService: RoutePlanningServing
    private let routeInvalidationStatus = "请重新生成路线。"

    private var segmentModesByLeg: [TripPlanDraft.RouteLeg: TravelMode] = [:]
    private var pendingSearchTask: Task<Void, Never>?
    private var pendingRouteTask: Task<[RouteSegment], Error>?
    private var activeSearchKeyword: String?
    private var activeRouteRequestID = UUID()

    init(
        placeSearchService: PlaceSearchServing? = nil,
        routePlanningService: RoutePlanningServing? = nil
    ) {
        self.placeSearchService = placeSearchService ?? MapKitPlaceSearchService()
        self.routePlanningService = routePlanningService ?? MapKitRoutePlanningService()
    }

    var totalDistance: CLLocationDistance {
        routeSegments.reduce(0) { $0 + $1.distance }
    }

    var totalTravelTime: TimeInterval {
        routeSegments.reduce(0) { $0 + $1.expectedTravelTime }
    }

    var hasExternalTransitSegments: Bool {
        routeSegments.contains(where: \.isExternalTransit)
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
        currentDraft.canGenerateRoute
    }

    var routeLegPlans: [RouteLegPlan] {
        let orderedStops = currentDraft.orderedStops
        guard orderedStops.count >= 2 else { return [] }

        return (0..<(orderedStops.count - 1)).map { index in
            RouteLegPlan(
                leg: TripPlanDraft.RouteLeg(
                    fromStopID: orderedStops[index].id,
                    toStopID: orderedStops[index + 1].id
                ),
                index: index,
                fromName: orderedStops[index].name,
                toName: orderedStops[index + 1].name
            )
        }
    }

    var routeOrderDescription: String? {
        currentDraft.routeOrderDescription
    }

    var routeDetailsButtonTitle: String {
        "查看分段路线（\(routeSegments.count)段）"
    }

    func makeRoutePlanMarkdownDocument(generatedAt: Date = .now) -> String {
        let draft = currentDraft
        var lines: [String] = []

        lines.append("# 路线规划")
        lines.append("")
        lines.append("## 概览")
        lines.append("")
        lines.append("- 生成时间：\(AppFormatters.timestamp(generatedAt))")
        lines.append("- 起点：\(draft.normalizedStartStop?.name ?? "未设置")")
        lines.append("- 终点：\(draft.normalizedEndStop?.name ?? "未设置")")
        lines.append("- 是否环线：\(loopToStart ? "是" : "否")")

        if let routeOrderDescription {
            lines.append("- 路线顺序：\(routeOrderDescription)")
        }

        if !routeSegments.isEmpty {
            lines.append("- 总时长：\(AppFormatters.duration(totalTravelTime))")
            if hasExternalTransitSegments {
                lines.append("- 总路程：\(AppFormatters.distance(totalDistance))（不含需在 Apple 地图中查看的公共交通实际轨迹）")
            } else {
                lines.append("- 总路程：\(AppFormatters.distance(totalDistance))")
            }
        }

        if let routeStatus {
            lines.append("- 当前状态：\(routeStatus.message)")
        }

        lines.append("- 行程建议：\(travelSuggestion)")
        lines.append("")
        lines.append("## 地点列表")
        lines.append("")

        if plannedStops.isEmpty {
            lines.append("- 暂无地点")
        } else {
            for (index, stop) in plannedStops.enumerated() {
                let roleSuffix = stopRoleSuffix(for: stop, draft: draft)
                lines.append("\(index + 1). \(stop.name)\(roleSuffix)")

                let trimmedSubtitle = stop.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedSubtitle.isEmpty {
                    lines.append("   - 地址：\(trimmedSubtitle)")
                }
            }
        }

        lines.append("")
        lines.append("## 分段规划")
        lines.append("")

        if routeSegments.isEmpty {
            lines.append("- 暂无已生成路线。")
        } else {
            for (index, segment) in routeSegments.enumerated() {
                lines.append("### 第\(index + 1)段")
                lines.append("")
                lines.append("- 起止：\(segment.from.name) → \(segment.to.name)")
                lines.append("- 通行方式：\(segmentModeDescription(for: segment))")
                lines.append("- 通行时间：\(AppFormatters.duration(segment.expectedTravelTime))")

                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    private var currentDraft: TripPlanDraft {
        TripPlanDraft(
            plannedStops: plannedStops,
            selectedStartStopID: startStopID,
            selectedEndStopID: endStopID,
            loopToStart: loopToStart
        )
    }

    // MARK: - Lifecycle

    func onDisappear() {
        pendingSearchTask?.cancel()
        placeSearchService.cancelActiveSearch()
        cancelPendingRouteGeneration()
    }

    // MARK: - Search

    func updateSearchText(_ newValue: String) {
        searchText = newValue
        scheduleAutoSearch(for: newValue)
    }

    // MARK: - Endpoint and Segment State

    func updateStartStopID(_ newStartID: UUID?) {
        startStopID = newStartID
        if loopToStart {
            endStopID = newStartID
        }

        let adjustmentMessage = normalizePlanState()
        invalidateRoute(
            message: composeRouteMessage(
                baseMessage: "起点已更新。",
                adjustmentMessage: adjustmentMessage
            )
        )
    }

    func updateEndStopID(_ newEndID: UUID?) {
        endStopID = newEndID

        let adjustmentMessage = normalizePlanState()
        invalidateRoute(
            message: composeRouteMessage(
                baseMessage: "终点已更新。",
                adjustmentMessage: adjustmentMessage
            )
        )
    }

    func updateLoopToStart(_ enabled: Bool) {
        loopToStart = enabled
        if enabled {
            endStopID = startStopID
        } else {
            endStopID = preferredEndStopIDAfterDisablingLoop()
        }

        let adjustmentMessage = normalizePlanState()
        let baseMessage = enabled ? "已切换为环线。" : "已取消环线，请确认终点。"
        invalidateRoute(
            message: composeRouteMessage(
                baseMessage: baseMessage,
                adjustmentMessage: adjustmentMessage
            )
        )
    }

    func toggleSegmentVisibility(_ segmentID: UUID) {
        if hiddenSegmentIDs.contains(segmentID) {
            hiddenSegmentIDs.remove(segmentID)
        } else {
            hiddenSegmentIDs.insert(segmentID)
        }
    }

    func modeForLeg(_ leg: TripPlanDraft.RouteLeg) -> TravelMode {
        segmentModesByLeg[leg] ?? defaultSegmentMode
    }

    func setMode(_ mode: TravelMode, for leg: TripPlanDraft.RouteLeg) {
        if mode == defaultSegmentMode {
            segmentModesByLeg.removeValue(forKey: leg)
        } else {
            segmentModesByLeg[leg] = mode
        }

        invalidateRoute(
            message: composeRouteMessage(
                baseMessage: "分段通行方式已更新。",
                adjustmentMessage: nil
            )
        )
    }

    // MARK: - Stop Management

    func addStop(from item: MKMapItem) {
        let newStop = TripStop(
            name: item.name ?? "未命名地点",
            subtitle: item.displayAddress,
            mapItem: item
        )

        let isDuplicate = plannedStops.contains { $0.isSemanticallyDuplicate(of: newStop) }
        guard !isDuplicate else {
            searchStatus = StatusMessage(tone: .info, message: "该地点已在行程中。")
            return
        }

        plannedStops.append(newStop)
        clearSearchState(
            message: StatusMessage(tone: .success, message: "已添加：\(newStop.name)。")
        )

        let adjustmentMessage = normalizePlanState()
        invalidateRoute(
            message: composeRouteMessage(
                baseMessage: "已添加：\(newStop.name)。",
                adjustmentMessage: adjustmentMessage
            )
        )

        cameraPosition = .region(
            MKCoordinateRegion(
                center: newStop.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
            )
        )
    }

    func moveStops(from source: IndexSet, to destination: Int) {
        plannedStops.move(fromOffsets: source, toOffset: destination)

        let adjustmentMessage = normalizePlanState()
        invalidateRoute(
            message: composeRouteMessage(
                baseMessage: "顺序已更新。",
                adjustmentMessage: adjustmentMessage
            )
        )
    }

    func removeStop(at index: Int) {
        guard plannedStops.indices.contains(index) else { return }
        let removedName = plannedStops[index].name
        plannedStops.remove(at: index)

        let adjustmentMessage = normalizePlanState()
        invalidateRoute(
            message: composeRouteMessage(
                baseMessage: "已删除：\(removedName)。",
                adjustmentMessage: adjustmentMessage
            )
        )
    }

    // MARK: - Route Planning

    func generateRoutePlan() async {
        let draft = currentDraft
        guard draft.canGenerateRoute else {
            routeStatus = StatusMessage(
                tone: .info,
                message: "至少需要两个地点才能生成路线。"
            )
            return
        }

        let orderedStops = draft.orderedStops
        let segmentModes = draft.routeLegs.map { segmentModesByLeg[$0] ?? defaultSegmentMode }
        let requestID = UUID()

        cancelPendingRouteGeneration()
        activeRouteRequestID = requestID
        isPlanningRoute = true
        routeStatus = nil

        let task = Task {
            try await routePlanningService.makeSegments(for: orderedStops, segmentModes: segmentModes)
        }
        pendingRouteTask = task

        do {
            let segments = try await task.value
            guard activeRouteRequestID == requestID else { return }

            pendingRouteTask = nil
            isPlanningRoute = false
            routeSegments = segments
            hiddenSegmentIDs.removeAll()

            if segments.isEmpty {
                routeStatus = StatusMessage(
                    tone: .warning,
                    message: "无法计算路线，请尝试更换地点或出行方式。"
                )
            } else if segments.contains(where: \.isTransitFallback) {
                routeStatus = StatusMessage(
                    tone: .warning,
                    message: "部分公共交通分段未找到可用公交方案，已改用步行或驾车。"
                )
                fitMapToPlannedContent()
            } else if segments.contains(where: \.isExternalTransit) {
                routeStatus = StatusMessage(
                    tone: .info,
                    message: "部分公共交通分段需在 Apple 地图中查看详细路线。"
                )
                fitMapToPlannedContent()
            } else if segments.contains(where: \.hasWarnings) {
                routeStatus = StatusMessage(
                    tone: .warning,
                    message: "路线已更新，但部分分段使用了替代方式或直线估算。"
                )
                fitMapToPlannedContent()
            } else {
                routeStatus = StatusMessage(
                    tone: .success,
                    message: "路线已更新，共 \(segments.count) 段。"
                )
                fitMapToPlannedContent()
            }
        } catch {
            guard activeRouteRequestID == requestID else { return }

            pendingRouteTask = nil
            isPlanningRoute = false

            guard !(error is CancellationError) else { return }

            routeSegments = []
            hiddenSegmentIDs.removeAll()
            routeStatus = StatusMessage(
                tone: .error,
                message: "路线计算失败：\(error.localizedDescription)"
            )
        }
    }

    func fitMapToPlannedContent() {
        var rect = MKMapRect.null

        for stop in plannedStops {
            let point = MKMapPoint(stop.coordinate)
            let stopRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
            rect = rect.isNull ? stopRect : rect.union(stopRect)
        }

        for segment in routeSegments {
            let segmentRect = segment.polyline.boundingMapRect
            rect = rect.isNull ? segmentRect : rect.union(segmentRect)
        }

        guard !rect.isNull else { return }

        let paddedRect = rect.insetBy(
            dx: -max(rect.size.width * 0.2, 2000),
            dy: -max(rect.size.height * 0.2, 2000)
        )
        cameraPosition = .rect(paddedRect)
    }

    // MARK: - Helpers

    private func scheduleAutoSearch(for rawText: String) {
        let keyword = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingSearchTask?.cancel()
        placeSearchService.cancelActiveSearch()

        guard !keyword.isEmpty else {
            activeSearchKeyword = nil
            clearSearchState(message: nil)
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

    private func performSearch(keyword: String) async {
        isSearching = true
        searchStatus = nil

        defer {
            if activeSearchKeyword == keyword {
                isSearching = false
            }
        }

        do {
            let items = try await placeSearchService.search(keyword: keyword, limit: 12)
            guard activeSearchKeyword == keyword else { return }

            searchResults = items
            searchStatus = items.isEmpty
                ? StatusMessage(
                    tone: .info,
                    message: "未找到相关地点，请尝试更具体的关键词。"
                )
                : nil
        } catch {
            guard !Task.isCancelled else { return }
            guard activeSearchKeyword == keyword else { return }

            searchResults = []
            searchStatus = StatusMessage(
                tone: .error,
                message: "搜索失败：\(error.localizedDescription)"
            )
        }
    }

    private func clearSearchState(message: StatusMessage?) {
        pendingSearchTask?.cancel()
        placeSearchService.cancelActiveSearch()
        searchText = ""
        activeSearchKeyword = nil
        searchResults = []
        isSearching = false
        searchStatus = message
    }

    private func normalizePlanState() -> String? {
        let draft = currentDraft
        let normalizedStartStopID = draft.normalizedStartStopID
        let normalizedEndStopID = draft.normalizedEndStopID
        var messages: [String] = []

        if startStopID != normalizedStartStopID {
            startStopID = normalizedStartStopID
            if let stopName = draft.normalizedStartStop?.name {
                messages.append("起点已调整为\(stopName)")
            }
        }

        if endStopID != normalizedEndStopID {
            endStopID = normalizedEndStopID
            if let stopName = draft.normalizedEndStop?.name {
                let prefix = loopToStart ? "终点已同步为" : "终点已调整为"
                messages.append("\(prefix)\(stopName)")
            }
        }

        let validLegs = Set(draft.routeLegs)
        segmentModesByLeg = segmentModesByLeg.filter { validLegs.contains($0.key) }

        return messages.isEmpty ? nil : messages.joined(separator: "，")
    }

    private func composeRouteMessage(
        baseMessage: String,
        adjustmentMessage: String?
    ) -> String {
        var parts = [baseMessage]
        if let adjustmentMessage {
            parts.append("\(adjustmentMessage)。")
        }
        parts.append(currentDraft.canGenerateRoute ? routeInvalidationStatus : "至少需要两个地点才能生成路线。")
        return parts.joined(separator: "")
    }

    private func stopRoleSuffix(for stop: TripStop, draft: TripPlanDraft) -> String {
        let isStart = stop.id == draft.normalizedStartStopID
        let isEnd = stop.id == draft.normalizedEndStopID

        if isStart && isEnd {
            return "（起点 / 终点）"
        }

        if isStart {
            return "（起点）"
        }

        if isEnd {
            return "（终点）"
        }

        return ""
    }

    private func segmentModeDescription(for segment: RouteSegment) -> String {
        if segment.requestedTravelMode == segment.travelMode {
            return segment.travelMode.rawValue
        }

        return "\(segment.travelMode.rawValue)（原选择：\(segment.requestedTravelMode.rawValue)）"
    }

    private func invalidateRoute(message: String) {
        cancelPendingRouteGeneration()
        routeSegments = []
        hiddenSegmentIDs.removeAll()
        routeStatus = StatusMessage(tone: .info, message: message)
    }

    private func preferredEndStopIDAfterDisablingLoop() -> UUID? {
        if let endStopID, endStopID != startStopID {
            return endStopID
        }

        return plannedStops.reversed().first(where: { $0.id != startStopID })?.id
            ?? plannedStops.last?.id
    }

    private func cancelPendingRouteGeneration() {
        activeRouteRequestID = UUID()
        pendingRouteTask?.cancel()
        pendingRouteTask = nil
        isPlanningRoute = false
    }
}
