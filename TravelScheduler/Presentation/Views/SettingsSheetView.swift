import MapKit
import Observation
import SwiftUI

struct SettingsSheetView: View {
    private struct RoutePlanDocument: Identifiable {
        let id = UUID()
        let markdown: String
    }

    @Bindable var viewModel: TripPlannerViewModel
    @Binding var isPresented: Bool
    @State private var editMode: EditMode = .active
    @State private var routePlanDocument: RoutePlanDocument?

    var body: some View {
        NavigationStack {
            List {
                searchSection
                routePlanningSection
                routeLegModesSection
                selectedStopsSection
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, $editMode)
            .navigationTitle(L10n.settingsTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.commonDone) {
                        isPresented = false
                    }
                }
            }
            .sheet(item: $routePlanDocument) { document in
                RoutePlanDocumentSheetView(markdown: document.markdown)
            }
        }
    }

    private var searchSection: some View {
        Section(L10n.settingsSearchSection) {
            TextField(L10n.settingsSearchPlaceholder, text: searchTextBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if viewModel.isSearching {
                ProgressView(L10n.settingsSearchLoading)
            }

            if let searchStatus = viewModel.searchStatus {
                statusView(searchStatus)
            }

            if !viewModel.searchResults.isEmpty {
                ForEach(viewModel.searchResults, id: \.self) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name ?? L10n.commonUnnamedPlace)
                            .font(.headline)

                        Text(item.displayAddress)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button(L10n.settingsAddToItinerary) {
                            viewModel.addStop(from: item)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(
                            L10n.settingsAddToItineraryAccessibility(
                                name: item.name ?? L10n.commonPlace
                            )
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var routePlanningSection: some View {
        Section(L10n.settingsRoutePlanningSection) {
            if viewModel.plannedStops.isEmpty {
                ContentUnavailableView(L10n.settingsAddPlacesFirst, systemImage: "mappin.and.ellipse")
            } else {
                Picker(L10n.settingsRouteStart, selection: startStopBinding) {
                    ForEach(viewModel.plannedStops) { stop in
                        Text(stop.name).tag(Optional(stop.id))
                    }
                }

                Toggle(L10n.settingsLoopToggle, isOn: loopToStartBinding)

                if !viewModel.loopToStart {
                    Picker(L10n.settingsRouteEnd, selection: endStopBinding) {
                        ForEach(viewModel.plannedStops) { stop in
                            Text(stop.name).tag(Optional(stop.id))
                        }
                    }
                }
            }

            if let routeOrderDescription = viewModel.routeOrderDescription {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.settingsActualGenerationOrder)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(routeOrderDescription)
                        .font(.footnote)
                }
            }

            Button {
                Task { await viewModel.generateRoutePlan() }
            } label: {
                actionButtonLabel(
                    title: L10n.settingsGenerateRoute,
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canGenerateRoute || viewModel.isPlanningRoute)

            if viewModel.isPlanningRoute {
                ProgressView(L10n.settingsRouteLoading)
            }

            if !viewModel.routeSegments.isEmpty {
                if viewModel.hasExternalTransitSegments {
                    Label(L10n.settingsTransitNoInAppDistance, systemImage: "ruler")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Label(
                        L10n.settingsTotalDistance(AppFormatters.distance(viewModel.totalDistance)),
                        systemImage: "ruler"
                    )
                }

                Label(
                    L10n.settingsTotalDuration(AppFormatters.duration(viewModel.totalTravelTime)),
                    systemImage: "clock"
                )

                Text(viewModel.travelSuggestion)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    routePlanDocument = RoutePlanDocument(
                        markdown: viewModel.makeRoutePlanMarkdownDocument()
                    )
                } label: {
                    actionButtonLabel(
                        title: L10n.settingsGenerateRoutePlanDocument,
                        systemImage: "doc.plaintext"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if let routeStatus = viewModel.routeStatus {
                statusView(routeStatus)
            }
        }
    }

    private var routeLegModesSection: some View {
        Section(L10n.settingsSegmentModesSection) {
            if viewModel.routeLegPlans.isEmpty {
                ContentUnavailableView(
                    L10n.settingsNoConfigurableSegmentsTitle,
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                    description: Text(L10n.settingsNoConfigurableSegmentsDescription)
                )
            } else {
                ForEach(viewModel.routeLegPlans) { leg in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text(L10n.segmentOrdinal(leg.index + 1))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("\(leg.fromName) → \(leg.toName)")
                                .font(.subheadline)
                                .lineLimit(1)
                        }

                        Picker(
                            L10n.settingsSegmentModePickerLabel(index: leg.index + 1),
                            selection: segmentModeBinding(for: leg.leg)
                        ) {
                            ForEach(TravelMode.allCases) { mode in
                                Text(mode.localizedName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(10)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }
            }
        }
    }

    private var selectedStopsSection: some View {
        Section(L10n.settingsSelectedPlacesSection) {
            if viewModel.plannedStops.isEmpty {
                ContentUnavailableView(L10n.settingsNoSelectedPlaces, systemImage: "list.bullet.rectangle")
            } else {
                ForEach(Array(viewModel.plannedStops.enumerated()), id: \.element.id) { idx, stop in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(RoutePalette.color(at: idx))
                            .frame(width: 12, height: 12)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(idx + 1). \(stop.name)")
                                .font(.body)
                            Text(stop.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Button(role: .destructive) {
                            viewModel.removeStop(at: idx)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(L10n.settingsDeleteAccessibility(name: stop.name))
                    }
                    .padding(.vertical, 2)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.removeStop(at: idx)
                        } label: {
                            Label(L10n.commonDelete, systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: viewModel.moveStops)
            }
        }
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { viewModel.searchText },
            set: viewModel.updateSearchText
        )
    }

    private var startStopBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.startStopID },
            set: viewModel.updateStartStopID
        )
    }

    private var endStopBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.endStopID },
            set: viewModel.updateEndStopID
        )
    }

    private var loopToStartBinding: Binding<Bool> {
        Binding(
            get: { viewModel.loopToStart },
            set: viewModel.updateLoopToStart
        )
    }

    private func segmentModeBinding(for leg: TripPlanDraft.RouteLeg) -> Binding<TravelMode> {
        Binding(
            get: { viewModel.modeForLeg(leg) },
            set: { viewModel.setMode($0, for: leg) }
        )
    }

    @ViewBuilder
    private func statusView(_ status: TripPlannerViewModel.StatusMessage) -> some View {
        Text(status.message)
            .font(.footnote)
            .foregroundStyle(statusColor(for: status.tone))
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

    private func actionButtonLabel(title: String, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 18)

            Text(title)
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
