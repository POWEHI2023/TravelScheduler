import SwiftUI

struct RouteLegendView: View {
    let segments: [RouteSegment]
    let hiddenSegmentIDs: Set<UUID>
    let onToggleVisibility: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    let isHidden = hiddenSegmentIDs.contains(segment.id)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(RoutePalette.color(at: index))
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.segmentOrdinal(index + 1))
                                .font(.caption)

                            Text(segment.travelMode.localizedName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if segment.showsOnMap {
                            Button {
                                onToggleVisibility(segment.id)
                            } label: {
                                Image(systemName: isHidden ? "eye.slash" : "eye")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(L10n.routeLegendExternalAccessibility)
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .opacity(segment.showsOnMap && isHidden ? 0.55 : 1.0)
                }
            }
        }
    }
}
