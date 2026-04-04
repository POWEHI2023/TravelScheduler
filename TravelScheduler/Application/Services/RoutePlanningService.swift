import Foundation
import MapKit

protocol RoutePlanningServing {
    func makeSegments(for stops: [TripStop], segmentModes: [TravelMode]) async throws -> [RouteSegment]
}

final class MapKitRoutePlanningService: RoutePlanningServing {
    private struct RouteResolution {
        let route: MKRoute
        let resolvedMode: TravelMode
        let warning: String?
    }

    private struct RoutingCandidate {
        let transportType: MKDirectionsTransportType
        let resolvedMode: TravelMode
    }

    private struct SegmentRequestKey: Hashable {
        let fromKey: String
        let toKey: String
        let mode: TravelMode
    }

    private struct CachedSegmentEntry {
        let segment: RouteSegment
        let expiresAt: Date
        var lastAccessedAt: Date
    }

    private let stableSegmentCacheTTL: TimeInterval = 15 * 60
    private let dynamicSegmentCacheTTL: TimeInterval = 5 * 60
    private let degradedSegmentCacheTTL: TimeInterval = 3 * 60
    private let maxCachedSegments = 120
    private let cacheLock = NSLock()
    private var cachedSegments: [SegmentRequestKey: CachedSegmentEntry] = [:]

    func makeSegments(for stops: [TripStop], segmentModes: [TravelMode]) async throws -> [RouteSegment] {
        guard stops.count >= 2 else { return [] }

        let now = Date()
        pruneExpiredCacheEntries(now: now)

        var segments: [RouteSegment] = []
        segments.reserveCapacity(stops.count - 1)

        for index in 0..<(stops.count - 1) {
            let sourceStop = stops[index]
            let destinationStop = stops[index + 1]
            let mode = modeForSegment(at: index, segmentModes: segmentModes)
            let cacheKey = SegmentRequestKey(
                fromKey: sourceStop.routeCacheKey,
                toKey: destinationStop.routeCacheKey,
                mode: mode
            )

            if let cachedSegment = resolveCachedSegment(for: cacheKey, now: now) {
                segments.append(cachedSegment)
                continue
            }

            let computedSegment = try await makeSegment(
                from: sourceStop,
                to: destinationStop,
                preferredMode: mode
            )

            cacheSegment(computedSegment, for: cacheKey)

            segments.append(computedSegment)
        }

        return segments
    }

    private func makeSegment(
        from sourceStop: TripStop,
        to destinationStop: TripStop,
        preferredMode: TravelMode
    ) async throws -> RouteSegment {
        if sameCoordinate(sourceStop.coordinate, destinationStop.coordinate) {
            return makeSameCoordinateSegment(
                from: sourceStop,
                to: destinationStop,
                requestedTravelMode: preferredMode
            )
        }

        switch preferredMode {
        case .transit:
            return try await makeTransitSegment(from: sourceStop, to: destinationStop)
        case .walking, .driving:
            return try await makeInAppSegment(
                from: sourceStop,
                to: destinationStop,
                preferredMode: preferredMode
            )
        }
    }

    private func makeInAppSegment(
        from sourceStop: TripStop,
        to destinationStop: TripStop,
        preferredMode: TravelMode
    ) async throws -> RouteSegment {
        do {
            if let resolved = try await resolveRoute(
                from: sourceStop,
                to: destinationStop,
                preferredMode: preferredMode
            ) {
                return makeResolvedSegment(
                    from: sourceStop,
                    to: destinationStop,
                    requestedTravelMode: preferredMode,
                    resolution: resolved
                )
            }

            return makeFallbackSegment(
                from: sourceStop,
                to: destinationStop,
                requestedTravelMode: preferredMode,
                mode: preferredMode,
                warning: L10n.routeServiceStraightLineFallback
            )
        } catch {
            if error is CancellationError {
                throw error
            }

            return makeFallbackSegment(
                from: sourceStop,
                to: destinationStop,
                requestedTravelMode: preferredMode,
                mode: preferredMode,
                warning: L10n.routeServiceStraightLineAfterReason(
                    reasonText(for: error, preferredMode: preferredMode)
                )
            )
        }
    }

    private func makeTransitSegment(
        from sourceStop: TripStop,
        to destinationStop: TripStop
    ) async throws -> RouteSegment {
        do {
            if let eta = try await resolveTransitETA(from: sourceStop, to: destinationStop) {
                return makeExternalTransitSegment(
                    from: sourceStop,
                    to: destinationStop,
                    expectedTravelTime: eta
                )
            }
        } catch {
            if error is CancellationError {
                throw error
            }
        }

        if let fallbackSegment = try await resolveTransitFallbackSegment(
            from: sourceStop,
            to: destinationStop
        ) {
            return fallbackSegment
        }

        return makeFallbackSegment(
            from: sourceStop,
            to: destinationStop,
            requestedTravelMode: .transit,
            mode: .transit,
            warning: L10n.routeServiceTransitNoSolutionNoFallback,
            mapRenderStyle: .connector
        )
    }

