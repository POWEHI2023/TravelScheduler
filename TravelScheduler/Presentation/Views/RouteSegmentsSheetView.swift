import SwiftUI

struct RouteSegmentsSheetView: View {
    let segments: [RouteSegment]
    @State private var expandedSegmentIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(RoutePalette.color(at: index))
                                .frame(width: 8, height: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    L10n.routeSegmentHeader(
                                        index: index + 1,
                                        from: segment.from.name,
                                        to: segment.to.name
                                    )
                                )
                                    .font(.subheadline)

                                Text(segmentSummary(for: segment))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let warningDetails = warningDetails(for: segment), !warningDetails.isEmpty {
                            warningDetailView(warningDetails)
                        }

                        segmentDetailView(for: segment)
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .contain)
                }
            }
            .navigationTitle(L10n.routeSegmentsTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func segmentDetailView(for segment: RouteSegment) -> some View {
        if let transitReference = segment.transitRouteReference {
            externalTransitDetailView(transitReference)
        } else {
            inAppRouteDetailView(for: segment)
        }
    }

    @ViewBuilder
    private func inAppRouteDetailView(for segment: RouteSegment) -> some View {
        let normalDetails = segment.details.filter { $0.kind == .step }
        let isExpanded = expandedSegmentIDs.contains(segment.id)

        VStack(alignment: .leading, spacing: 8) {
            Label(
                L10n.routeSegmentEstimatedDuration(
                    AppFormatters.duration(segment.expectedTravelTime)
                ),
                systemImage: "clock"
            )
                .font(.caption)
                .foregroundStyle(.secondary)

            if !normalDetails.isEmpty {
                Button {
                    toggleExpandedDetails(for: segment.id)
                } label: {
                    Label(
                        isExpanded ? L10n.routeSegmentHideDetails : L10n.routeSegmentShowDetails,
                        systemImage: isExpanded ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
            }

            if isExpanded, let routeName = segment.routeName {
                Label(routeName, systemImage: "map")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isExpanded && normalDetails.isEmpty {
                Text(L10n.routeSegmentNoDetails)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if isExpanded {
                ForEach(normalDetails) { detail in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(detail.transportDescription) · \(AppFormatters.distance(detail.distance))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(detail.instruction)
                            .font(.caption)

                        if let notice = detail.notice {
                            Text(notice)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 18)
                }
            }
        }
    }

    private func externalTransitDetailView(_ transitReference: TransitRouteReference) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                L10n.routeSegmentProviderHandlesDetails(transitReference.provider.displayName),
                systemImage: "tram.fill"
            )
                .font(.caption)
                .foregroundStyle(.secondary)

            if let estimatedTravelTime = transitReference.estimatedTravelTime {
                Label(
                    L10n.routeSegmentEstimatedDuration(AppFormatters.duration(estimatedTravelTime)),
                    systemImage: "clock"
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(L10n.routeSegmentPreferences(transitReference.preferredModesDescription))
                .font(.caption)
                .foregroundStyle(.secondary)

            Link(destination: transitReference.launchURL) {
                Label(L10n.routeSegmentOpenInAppleMaps, systemImage: "arrow.up.right.square")
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private func segmentSummary(for segment: RouteSegment) -> String {
        if let transitReference = segment.transitRouteReference {
            if let estimatedTravelTime = transitReference.estimatedTravelTime {
                return L10n.routeSegmentSummary(
                    mode: segment.travelMode.localizedName,
                    duration: AppFormatters.duration(estimatedTravelTime)
                )
            }
            return L10n.routeSegmentDetailsInAppleMaps(mode: segment.travelMode.localizedName)
        }

        return L10n.routeSegmentSummary(
            mode: segment.travelMode.localizedName,
            distance: AppFormatters.distance(segment.distance),
            duration: AppFormatters.duration(segment.expectedTravelTime)
        )
    }

    private func warningDetails(for segment: RouteSegment) -> [RouteSegment.Detail]? {
        let items = segment.details.filter { $0.kind == .warning }
        return items.isEmpty ? nil : items
    }

    private func warningDetailView(_ details: [RouteSegment.Detail]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(details) { detail in
                Label(detail.instruction, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func toggleExpandedDetails(for segmentID: UUID) {
        if expandedSegmentIDs.contains(segmentID) {
            expandedSegmentIDs.remove(segmentID)
        } else {
            expandedSegmentIDs.insert(segmentID)
        }
    }
}
