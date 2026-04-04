import SwiftUI

struct RouteLegendView: View {
    let segments: [RouteSegment]
    let hiddenSegmentIDs: Set<UUID>
    let onToggle: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    let isHidden = hiddenSegmentIDs.contains(segment.id)

                    Button {
                        onToggle(segment.id)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(RoutePalette.color(at: index))
                                .frame(width: 10, height: 10)

                            Text("第\(index + 1)段")
                                .font(.caption)

                            Image(systemName: isHidden ? "eye.slash" : "eye")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .opacity(isHidden ? 0.55 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
