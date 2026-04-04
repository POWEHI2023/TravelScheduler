import SwiftUI

struct RouteSegmentsSheetView: View {
    let segments: [RouteSegment]

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(RoutePalette.color(at: index))
                            .frame(width: 8, height: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("第\(index + 1)段：\(segment.from.name) → \(segment.to.name)")
                                .font(.subheadline)

                            Text("\(AppFormatters.distance(segment.distance)) · \(AppFormatters.duration(segment.expectedTravelTime))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("分段路线")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
