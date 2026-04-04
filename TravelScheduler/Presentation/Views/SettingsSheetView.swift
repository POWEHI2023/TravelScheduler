import MapKit
import Observation
import SwiftUI

struct SettingsSheetView: View {
    @Bindable var viewModel: TripPlannerViewModel
    @Binding var isPresented: Bool
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                searchSection
                routePlanningSection
                selectedStopsSection
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
            .onChange(of: viewModel.searchText) { _, newValue in
                viewModel.scheduleAutoSearch(for: newValue)
            }
            .onChange(of: viewModel.loopToStart) { _, enabled in
                viewModel.handleLoopChange(enabled)
            }
        }
    }

    private var searchSection: some View {
        Section("搜索地点") {
            TextField("输入景点、地标或地址", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if viewModel.isSearching {
                ProgressView("搜索中...")
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
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var routePlanningSection: some View {
        Section("路线规划") {
            Picker("出行方式", selection: $viewModel.selectedMode) {
                ForEach(TravelMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.plannedStops.isEmpty {
                Text("请先添加地点")
                    .foregroundStyle(.secondary)
            } else {
                Picker("起点", selection: $viewModel.startStopID) {
                    ForEach(viewModel.plannedStops) { stop in
                        Text(stop.name).tag(Optional(stop.id))
                    }
                }

                Toggle("终点与起点相同（环线）", isOn: $viewModel.loopToStart)

                if !viewModel.loopToStart {
                    Picker("终点", selection: $viewModel.endStopID) {
                        ForEach(viewModel.plannedStops) { stop in
                            Text(stop.name).tag(Optional(stop.id))
                        }
                    }
                }
            }

            Button {
                Task { await viewModel.generateRoutePlan() }
            } label: {
                Label("按当前顺序生成路线", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            }
            .disabled(!viewModel.canGenerateRoute || viewModel.isPlanningRoute)

            if viewModel.isPlanningRoute {
                ProgressView("路线计算中...")
            }

            if !viewModel.routeSegments.isEmpty {
                Label("总路程：\(AppFormatters.distance(viewModel.totalDistance))", systemImage: "ruler")
                Label("总时长：\(AppFormatters.duration(viewModel.totalTravelTime))", systemImage: "clock")

                Text(viewModel.travelSuggestion)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectedStopsSection: some View {
        Section("已选地点（拖动右侧把手排序）") {
            if viewModel.plannedStops.isEmpty {
                Text("还没有添加地点")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.plannedStops.enumerated()), id: \.element.id) { idx, stop in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(viewModel.colorForStop(at: idx))
                            .frame(width: 12, height: 12)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(idx + 1). \(stop.name)")
                                .font(.body)
                            Text(stop.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onMove(perform: viewModel.moveStops)
                .onDelete(perform: viewModel.deleteStops)
            }
        }
    }

    private var routeDetailSection: some View {
        Section("分段详情") {
            ForEach(Array(viewModel.routeSegments.enumerated()), id: \.element.id) { index, segment in
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(viewModel.colorForSegment(at: index))
                        .frame(width: 8, height: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("第\(index + 1)段：\(segment.from.name) → \(segment.to.name)")
                            .font(.subheadline)

                        Text("\(AppFormatters.distance(segment.distance)) · \(AppFormatters.duration(segment.expectedTravelTime))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
