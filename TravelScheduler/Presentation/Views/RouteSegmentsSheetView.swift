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
                                Text("第\(index + 1)段：\(segment.from.name) → \(segment.to.name)")
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
            .navigationTitle("分段路线")
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
            Label("预计时长：\(AppFormatters.duration(segment.expectedTravelTime))", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !normalDetails.isEmpty {
                Button {
                    toggleExpandedDetails(for: segment.id)
                } label: {
                    Label(
                        isExpanded ? "收起详细路线" : "显示详细路线",
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
                Text("暂无更详细步骤信息")
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
            Label("\(transitReference.provider.displayName) 承接详细路线", systemImage: "tram.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let estimatedTravelTime = transitReference.estimatedTravelTime {
                Label("预计时长：\(AppFormatters.duration(estimatedTravelTime))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("偏好：\(transitReference.preferredModesDescription)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Link(destination: transitReference.launchURL) {
                Label("在 Apple 地图中查看", systemImage: "arrow.up.right.square")
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private func segmentSummary(for segment: RouteSegment) -> String {
        if let transitReference = segment.transitRouteReference {
            if let estimatedTravelTime = transitReference.estimatedTravelTime {
                return "\(segment.travelMode.rawValue) · \(AppFormatters.duration(estimatedTravelTime))"
            }
            return "\(segment.travelMode.rawValue) · 详情见 Apple 地图"
        }

        return "\(segment.travelMode.rawValue) · \(AppFormatters.distance(segment.distance)) · \(AppFormatters.duration(segment.expectedTravelTime))"
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
