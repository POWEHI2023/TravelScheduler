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
    private let routeInvalidationStatus = L10n.routeInvalidationStatus

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
        guard !routeSegments.isEmpty else { return L10n.travelSuggestionNeedsRoute }

        let hours = totalTravelTime / 3600
        switch hours {
        case ..<2:
            return L10n.travelSuggestionHalfDay
        case 2..<6:
            return L10n.travelSuggestionFullDay
        default:
            return L10n.travelSuggestionLong
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
        L10n.routeDetailsButtonTitle(segmentCount: routeSegments.count)
    }

    func makeRoutePlanMarkdownDocument(generatedAt: Date = .now) -> String {
        let draft = currentDraft
        var lines: [String] = []

        lines.append("# \(L10n.markdownTitle)")
        lines.append("")
        lines.append("## \(L10n.markdownOverviewSection)")
        lines.append("")
        lines.append("- \(L10n.markdownGeneratedAt(AppFormatters.timestamp(generatedAt)))")
        lines.append("- \(L10n.markdownStart(draft.normalizedStartStop?.name ?? "—"))")
        lines.append("- \(L10n.markdownEnd(draft.normalizedEndStop?.name ?? "—"))")
        lines.append("- \(L10n.markdownIsLoop(loopToStart ? L10n.commonYes : L10n.commonNo))")

        if let routeOrderDescription {
            lines.append("- \(L10n.markdownRouteOrder(routeOrderDescription))")
        }

        if !routeSegments.isEmpty {
            lines.append("- \(L10n.markdownTotalDuration(AppFormatters.duration(totalTravelTime)))")
            if hasExternalTransitSegments {
                lines.append(
                    "- \(L10n.markdownTotalDistanceTransitNote(AppFormatters.distance(totalDistance)))"
                )
            } else {
                lines.append("- \(L10n.markdownTotalDistance(AppFormatters.distance(totalDistance)))")
            }
        }

        if let routeStatus {
            lines.append("- \(L10n.markdownCurrentStatus(routeStatus.message))")
        }

        lines.append("- \(L10n.markdownTravelSuggestion(travelSuggestion))")
        lines.append("")
        lines.append("## \(L10n.markdownPlacesSection)")
        lines.append("")

        if plannedStops.isEmpty {
            lines.append("- \(L10n.markdownNoPlaces)")
        } else {
            for (index, stop) in plannedStops.enumerated() {
                let roleSuffix = stopRoleSuffix(for: stop, draft: draft)
                lines.append("\(index + 1). \(stop.name)\(roleSuffix)")

                let trimmedSubtitle = stop.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedSubtitle.isEmpty {
                    lines.append("   - \(L10n.markdownAddress(trimmedSubtitle))")
                }
            }
        }

        lines.append("")
        lines.append("## \(L10n.markdownSegmentsSection)")
        lines.append("")

        if routeSegments.isEmpty {
            lines.append("- \(L10n.markdownNoRoute)")
        } else {
            for (index, segment) in routeSegments.enumerated() {
                lines.append("### \(L10n.markdownSegmentTitle(index + 1))")
                lines.append("")
                lines.append(
                    "- \(L10n.markdownSegmentStartEnd(from: segment.from.name, to: segment.to.name))"
                )
                lines.append("- \(L10n.markdownSegmentMode(segmentModeDescription(for: segment)))")
                lines.append(
                    "- \(L10n.markdownSegmentDuration(AppFormatters.duration(segment.expectedTravelTime)))"
                )

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
                baseMessage: L10n.routeStartUpdated,
                adjustmentMessage: adjustmentMessage
            )
        )
    }

    func updateEndStopID(_ newEndID: UUID?) {
        endStopID = newEndID

        let adjustmentMessage = normalizePlanState()
        invalidateRoute(
            message: composeRouteMessage(
                baseMessage: L10n.routeEndUpdated,
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
        let baseMessage = enabled ? L10n.routeLoopEnabled : L10n.routeLoopDisabled
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
                baseMessage: L10n.routeSegmentModeUpdated,
                adjustmentMessage: nil
            )
        )
    }

    // MARK: - Stop Management

    func addStop(from item: MKMapItem) {
        let newStop = TripStop(
            name: item.name ?? L10n.commonUnnamedPlace,
            subtitle: item.displayAddress,
            mapItem: item
        )

        let isDuplicate = plannedStops.contains { $0.isSemanticallyDuplicate(of: newStop) }
        guard !isDuplicate else {
            searchStatus = StatusMessage(tone: .info, message: L10n.searchDuplicatePlace)
            return
        }

        plannedStops.append(newStop)
        clearSearchState(
            message: StatusMessage(tone: .success, message: L10n.routeAdded(newStop.name))
        )

        let adjustmentMessage = normalizePlanState()
        invalidateRoute(
            message: composeRouteMessage(
                baseMessage: L10n.routeAdded(newStop.name),
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
                baseMessage: L10n.routeOrderUpdated,
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
                baseMessage: L10n.routeDeleted(removedName),
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
                message: L10n.routeMinimumStops
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
                    message: L10n.routeCannotCalculate
                )
            } else if segments.contains(where: \.isTransitFallback) {
                routeStatus = StatusMessage(
                    tone: .warning,
                    message: L10n.routeTransitFallbackStatus
                )
                fitMapToPlannedContent()
            } else if segments.contains(where: \.isExternalTransit) {
                routeStatus = StatusMessage(
                    tone: .info,
                    message: L10n.routeExternalTransitStatus
                )
                fitMapToPlannedContent()
            } else if segments.contains(where: \.hasWarnings) {
                routeStatus = StatusMessage(
                    tone: .warning,
                    message: L10n.routeUpdatedWithFallback
                )
                fitMapToPlannedContent()
            } else {
                routeStatus = StatusMessage(
                    tone: .success,
                    message: L10n.routeUpdatedSegments(segments.count)
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
                message: L10n.routeGenerationFailed(error.localizedDescription)
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
                    message: L10n.searchNoResults
                )
                : nil
        } catch {
            guard !Task.isCancelled else { return }
            guard activeSearchKeyword == keyword else { return }

            searchResults = []
            searchStatus = StatusMessage(
                tone: .error,
                message: L10n.searchFailed(error.localizedDescription)
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
                messages.append(L10n.routeStartAdjusted(stopName))
            }
        }

        if endStopID != normalizedEndStopID {
            endStopID = normalizedEndStopID
            if let stopName = draft.normalizedEndStop?.name {
                messages.append(
                    loopToStart
                        ? L10n.routeEndSynced(stopName)
                        : L10n.routeEndAdjusted(stopName)
                )
            }
        }

        let validLegs = Set(draft.routeLegs)
        segmentModesByLeg = segmentModesByLeg.filter { validLegs.contains($0.key) }

        return messages.isEmpty
            ? nil
            : (ListFormatter.localizedString(byJoining: messages) ?? messages.joined(separator: ", "))
    }

    private func composeRouteMessage(
        baseMessage: String,
        adjustmentMessage: String?
    ) -> String {
        let followup = currentDraft.canGenerateRoute ? routeInvalidationStatus : L10n.routeMinimumStops

        if let adjustmentMessage {
            return L10n.routeMessage(
                base: baseMessage,
                adjustment: adjustmentMessage,
                followup: followup
            )
        }

        return L10n.routeMessage(base: baseMessage, followup: followup)
    }

    private func stopRoleSuffix(for stop: TripStop, draft: TripPlanDraft) -> String {
        let isStart = stop.id == draft.normalizedStartStopID
        let isEnd = stop.id == draft.normalizedEndStopID

        if isStart && isEnd {
            return L10n.routeStopRoleStartEnd
        }

        if isStart {
            return L10n.routeStopRoleStart
        }

        if isEnd {
            return L10n.routeStopRoleEnd
        }

        return ""
    }

    private func segmentModeDescription(for segment: RouteSegment) -> String {
        if segment.requestedTravelMode == segment.travelMode {
            return segment.travelMode.localizedName
        }

        return L10n.routeSegmentModeOriginalSelection(
            actual: segment.travelMode.localizedName,
            original: segment.requestedTravelMode.localizedName
        )
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
