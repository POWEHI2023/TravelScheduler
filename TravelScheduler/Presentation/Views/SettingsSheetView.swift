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
    @State private var routePlanDocument: RoutePlanDocument?

    var body: some View {
        NavigationStack {
            List {
                searchSection
                selectedStopsSection
                routePlanningSection
                routeLegModesSection
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: searchTextBinding,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: L10n.settingsSearchPlaceholder
            )
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
            if viewModel.searchText.isEmpty,
               viewModel.searchResults.isEmpty,
               viewModel.searchStatus == nil,
               !viewModel.isSearching {
                Text(L10n.settingsSearchHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.isSearching {
                ProgressView(L10n.settingsSearchLoading)
            }

            if let searchStatus = viewModel.searchStatus {
                statusView(searchStatus)
            }

            if !viewModel.searchResults.isEmpty {
                ForEach(viewModel.searchResults, id: \.self) { item in
                    Button {
                        viewModel.addStop(from: item)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.name ?? L10n.commonUnnamedPlace)
                                    .font(.headline)

                                Text(item.displayAddress)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "plus.circle.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        L10n.settingsAddToItineraryAccessibility(
                            name: item.name ?? L10n.commonPlace
                        )
                    )
                }
            }
        }
    }

    private var routePlanningSection: some View {
        Section(L10n.settingsRoutePlanningSection) {
            if viewModel.plannedStops.isEmpty {
                ContentUnavailableView(L10n.settingsAddPlacesFirst, systemImage: "mappin.and.ellipse")
            } else {
                Toggle(L10n.settingsLoopToggle, isOn: loopToStartBinding)
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
        SelectedStopsSectionView(
            plannedStops: plannedStopsBinding,
            stopIndicesByID: plannedStopIndicesByID,
            canMoveStops: viewModel.plannedStops.count > 1
        )
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { viewModel.searchText },
            set: viewModel.updateSearchText
        )
    }

    private var loopToStartBinding: Binding<Bool> {
        Binding(
            get: { viewModel.loopToStart },
            set: viewModel.updateLoopToStart
        )
    }

    private var plannedStopsBinding: Binding<[TripStop]> {
        Binding(
            get: { viewModel.plannedStops },
            set: viewModel.applyEditedPlannedStops
        )
    }

    private var plannedStopIndicesByID: [UUID: Int] {
        Dictionary(
            uniqueKeysWithValues: viewModel.plannedStops.enumerated().map { index, stop in
                (stop.id, index)
            }
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
        Label(status.message, systemImage: status.tone.systemImage)
            .font(.footnote)
            .foregroundStyle(status.tone.color)
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

    private struct SelectedStopsSectionView: View {
        @Binding var plannedStops: [TripStop]
        let stopIndicesByID: [UUID: Int]
        let canMoveStops: Bool

        var body: some View {
            Section {
                if plannedStops.isEmpty {
                    ContentUnavailableView(
                        L10n.settingsNoSelectedPlaces,
                        systemImage: "list.bullet.rectangle"
                    )
                } else {
                    ForEach($plannedStops, editActions: .all) { $stop in
                        SelectedStopRow(
                            stop: $stop.wrappedValue,
                            index: stopIndicesByID[$stop.wrappedValue.id] ?? 0
                        )
                        .moveDisabled(!canMoveStops)
                    }
                }
            } header: {
                Text(L10n.settingsSelectedPlacesSection)
            } footer: {
                if !plannedStops.isEmpty {
                    Text(L10n.settingsSelectedPlacesHint)
                }
            }
        }
    }

    private struct SelectedStopRow: View {
        let stop: TripStop
        let index: Int

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(RoutePalette.color(at: index))
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(index + 1). \(stop.name)")
                        .font(.body)
                    Text(stop.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }
            .padding(.vertical, 2)
        }
    }
}
