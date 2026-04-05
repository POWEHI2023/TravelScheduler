import SwiftUI

struct RouteLegendView: View {
    let segments: [RouteSegment]
    let hiddenSegmentIDs: Set<UUID>
    let onToggleVisibility: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    segmentChip(for: segment, at: index)
                }
            }
        }
    }

    @ViewBuilder
    private func segmentChip(for segment: RouteSegment, at index: Int) -> some View {
        let isHidden = hiddenSegmentIDs.contains(segment.id)

        if segment.showsOnMap {
            Button {
                onToggleVisibility(segment.id)
            } label: {
                chipContent(for: segment, at: index, isHidden: isHidden)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isHidden
                    ? L10n.routeLegendShowSegmentAccessibility(
                        index: index + 1,
                        mode: segment.travelMode.localizedName
                    )
                    : L10n.routeLegendHideSegmentAccessibility(
                        index: index + 1,
                        mode: segment.travelMode.localizedName
                    )
            )
            .accessibilityHint(L10n.routeLegendToggleVisibilityHint)
        } else {
            chipContent(for: segment, at: index, isHidden: isHidden)
                .accessibilityLabel(L10n.routeLegendExternalAccessibility)
        }
    }

    private func chipContent(for segment: RouteSegment, at index: Int, isHidden: Bool) -> some View {
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

            Image(
                systemName: segment.showsOnMap
                    ? (isHidden ? "eye.slash.fill" : "eye.fill")
                    : "arrow.up.right.square.fill"
            )
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .contentShape(Capsule())
        .opacity(segment.showsOnMap && isHidden ? 0.55 : 1.0)
    }
}
