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
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
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
        Section("搜索地点") {
            TextField("输入景点、地标或地址", text: searchTextBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if viewModel.isSearching {
                ProgressView("搜索中...")
            }

            if let searchStatus = viewModel.searchStatus {
                statusView(searchStatus)
            }

            if !viewModel.searchResults.isEmpty {
                ForEach(viewModel.searchResults, id: \.self) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name ?? "未命名地点")
                            .font(.headline)

                        Text(item.displayAddress)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("添加到行程") {
                            viewModel.addStop(from: item)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("添加\(item.name ?? "地点")到行程")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var routePlanningSection: some View {
        Section("路线规划") {
            if viewModel.plannedStops.isEmpty {
                ContentUnavailableView("请先添加地点", systemImage: "mappin.and.ellipse")
            } else {
                Picker("起点", selection: startStopBinding) {
                    ForEach(viewModel.plannedStops) { stop in
                        Text(stop.name).tag(Optional(stop.id))
                    }
                }

                Toggle("终点与起点相同（环线）", isOn: loopToStartBinding)

                if !viewModel.loopToStart {
                    Picker("终点", selection: endStopBinding) {
                        ForEach(viewModel.plannedStops) { stop in
                            Text(stop.name).tag(Optional(stop.id))
                        }
                    }
                }
            }

            if let routeOrderDescription = viewModel.routeOrderDescription {
                VStack(alignment: .leading, spacing: 4) {
                    Text("实际生成顺序")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(routeOrderDescription)
                        .font(.footnote)
                }
            }

            Button {
                Task { await viewModel.generateRoutePlan() }
            } label: {
                Label("按已选起终点生成路线", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canGenerateRoute || viewModel.isPlanningRoute)

            if viewModel.isPlanningRoute {
                ProgressView("路线计算中...")
            }

            if !viewModel.routeSegments.isEmpty {
                if viewModel.hasExternalTransitSegments {
                    Label("部分公共交通分段不提供应用内路程估算", systemImage: "ruler")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Label("总路程：\(AppFormatters.distance(viewModel.totalDistance))", systemImage: "ruler")
                }

                Label("总时长：\(AppFormatters.duration(viewModel.totalTravelTime))", systemImage: "clock")

                Text(viewModel.travelSuggestion)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    routePlanDocument = RoutePlanDocument(
                        markdown: viewModel.makeRoutePlanMarkdownDocument()
                    )
                } label: {
                    Label("生成路线规划文档", systemImage: "doc.plaintext")
                }
                .buttonStyle(.bordered)
            }

            if let routeStatus = viewModel.routeStatus {
                statusView(routeStatus)
            }
        }
    }

    private var routeLegModesSection: some View {
        Section("分段通行方式") {
            if viewModel.routeLegPlans.isEmpty {
                ContentUnavailableView(
                    "暂无可配置分段",
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                    description: Text("至少添加两个地点并确认起终点后可配置每一段的通行方式")
                )
            } else {
                ForEach(viewModel.routeLegPlans) { leg in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("第\(leg.index + 1)段")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("\(leg.fromName) → \(leg.toName)")
                                .font(.subheadline)
                                .lineLimit(1)
                        }

                        Picker("第\(leg.index + 1)段通行方式", selection: segmentModeBinding(for: leg.leg)) {
                            ForEach(TravelMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
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
        Section("已选地点") {
            if viewModel.plannedStops.isEmpty {
                ContentUnavailableView("还没有添加地点", systemImage: "list.bullet.rectangle")
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
                        .accessibilityLabel("删除\(stop.name)")
                    }
                    .padding(.vertical, 2)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.removeStop(at: idx)
                        } label: {
                            Label("删除", systemImage: "trash")
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
}
