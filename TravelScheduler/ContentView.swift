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
            .navigationTitle("旅行地图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.fitMapToPlannedContent()
                    } label: {
                        Label("定位路线", systemImage: "scope")
                    }
                    .disabled(viewModel.plannedStops.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("设置", systemImage: "slider.horizontal.3")
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
            .onChange(of: viewModel.plannedStops.map(\.id)) { _, _ in
                viewModel.syncRouteEndpointsWithStops()
            }
            .onChange(of: viewModel.startStopID) { _, newStartID in
                viewModel.handleStartStopChanged(newStartID)
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
                    .tint(viewModel.colorForStop(at: index))
            }

            ForEach(Array(viewModel.routeSegments.enumerated()), id: \.element.id) { index, segment in
                if !viewModel.hiddenSegmentIDs.contains(segment.id) {
                    MapPolyline(segment.polyline)
                        .stroke(
                            viewModel.colorForSegment(at: index),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
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
        VStack {
            if !viewModel.routeSegments.isEmpty {
                RouteLegendView(
                    segments: viewModel.routeSegments,
                    hiddenSegmentIDs: viewModel.hiddenSegmentIDs,
                    onToggle: viewModel.toggleSegmentVisibility
                )
                .padding(.top, 8)
            }

            Spacer()

            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.footnote)
                    .underline(isRouteUpdateMessage(message), color: .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 12)
                    .onTapGesture {
                        guard isRouteUpdateMessage(message), !viewModel.routeSegments.isEmpty else {
                            return
                        }
                        showRouteSegmentsSheet = true
                    }
            }
        }
        .padding(.horizontal, 12)
    }

    private func isRouteUpdateMessage(_ message: String) -> Bool {
        message.hasPrefix("路线已更新，共")
    }
}

#Preview {
    ContentView()
}
