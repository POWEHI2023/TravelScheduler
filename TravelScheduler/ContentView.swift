import MapKit
import SwiftUI

struct ContentView: View {
    @State private var viewModel = TripPlannerViewModel()
    @State private var showSettings = false
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

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label(L10n.contentSettings, systemImage: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheetView(viewModel: viewModel, isPresented: $showSettings)
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
        .mapControls {
            MapCompass()
            MapScaleView()
            MapPitchToggle()
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
                        Text(viewModel.routeDetailsButtonTitle)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if let routeStatus = viewModel.routeStatus {
                    Text(routeStatus.message)
                        .font(.footnote)
                        .foregroundStyle(statusColor(for: routeStatus.tone))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 12)
    }

    private func statusColor(for tone: TripPlannerViewModel.StatusMessage.Tone) -> Color {
        switch tone {
        case .info:
            return .secondary
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
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
