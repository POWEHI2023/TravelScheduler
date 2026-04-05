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
        lines.append("- \(L10n.markdownStart(markdownSafeText(context.draft.startStop?.name ?? "—")))")
        lines.append("- \(L10n.markdownEnd(markdownSafeText(context.draft.endStop?.name ?? "—")))")
        lines.append(
            "- \(L10n.markdownIsLoop(context.draft.loopToStart ? L10n.commonYes : L10n.commonNo))"
        )

        if let routeOrderDescription = context.draft.routeOrderDescription {
            lines.append("- \(L10n.markdownRouteOrder(markdownSafeText(routeOrderDescription)))")
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
            lines.append("- \(L10n.markdownCurrentStatus(markdownSafeText(routeStatusMessage)))")
        }

        lines.append("- \(L10n.markdownTravelSuggestion(markdownSafeText(context.travelSuggestion)))")
        lines.append("")
        lines.append("## \(L10n.markdownPlacesSection)")
        lines.append("")

        if context.draft.plannedStops.isEmpty {
            lines.append("- \(L10n.markdownNoPlaces)")
        } else {
            for (index, stop) in context.draft.plannedStops.enumerated() {
                let roleSuffix = stopRoleSuffix(for: stop, draft: context.draft)
                lines.append("\(index + 1). \(markdownSafeText(stop.name))\(roleSuffix)")

                let trimmedSubtitle = markdownSafeText(stop.subtitle)
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
                    "- \(L10n.markdownSegmentStartEnd(from: markdownSafeText(segment.from.name), to: markdownSafeText(segment.to.name)))"
                )
                lines.append("- \(L10n.markdownSegmentMode(markdownSafeText(segmentModeDescription(for: segment))))")
                lines.append(
                    "- \(L10n.markdownSegmentDuration(AppFormatters.duration(segment.expectedTravelTime)))"
                )

                if let routeName = segment.routeName {
                    lines.append("- \(L10n.markdownSegmentRouteName(markdownSafeText(routeName)))")
                }

                if let transitReference = segment.transitRouteReference {
                    lines.append(
                        "- \(L10n.markdownSegmentOpenInProvider(markdownSafeText(transitReference.provider.displayName)))"
                    )
                    lines.append(
                        "- \(L10n.markdownSegmentTransitPreferences(markdownSafeText(transitReference.preferredModesDescription)))"
                    )
                }

                for warning in segment.warningDetails {
                    lines.append(
                        "  - \(L10n.markdownSegmentWarning(markdownSafeText(warning.instruction)))"
                    )
                }

                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func stopRoleSuffix(for stop: TripStop, draft: TripPlanDraft) -> String {
        let isStart = stop.id == draft.startStop?.id
        let isEnd = stop.id == draft.endStop?.id

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

    private static func singleLineText(_ text: String) -> String {
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\t", with: " ")

        return normalizedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func markdownSafeText(_ text: String) -> String {
        escapeMarkdown(in: singleLineText(text))
    }

    private static func escapeMarkdown(in text: String) -> String {
        var escapedText = ""
        escapedText.reserveCapacity(text.count)

        for character in text {
            switch character {
            case "\\", "`", "*", "_", "{", "}", "[", "]", "(", ")", "#", "+", "-", "!", "|", ">":
                escapedText.append("\\")
                escapedText.append(character)
            default:
                escapedText.append(character)
            }
        }

        return escapedText
    }
}
