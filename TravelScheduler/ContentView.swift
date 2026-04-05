import MapKit
import SwiftUI

struct ContentView: View {
    @State private var viewModel = TripPlannerViewModel()
    @State private var showPlannerSheet = false
    @State private var showRouteSegmentsSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                mapLayer
                overlayLayer
            }
            .navigationTitle(L10n.contentNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.fitMapToPlannedContent()
                    } label: {
                        Label(L10n.contentLocateRoute, systemImage: "scope")
                    }
                    .disabled(viewModel.plannedStops.isEmpty)
                }
            }
            .sheet(isPresented: $showPlannerSheet, onDismiss: {
                viewModel.onSettingsSheetDisappear()
            }) {
                SettingsSheetView(viewModel: viewModel, isPresented: $showPlannerSheet)
                    .presentationDetents([.large])
                    .presentationContentInteraction(.scrolls)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showRouteSegmentsSheet) {
                RouteSegmentsSheetView(segments: viewModel.routeSegments)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onDisappear {
                viewModel.onDisappear()
            }
        }
    }

    private var mapLayer: some View {
        Map(position: $viewModel.cameraPosition) {
            ForEach(Array(viewModel.plannedStops.enumerated()), id: \.element.id) { index, stop in
                Marker("\(index + 1). \(stop.name)", coordinate: stop.coordinate)
                    .tint(RoutePalette.color(at: index))
            }

            ForEach(Array(viewModel.routeSegments.enumerated()), id: \.element.id) { index, segment in
                if segment.showsOnMap && !viewModel.hiddenSegmentIDs.contains(segment.id) {
                    MapPolyline(segment.polyline)
                        .stroke(
                            RoutePalette.color(at: index),
                            style: strokeStyle(for: segment)
                        )
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControlVisibility(.automatic)
        .mapControls {
            MapCompass()
            MapPitchToggle()
            MapScaleView()
        }
        .ignoresSafeArea()
    }

    private var overlayLayer: some View {
        VStack(spacing: 10) {
            if !viewModel.routeSegments.isEmpty {
                RouteLegendView(
                    segments: viewModel.routeSegments,
                    hiddenSegmentIDs: viewModel.hiddenSegmentIDs,
                    onToggleVisibility: viewModel.toggleSegmentVisibility
                )
                .padding(.top, 8)
            }

            Spacer()

            VStack(spacing: 8) {
                if !viewModel.routeSegments.isEmpty {
                    Button {
                        showRouteSegmentsSheet = true
                    } label: {
                        Text(
                            L10n.routeDetailsButtonTitle(
                                segmentCount: viewModel.routeSegments.count
                            )
                        )
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showPlannerSheet = true
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.tint)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                viewModel.plannedStops.isEmpty
                                    ? L10n.contentOpenPlanner
                                    : L10n.contentEditPlanner
                            )
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(plannerSummaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.up.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                if let routeStatus = viewModel.routeStatus {
                    Label(routeStatus.message, systemImage: routeStatus.tone.systemImage)
                        .font(.footnote)
                        .foregroundStyle(routeStatus.tone.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 12)
    }

    private var plannerSummaryText: String {
        if viewModel.plannedStops.isEmpty {
            return L10n.contentPlannerEmptyHint
        }

        if viewModel.routeSegments.isEmpty {
            return L10n.contentPlannerPlacesSelected(viewModel.plannedStops.count)
        }

        return L10n.contentPlannerRouteReady(
            placeCount: viewModel.plannedStops.count,
            segmentCount: viewModel.routeSegments.count
        )
    }

    private func strokeStyle(for segment: RouteSegment) -> StrokeStyle {
        switch segment.mapRenderStyle {
        case .solid:
            return StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
        case .connector:
            return StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [8, 6])
        }
    }
}

#Preview {
    ContentView()
}
