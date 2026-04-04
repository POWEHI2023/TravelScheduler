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
        RoutePlanDocumentBuilder.makeMarkdown(
            context: .init(
                draft: currentDraft,
                routeSegments: routeSegments,
                routeStatusMessage: routeStatus?.message,
                travelSuggestion: travelSuggestion
            ),
            generatedAt: generatedAt
        )
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

        invalidateRouteAfterPlanChange(baseMessage: L10n.routeStartUpdated)
    }

    func updateEndStopID(_ newEndID: UUID?) {
        endStopID = newEndID

        invalidateRouteAfterPlanChange(baseMessage: L10n.routeEndUpdated)
    }

    func updateLoopToStart(_ enabled: Bool) {
        loopToStart = enabled
        if enabled {
            endStopID = startStopID
        } else {
            endStopID = preferredEndStopIDAfterDisablingLoop()
        }

        let baseMessage = enabled ? L10n.routeLoopEnabled : L10n.routeLoopDisabled
        invalidateRouteAfterPlanChange(baseMessage: baseMessage)
    }

    func toggleSegmentVisibility(_ segmentID: UUID) {
        hiddenSegmentIDs.formSymmetricDifference([segmentID])
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

        invalidateRouteAfterPlanChange(
            baseMessage: L10n.routeSegmentModeUpdated,
            shouldNormalizePlanState: false
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

        invalidateRouteAfterPlanChange(baseMessage: L10n.routeAdded(newStop.name))

        cameraPosition = .region(
            MKCoordinateRegion(
                center: newStop.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
            )
        )
    }

    func moveStops(from source: IndexSet, to destination: Int) {
        plannedStops.move(fromOffsets: source, toOffset: destination)

        invalidateRouteAfterPlanChange(baseMessage: L10n.routeOrderUpdated)
    }

    func removeStop(at index: Int) {
        guard plannedStops.indices.contains(index) else { return }
        let removedName = plannedStops[index].name
        plannedStops.remove(at: index)

        invalidateRouteAfterPlanChange(baseMessage: L10n.routeDeleted(removedName))
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

            completeRoutePlanning()
            applyGeneratedRoute(segments)
        } catch {
            guard activeRouteRequestID == requestID else { return }

            completeRoutePlanning()

            guard !(error is CancellationError) else { return }

            clearGeneratedRoute()
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
        searchResults = []
        searchStatus = nil
        isSearching = false
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
        let followup = currentDraft.canGenerateRoute
            ? L10n.routeInvalidationStatus
            : L10n.routeMinimumStops

        if let adjustmentMessage {
            return L10n.routeMessage(
                base: baseMessage,
                adjustment: adjustmentMessage,
                followup: followup
            )
        }

        return L10n.routeMessage(base: baseMessage, followup: followup)
    }

    private func invalidateRouteAfterPlanChange(
        baseMessage: String,
        shouldNormalizePlanState: Bool = true
    ) {
        let adjustmentMessage = shouldNormalizePlanState ? normalizePlanState() : nil
        invalidateRoute(
            message: composeRouteMessage(
                baseMessage: baseMessage,
                adjustmentMessage: adjustmentMessage
            )
        )
    }

    private func applyGeneratedRoute(_ segments: [RouteSegment]) {
        routeSegments = segments
        hiddenSegmentIDs.removeAll()
        routeStatus = statusMessage(for: segments)

        if !segments.isEmpty {
            fitMapToPlannedContent()
        }
    }

    private func statusMessage(for segments: [RouteSegment]) -> StatusMessage {
        if segments.isEmpty {
            return StatusMessage(
                tone: .warning,
                message: L10n.routeCannotCalculate
            )
        }

        if segments.contains(where: \.isTransitFallback) {
            return StatusMessage(
                tone: .warning,
                message: L10n.routeTransitFallbackStatus
            )
        }

        if segments.contains(where: \.isExternalTransit) {
            return StatusMessage(
                tone: .info,
                message: L10n.routeExternalTransitStatus
            )
        }

        if segments.contains(where: \.hasWarnings) {
            return StatusMessage(
                tone: .warning,
                message: L10n.routeUpdatedWithFallback
            )
        }

        return StatusMessage(
            tone: .success,
            message: L10n.routeUpdatedSegments(segments.count)
        )
    }

    private func clearGeneratedRoute() {
        routeSegments = []
        hiddenSegmentIDs.removeAll()
    }

    private func invalidateRoute(message: String) {
        cancelPendingRouteGeneration()
        clearGeneratedRoute()
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
        completeRoutePlanning()
    }

    private func completeRoutePlanning() {
        pendingRouteTask = nil
        isPlanningRoute = false
    }
}