    private func modeForSegment(at index: Int, segmentModes: [TravelMode]) -> TravelMode {
        guard segmentModes.indices.contains(index) else { return .driving }
        return segmentModes[index]
    }

    private func sameCoordinate(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.00001 && abs(lhs.longitude - rhs.longitude) < 0.00001
    }

    private func resolveRoute(
        from sourceStop: TripStop,
        to destinationStop: TripStop,
        preferredMode: TravelMode
    ) async throws -> RouteResolution? {
        let candidates = routingCandidates(for: preferredMode)
        var lastError: Error?

        for (index, candidate) in candidates.enumerated() {
            do {
                guard let route = try await calculateRoute(
                    from: sourceStop,
                    to: destinationStop,
                    transportType: candidate.transportType
                ) else {
                    continue
                }

                let warning: String?
                if index == 0 {
                    warning = nil
                } else {
                    warning = L10n.routeServicePreferredFallback(
                        preferredMode: preferredMode.localizedName,
                        resolvedMode: candidate.resolvedMode.localizedName
                    )
                }

                return RouteResolution(
                    route: route,
                    resolvedMode: candidate.resolvedMode,
                    warning: warning
                )
            } catch {
                if error is CancellationError {
                    throw error
                }

                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }

        return nil
    }

    private func resolveTransitFallbackSegment(
        from sourceStop: TripStop,
        to destinationStop: TripStop
    ) async throws -> RouteSegment? {
        for fallbackMode in [TravelMode.walking, .driving] {
            do {
                guard let route = try await calculateRoute(
                    from: sourceStop,
                    to: destinationStop,
                    transportType: transportType(for: fallbackMode)
                ) else {
                    continue
                }

                let resolution = RouteResolution(
                    route: route,
                    resolvedMode: fallbackMode,
                    warning: L10n.routeServiceTransitFallbackMode(fallbackMode.localizedName)
                )

                return makeResolvedSegment(
                    from: sourceStop,
                    to: destinationStop,
                    requestedTravelMode: .transit,
                    resolution: resolution
                )
            } catch {
                if error is CancellationError {
                    throw error
                }
            }
        }

        return nil
    }

    private func routingCandidates(for preferredMode: TravelMode) -> [RoutingCandidate] {
        switch preferredMode {
        case .walking:
            return [
                RoutingCandidate(transportType: .walking, resolvedMode: .walking),
                RoutingCandidate(transportType: .automobile, resolvedMode: .driving)
            ]
        case .driving:
            return [
                RoutingCandidate(transportType: .automobile, resolvedMode: .driving)
            ]
        case .transit:
            return []
        }
    }

    private func makeResolvedSegment(
        from sourceStop: TripStop,
        to destinationStop: TripStop,
        requestedTravelMode: TravelMode,
        resolution: RouteResolution
    ) -> RouteSegment {
        RouteSegment(
            from: sourceStop,
            to: destinationStop,
            requestedTravelMode: requestedTravelMode,
            travelMode: resolution.resolvedMode,
            distance: resolution.route.distance,
            expectedTravelTime: resolution.route.expectedTravelTime,
            polyline: resolution.route.polyline,
            routeName: resolution.route.name.nilIfBlank,
            details: detailsWithWarning(
                baseDetails: makeSegmentDetails(
                    from: resolution.route,
                    resolvedMode: resolution.resolvedMode
                ),
                warning: resolution.warning
            ),
            representation: .inAppRoute,
            mapRenderStyle: .solid
        )
    }

    private func makeExternalTransitSegment(
        from sourceStop: TripStop,
        to destinationStop: TripStop,
        expectedTravelTime: TimeInterval
    ) -> RouteSegment {
        let transitReference = TransitRouteReference(
            launchURL: appleMapsTransitURL(from: sourceStop, to: destinationStop),
            preferredModes: TransitRouteReference.defaultPreferredModes,
            estimatedTravelTime: expectedTravelTime
        )

        return RouteSegment(
            from: sourceStop,
            to: destinationStop,
            requestedTravelMode: .transit,
            travelMode: .transit,
            distance: 0,
            expectedTravelTime: expectedTravelTime,
            polyline: directPolyline(from: sourceStop, to: destinationStop),
            routeName: L10n.routeServiceAppleMapsTransitRouteName,
            details: [],
            representation: .externalTransit(transitReference),
            mapRenderStyle: .connector
        )
    }

    private func makeSameCoordinateSegment(
        from sourceStop: TripStop,
        to destinationStop: TripStop,
        requestedTravelMode: TravelMode
    ) -> RouteSegment {
        return RouteSegment(
            from: sourceStop,
            to: destinationStop,
            requestedTravelMode: requestedTravelMode,
            travelMode: requestedTravelMode,
            distance: 0,
            expectedTravelTime: 0,
            polyline: directPolyline(from: sourceStop, to: destinationStop),
            details: [makeWarningDetail(L10n.routeServiceSameCoordinate)],
            representation: .inAppRoute,
            mapRenderStyle: requestedTravelMode == .transit ? .connector : .solid
        )
    }

    private func makeFallbackSegment(
        from sourceStop: TripStop,
        to destinationStop: TripStop,
        requestedTravelMode: TravelMode,
        mode: TravelMode,
        warning: String,
        mapRenderStyle: RouteSegment.MapRenderStyle = .solid
    ) -> RouteSegment {
        let distance = directDistance(from: sourceStop, to: destinationStop)
        let estimatedTime = distance / estimatedSpeed(for: mode)

        return RouteSegment(
            from: sourceStop,
            to: destinationStop,
            requestedTravelMode: requestedTravelMode,
            travelMode: mode,
            distance: distance,
            expectedTravelTime: estimatedTime,
            polyline: directPolyline(from: sourceStop, to: destinationStop),
            details: [makeWarningDetail(warning)],
            representation: .inAppRoute,
            mapRenderStyle: mapRenderStyle
        )
    }

    private func resolveTransitETA(
        from sourceStop: TripStop,
        to destinationStop: TripStop
    ) async throws -> TimeInterval? {
        let directions = MKDirections(
            request: makeDirectionsRequest(
                from: sourceStop,
                to: destinationStop,
                transportType: .transit
            )
        )

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                directions.calculateETA { response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    continuation.resume(returning: response?.expectedTravelTime)
                }
            }
        } onCancel: {
            directions.cancel()
        }
    }

    private func calculateRoute(
        from sourceStop: TripStop,
        to destinationStop: TripStop,
        transportType: MKDirectionsTransportType
    ) async throws -> MKRoute? {
        let directions = MKDirections(
            request: makeDirectionsRequest(
                from: sourceStop,
                to: destinationStop,
                transportType: transportType
            )
        )

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                directions.calculate { response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    continuation.resume(returning: response?.routes.first)
                }
            }
        } onCancel: {
            directions.cancel()
        }
    }

    private func makeDirectionsRequest(
        from sourceStop: TripStop,
        to destinationStop: TripStop,
        transportType: MKDirectionsTransportType
    ) -> MKDirections.Request {
        let request = MKDirections.Request()
        request.source = sourceStop.mapItem
        request.destination = destinationStop.mapItem
        request.transportType = transportType
        request.requestsAlternateRoutes = false
        return request
    }

    private func transportType(for mode: TravelMode) -> MKDirectionsTransportType {
        switch mode {
        case .walking:
            return .walking
        case .driving:
            return .automobile
        case .transit:
            return .transit
        }
    }

    private func directPolyline(from sourceStop: TripStop, to destinationStop: TripStop) -> MKPolyline {
        let coordinates = [sourceStop.coordinate, destinationStop.coordinate]
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }

    private func directDistance(from sourceStop: TripStop, to destinationStop: TripStop) -> CLLocationDistance {
        CLLocation(
            latitude: sourceStop.coordinate.latitude,
            longitude: sourceStop.coordinate.longitude
        )
        .distance(
            from: CLLocation(
                latitude: destinationStop.coordinate.latitude,
                longitude: destinationStop.coordinate.longitude
            )
        )
    }

    private func appleMapsTransitURL(from sourceStop: TripStop, to destinationStop: TripStop) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.path = "/directions"
        components.queryItems = [
            URLQueryItem(name: "source", value: sourceStop.mapsCoordinateQueryValue),
            URLQueryItem(name: "destination", value: destinationStop.mapsCoordinateQueryValue),
            URLQueryItem(name: "mode", value: "transit"),
            URLQueryItem(
                name: "transit-preferences",
                value: TransitRouteReference.defaultPreferredModes.map(\.queryValue).joined(separator: ",")
            )
        ]

        if let url = components.url {
            return url
        }

        assertionFailure("Failed to build Apple Maps transit URL")
        return URL(string: "https://maps.apple.com") ?? URL(fileURLWithPath: "/")
    }

    private func estimatedSpeed(for mode: TravelMode) -> CLLocationSpeed {
        switch mode {
        case .walking:
            return 1.4
        case .transit:
            return 6.0
        case .driving:
            return 13.9
        }
    }

    private func reasonText(for error: Error?, preferredMode: TravelMode) -> String {
        guard let error else { return L10n.routeServiceModeUnavailable(preferredMode.localizedName) }
        guard let mkError = error as? MKError else {
            return L10n.routeServiceModeFailed(preferredMode.localizedName)
        }

        switch mkError.code {
        case .directionsNotFound:
            return L10n.routeServiceModeNotFound(preferredMode.localizedName)
        case .loadingThrottled:
            return L10n.routeServiceRequestThrottled
        case .serverFailure:
            return L10n.routeServiceUnavailable
        default:
            return L10n.routeServiceModeFailed(preferredMode.localizedName)
        }
    }

    private func makeWarningDetail(_ warning: String) -> RouteSegment.Detail {
        RouteSegment.Detail(
            kind: .warning,
            transportDescription: L10n.commonWarningLabel,
            instruction: warning,
            distance: 0
        )
    }

    private func detailsWithWarning(
        baseDetails: [RouteSegment.Detail],
        warning: String?
    ) -> [RouteSegment.Detail] {
        guard let warning else { return baseDetails }
        return [makeWarningDetail(warning)] + baseDetails
    }

    private func makeSegmentDetails(
        from route: MKRoute,
        resolvedMode: TravelMode
    ) -> [RouteSegment.Detail] {
        route.steps.compactMap { step in
            let instruction = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            let notice = step.notice?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedNotice = notice?.isEmpty == true ? nil : notice

            guard !instruction.isEmpty || normalizedNotice != nil else { return nil }

            return RouteSegment.Detail(
                kind: .step,
                transportDescription: transportDescription(
                    for: step.transportType,
                    resolvedMode: resolvedMode
                ),
                instruction: instruction.isEmpty ? L10n.routeServiceContinueToDestination : instruction,
                notice: normalizedNotice,
                distance: step.distance
            )
        }
    }

    private func resolveCachedSegment(
        for key: SegmentRequestKey,
        now: Date
    ) -> RouteSegment? {
        withCacheLock {
            guard var cachedEntry = cachedSegments[key] else { return nil }
            guard cachedEntry.expiresAt >= now else {
                cachedSegments.removeValue(forKey: key)
                return nil
            }

            cachedEntry.lastAccessedAt = now
            cachedSegments[key] = cachedEntry
            return cachedEntry.segment
        }
    }

    private func pruneExpiredCacheEntries(now: Date) {
        withCacheLock {
            cachedSegments = cachedSegments.filter {
                $0.value.expiresAt >= now
            }
        }
    }

    private func cacheSegment(
        _ segment: RouteSegment,
        for key: SegmentRequestKey
    ) {
        let now = Date()
        let entry = CachedSegmentEntry(
            segment: segment,
            expiresAt: now.addingTimeInterval(cacheTTL(for: segment)),
            lastAccessedAt: now
        )

        withCacheLock {
            cachedSegments[key] = entry
        }
        evictLeastRecentlyUsedEntriesIfNeeded()
    }

    private func cacheTTL(for segment: RouteSegment) -> TimeInterval {
        if segment.hasWarnings {
            return degradedSegmentCacheTTL
        }

        if segment.isExternalTransit || segment.travelMode == .driving {
            return dynamicSegmentCacheTTL
        }

        return stableSegmentCacheTTL
    }

    private func evictLeastRecentlyUsedEntriesIfNeeded() {
        withCacheLock {
            let overflowCount = cachedSegments.count - maxCachedSegments
            guard overflowCount > 0 else { return }

            let keysToEvict = cachedSegments
                .sorted { $0.value.lastAccessedAt < $1.value.lastAccessedAt }
                .prefix(overflowCount)
                .map(\.key)

            keysToEvict.forEach { cachedSegments.removeValue(forKey: $0) }
        }
    }

    private func transportDescription(
        for transportType: MKDirectionsTransportType,
        resolvedMode: TravelMode
    ) -> String {
        if transportType.contains(.automobile) {
            return TravelMode.driving.localizedName
        }

        if transportType.contains(.walking) {
            return TravelMode.walking.localizedName
        }

        if transportType.contains(.transit) {
            return TravelMode.transit.localizedName
        }

        return resolvedMode.localizedName
    }

    private func withCacheLock<T>(_ body: () -> T) -> T {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return body()
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
