import Foundation
import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class TripPlannerViewModel {
    private struct CachedSearchEntry {
        let items: [MKMapItem]
        let expiresAt: Date
        var lastAccessedAt: Date
    }

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
    private(set) var loopToStart = false

    private let defaultSegmentMode: TravelMode = .driving
    private let searchDebounceNanoseconds: UInt64 = 280_000_000
    private let searchCacheTTL: TimeInterval = 4 * 60
    private let maxCachedSearchEntries = 24
    private let placeSearchService: PlaceSearchServing
    private let routePlanningService: RoutePlanningServing

    private var segmentModesByLeg: [TripPlanDraft.RouteLeg: TravelMode] = [:]
    private var searchCache: [String: CachedSearchEntry] = [:]
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
            loopToStart: loopToStart
        )
    }

    // MARK: - Lifecycle

    func onDisappear() {
        pendingSearchTask?.cancel()
        placeSearchService.cancelActiveSearch()
        cancelPendingRouteGeneration()
    }

    func onSettingsSheetDisappear() {
        clearSearchState(message: nil)
    }

    // MARK: - Search

    func updateSearchText(_ newValue: String) {
        searchText = newValue
        scheduleAutoSearch(for: newValue)
    }

    // MARK: - Endpoint and Segment State

    func updateLoopToStart(_ enabled: Bool) {
        guard loopToStart != enabled else { return }
        loopToStart = enabled

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
        guard modeForLeg(leg) != mode else { return }

        if mode == defaultSegmentMode {
            segmentModesByLeg.removeValue(forKey: leg)
        } else {
            segmentModesByLeg[leg] = mode
        }

        invalidateRouteAfterPlanChange(
            baseMessage: L10n.routeSegmentModeUpdated
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

    func applyEditedPlannedStops(_ updatedStops: [TripStop]) {
        let previousStops = plannedStops
        let currentStopIDs = previousStops.map(\.id)
        let updatedStopIDs = updatedStops.map(\.id)
        guard currentStopIDs != updatedStopIDs else { return }

        plannedStops = updatedStops

        if previousStops.count == updatedStops.count {
            invalidateRouteAfterPlanChange(baseMessage: L10n.routeOrderUpdated)
            return
        }

        let updatedStopIDSet = Set(updatedStopIDs)
        let removedStops = previousStops.filter { !updatedStopIDSet.contains($0.id) }

        let baseMessage: String
        if removedStops.count == 1 {
            baseMessage = L10n.routeDeleted(removedStops[0].name)
        } else if removedStops.count > 1 {
            baseMessage = L10n.routeDeletedStops(removedStops.count)
        } else {
            baseMessage = L10n.routeOrderUpdated
        }

        invalidateRouteAfterPlanChange(baseMessage: baseMessage)
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

        let task = Task(priority: .userInitiated) {
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
                message: routeErrorMessage(for: error)
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

        for segment in routeSegments where segment.showsOnMap && !hiddenSegmentIDs.contains(segment.id) {
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
        let normalizedKeyword = keyword.lowercased()
        pendingSearchTask?.cancel()
        placeSearchService.cancelActiveSearch()

        guard !keyword.isEmpty else {
            activeSearchKeyword = nil
            clearSearchState(message: nil)
            return
        }

        if activeSearchKeyword == normalizedKeyword, isSearching || !searchResults.isEmpty {
            return
        }

        if let cachedEntry = cachedSearchEntry(for: normalizedKeyword) {
            activeSearchKeyword = normalizedKeyword
            searchResults = cachedEntry.items
            searchStatus = cachedEntry.items.isEmpty
                ? StatusMessage(tone: .info, message: L10n.searchNoResults)
                : nil
            isSearching = false
            return
        }

        activeSearchKeyword = normalizedKeyword
        searchResults = []
        searchStatus = nil
        isSearching = false
        pendingSearchTask = Task(priority: .utility) { [weak self] in
            do {
                try await Task.sleep(nanoseconds: self?.searchDebounceNanoseconds ?? 280_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await self?.performSearch(keyword: keyword, normalizedKeyword: normalizedKeyword)
        }
    }

    private func performSearch(keyword: String, normalizedKeyword: String) async {
        isSearching = true
        searchStatus = nil

        defer {
            if activeSearchKeyword == normalizedKeyword {
                isSearching = false
            }
        }

        do {
            let items = try await placeSearchService.search(keyword: keyword, limit: 12)
            guard activeSearchKeyword == normalizedKeyword else { return }

            searchResults = items
            cacheSearchResults(items, for: normalizedKeyword)
            searchStatus = items.isEmpty
                ? StatusMessage(
                    tone: .info,
                    message: L10n.searchNoResults
                )
                : nil
        } catch {
            guard !Task.isCancelled else { return }
            guard activeSearchKeyword == normalizedKeyword else { return }

            searchResults = []
            searchStatus = StatusMessage(
                tone: .error,
                message: searchErrorMessage(for: error)
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

    private func normalizePlanState() {
        let draft = currentDraft
        let validLegs = Set(draft.routeLegs)
        segmentModesByLeg = segmentModesByLeg.filter { validLegs.contains($0.key) }
    }

    private func composeRouteMessage(baseMessage: String) -> String {
        let followup = currentDraft.canGenerateRoute
            ? L10n.routeInvalidationStatus
            : L10n.routeMinimumStops

        return L10n.routeMessage(base: baseMessage, followup: followup)
    }

    private func invalidateRouteAfterPlanChange(baseMessage: String) {
        normalizePlanState()
        invalidateRoute(message: composeRouteMessage(baseMessage: baseMessage))
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

    private func cancelPendingRouteGeneration() {
        activeRouteRequestID = UUID()
        pendingRouteTask?.cancel()
        completeRoutePlanning()
    }

    private func completeRoutePlanning() {
        pendingRouteTask = nil
        isPlanningRoute = false
    }

    private func cachedSearchEntry(for normalizedKeyword: String) -> CachedSearchEntry? {
        let now = Date()
        if var entry = searchCache[normalizedKeyword], entry.expiresAt >= now {
            entry.lastAccessedAt = now
            searchCache[normalizedKeyword] = entry
            return entry
        }

        if searchCache[normalizedKeyword] != nil {
            searchCache.removeValue(forKey: normalizedKeyword)
        }
        return nil
    }

    private func cacheSearchResults(_ items: [MKMapItem], for normalizedKeyword: String) {
        let now = Date()
        searchCache = searchCache.filter { $0.value.expiresAt >= now }
        searchCache[normalizedKeyword] = CachedSearchEntry(
            items: items,
            expiresAt: now.addingTimeInterval(searchCacheTTL),
            lastAccessedAt: now
        )

        let overflowCount = searchCache.count - maxCachedSearchEntries
        guard overflowCount > 0 else { return }

        let keysToRemove = searchCache
            .sorted { lhs, rhs in
                if lhs.value.lastAccessedAt == rhs.value.lastAccessedAt {
                    return lhs.key < rhs.key
                }
                return lhs.value.lastAccessedAt < rhs.value.lastAccessedAt
            }
            .prefix(overflowCount)
            .map(\.key)

        for key in keysToRemove {
            searchCache.removeValue(forKey: key)
        }
    }

    private func searchErrorMessage(for error: Error) -> String {
        guard let mkError = error as? MKError else {
            return L10n.searchFailedGeneric
        }

        switch mkError.code {
        case .placemarkNotFound:
            return L10n.searchNoResults
        case .loadingThrottled:
            return L10n.searchRequestThrottled
        case .serverFailure:
            return L10n.searchServiceUnavailable
        default:
            return L10n.searchFailedGeneric
        }
    }

    private func routeErrorMessage(for error: Error) -> String {
        guard let mkError = error as? MKError else {
            return L10n.routeGenerationFailedGeneric
        }

        switch mkError.code {
        case .directionsNotFound:
            return L10n.routeCannotCalculate
        case .loadingThrottled:
            return L10n.routeGenerationThrottled
        case .serverFailure:
            return L10n.routeGenerationServiceUnavailable
        default:
            return L10n.routeGenerationFailedGeneric
        }
    }
}
