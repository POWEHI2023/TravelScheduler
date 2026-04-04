import Foundation

enum RoutePlanDocumentBuilder {
    struct Context {
        let draft: TripPlanDraft
        let routeSegments: [RouteSegment]
        let routeStatusMessage: String?
        let travelSuggestion: String
    }

    static func makeMarkdown(
        context: Context,
        generatedAt: Date = .now
    ) -> String {
        let totalDistance = context.routeSegments.reduce(0) { $0 + $1.distance }
        let totalTravelTime = context.routeSegments.reduce(0) { $0 + $1.expectedTravelTime }
        let hasExternalTransitSegments = context.routeSegments.contains(where: \.isExternalTransit)
        var lines: [String] = []

        lines.append("# \(L10n.markdownTitle)")
        lines.append("")
        lines.append("## \(L10n.markdownOverviewSection)")
        lines.append("")
        lines.append("- \(L10n.markdownGeneratedAt(AppFormatters.timestamp(generatedAt)))")
        lines.append("- \(L10n.markdownStart(context.draft.normalizedStartStop?.name ?? "—"))")
        lines.append("- \(L10n.markdownEnd(context.draft.normalizedEndStop?.name ?? "—"))")
        lines.append(
            "- \(L10n.markdownIsLoop(context.draft.loopToStart ? L10n.commonYes : L10n.commonNo))"
        )

        if let routeOrderDescription = context.draft.routeOrderDescription {
            lines.append("- \(L10n.markdownRouteOrder(routeOrderDescription))")
        }

        if !context.routeSegments.isEmpty {
            lines.append("- \(L10n.markdownTotalDuration(AppFormatters.duration(totalTravelTime)))")
            if hasExternalTransitSegments {
                lines.append(
                    "- \(L10n.markdownTotalDistanceTransitNote(AppFormatters.distance(totalDistance)))"
                )
            } else {
                lines.append("- \(L10n.markdownTotalDistance(AppFormatters.distance(totalDistance)))")
            }
        }

        if let routeStatusMessage = context.routeStatusMessage {
            lines.append("- \(L10n.markdownCurrentStatus(routeStatusMessage))")
        }

        lines.append("- \(L10n.markdownTravelSuggestion(context.travelSuggestion))")
        lines.append("")
        lines.append("## \(L10n.markdownPlacesSection)")
        lines.append("")

        if context.draft.plannedStops.isEmpty {
            lines.append("- \(L10n.markdownNoPlaces)")
        } else {
            for (index, stop) in context.draft.plannedStops.enumerated() {
                let roleSuffix = stopRoleSuffix(for: stop, draft: context.draft)
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

        if context.routeSegments.isEmpty {
            lines.append("- \(L10n.markdownNoRoute)")
        } else {
            for (index, segment) in context.routeSegments.enumerated() {
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

    private static func stopRoleSuffix(for stop: TripStop, draft: TripPlanDraft) -> String {
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

    private static func segmentModeDescription(for segment: RouteSegment) -> String {
        if segment.requestedTravelMode == segment.travelMode {
            return segment.travelMode.localizedName
        }

        return L10n.routeSegmentModeOriginalSelection(
            actual: segment.travelMode.localizedName,
            original: segment.requestedTravelMode.localizedName
        )
    }
}
