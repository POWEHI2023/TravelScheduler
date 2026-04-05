import Foundation

enum L10n {
    private static func text(
        _ key: StaticString,
        defaultValue: String.LocalizationValue
    ) -> String {
        String(localized: key, defaultValue: defaultValue, table: "Localizable")
    }

    private static func format(
        _ key: StaticString,
        defaultValue: String.LocalizationValue,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: text(key, defaultValue: defaultValue),
            locale: .autoupdatingCurrent,
            arguments: arguments
        )
    }

    static var commonDone: String {
        text("common.done", defaultValue: "完成")
    }

    static var commonClose: String {
        text("common.close", defaultValue: "关闭")
    }

    static var commonDelete: String {
        text("common.delete", defaultValue: "删除")
    }

    static var commonYes: String {
        text("common.yes", defaultValue: "是")
    }

    static var commonNo: String {
        text("common.no", defaultValue: "否")
    }

    static var commonUnnamedPlace: String {
        text("common.unnamed_place", defaultValue: "未命名地点")
    }

    static var commonPlace: String {
        text("common.place", defaultValue: "地点")
    }

    static var commonWarningLabel: String {
        text("common.warning_label", defaultValue: "提示")
    }

    static var commonAppleMaps: String {
        text("common.apple_maps", defaultValue: "Apple 地图")
    }

    static var contentNavigationTitle: String {
        text("content.navigation.title", defaultValue: "旅行地图")
    }

    static var contentLocateRoute: String {
        text("content.button.locate_route", defaultValue: "定位路线")
    }

    static var contentSettings: String {
        text("content.button.settings", defaultValue: "设置")
    }

    static func segmentOrdinal(_ index: Int) -> String {
        format("route.segment.ordinal", defaultValue: "第%lld段", Int64(index))
    }

    static func routeSegmentHeader(index: Int, from: String, to: String) -> String {
        format(
            "route.segment.header",
            defaultValue: "第%1$lld段：%2$@ → %3$@",
            Int64(index),
            from,
            to
        )
    }

    static var routeSegmentsTitle: String {
        text("route.segments.title", defaultValue: "分段路线")
    }

    static func routeSegmentEstimatedDuration(_ duration: String) -> String {
        format("route.segment.estimated_duration", defaultValue: "预计时长：%@", duration)
    }

    static var routeSegmentShowDetails: String {
        text("route.segment.show_details", defaultValue: "显示详细路线")
    }

    static var routeSegmentHideDetails: String {
        text("route.segment.hide_details", defaultValue: "收起详细路线")
    }

    static var routeSegmentNoDetails: String {
        text("route.segment.no_details", defaultValue: "暂无更详细步骤信息")
    }

    static func routeSegmentProviderHandlesDetails(_ provider: String) -> String {
        format(
            "route.segment.provider_handles_details",
            defaultValue: "%@ 承接详细路线",
            provider
        )
    }

    static func routeSegmentPreferences(_ preferences: String) -> String {
        format("route.segment.preferences", defaultValue: "偏好：%@", preferences)
    }

    static var routeSegmentOpenInAppleMaps: String {
        text("route.segment.open_in_apple_maps", defaultValue: "在 Apple 地图中查看")
    }

    static func routeSegmentDetailsInAppleMaps(mode: String) -> String {
        format(
            "route.segment.details_in_apple_maps",
            defaultValue: "%@ · 详情见 Apple 地图",
            mode
        )
    }

    static func routeSegmentSummary(mode: String, duration: String) -> String {
        format(
            "route.segment.summary_duration",
            defaultValue: "%@ · %@",
            mode,
            duration
        )
    }

    static func routeSegmentSummary(mode: String, distance: String, duration: String) -> String {
        format(
            "route.segment.summary_full",
            defaultValue: "%@ · %@ · %@",
            mode,
            distance,
            duration
        )
    }

    static func routeDetailsButtonTitle(segmentCount: Int) -> String {
        format(
            "route.details.button_title",
            defaultValue: "查看分段路线（%lld段）",
            Int64(segmentCount)
        )
    }

    static var routeLegendExternalAccessibility: String {
        text(
            "route.legend.external_accessibility",
            defaultValue: "该段需在 Apple 地图中查看"
        )
    }

    static var settingsTitle: String {
        text("settings.title", defaultValue: "设置")
    }

    static var settingsSearchSection: String {
        text("settings.section.search", defaultValue: "搜索地点")
    }

    static var settingsSearchPlaceholder: String {
        text(
            "settings.search.placeholder",
            defaultValue: "输入景点、地标或地址"
        )
    }

    static var settingsSearchLoading: String {
        text("settings.search.loading", defaultValue: "搜索中...")
    }

    static var settingsAddToItinerary: String {
        text("settings.search.add_to_itinerary", defaultValue: "添加到行程")
    }

    static func settingsAddToItineraryAccessibility(name: String) -> String {
        format(
            "settings.search.add_accessibility",
            defaultValue: "添加%@到行程",
            name
        )
    }

    static var settingsRoutePlanningSection: String {
        text("settings.section.route_planning", defaultValue: "路线规划")
    }

    static var settingsAddPlacesFirst: String {
        text("settings.route.add_places_first", defaultValue: "请先添加地点")
    }

    static var settingsLoopToggle: String {
        text(
            "settings.route.loop_toggle",
            defaultValue: "终点与起点相同（环线）"
        )
    }

    static var settingsActualGenerationOrder: String {
        text("settings.route.actual_generation_order", defaultValue: "实际生成顺序")
    }

    static var settingsGenerateRoute: String {
        text(
            "settings.route.generate",
            defaultValue: "生成路线"
        )
    }

    static var settingsRouteLoading: String {
        text("settings.route.loading", defaultValue: "路线计算中...")
    }

    static var settingsTransitNoInAppDistance: String {
        text(
            "settings.route.no_in_app_distance_for_transit",
            defaultValue: "部分公共交通分段不提供应用内路程估算"
        )
    }

    static func settingsTotalDistance(_ distance: String) -> String {
        format("settings.route.total_distance", defaultValue: "总路程：%@", distance)
    }

    static func settingsTotalDuration(_ duration: String) -> String {
        format("settings.route.total_duration", defaultValue: "总时长：%@", duration)
    }

    static var settingsGenerateRoutePlanDocument: String {
        text(
            "settings.route.generate_document",
            defaultValue: "生成路线规划文档"
        )
    }

    static var settingsSegmentModesSection: String {
        text("settings.section.segment_modes", defaultValue: "分段通行方式")
    }

    static var settingsNoConfigurableSegmentsTitle: String {
        text(
            "settings.segment_modes.empty_title",
            defaultValue: "暂无可配置分段"
        )
    }

    static var settingsNoConfigurableSegmentsDescription: String {
        text(
            "settings.segment_modes.empty_description",
            defaultValue: "至少添加两个地点并确认起终点后可配置每一段的通行方式"
        )
    }

    static func settingsSegmentModePickerLabel(index: Int) -> String {
        format(
            "settings.segment_modes.picker_label",
            defaultValue: "第%lld段通行方式",
            Int64(index)
        )
    }

    static var settingsSelectedPlacesSection: String {
        text("settings.section.selected_places", defaultValue: "已选地点")
    }

    static var settingsNoSelectedPlaces: String {
        text("settings.selected_places.empty", defaultValue: "还没有添加地点")
    }

    static func settingsDeleteAccessibility(name: String) -> String {
        format("settings.delete_accessibility", defaultValue: "删除%@", name)
    }

    static var routePlanDocumentTitle: String {
        text("route_plan_document.title", defaultValue: "路线规划文档")
    }

    static var routePlanDocumentEmptyTitle: String {
        text(
            "route_plan_document.empty_title",
            defaultValue: "暂无路线规划内容"
        )
    }

    static var routePlanDocumentEmptyDescription: String {
        text(
            "route_plan_document.empty_description",
            defaultValue: "请先生成路线，再创建路线规划文档。"
        )
    }

    static var routePlanDocumentCopyAccessibility: String {
        text(
            "route_plan_document.copy_accessibility",
            defaultValue: "复制规划内容"
        )
    }

    static var routePlanDocumentCopiedAccessibility: String {
        text(
            "route_plan_document.copied_accessibility",
            defaultValue: "已复制规划内容"
        )
    }

    static var routePlanDocumentCopiedToClipboard: String {
        text(
            "route_plan_document.copied_to_clipboard",
            defaultValue: "已复制到剪贴板"
        )
    }

    static var travelSuggestionNeedsRoute: String {
        text(
            "suggestion.needs_route",
            defaultValue: "添加至少两个地点后可生成路线建议"
        )
    }

    static var travelSuggestionHalfDay: String {
        text(
            "suggestion.half_day",
            defaultValue: "建议：这条路线适合半日轻量行程。"
        )
    }

    static var travelSuggestionFullDay: String {
        text(
            "suggestion.full_day",
            defaultValue: "建议：这条路线适合一天内完成。"
        )
    }

    static var travelSuggestionLong: String {
        text(
            "suggestion.long",
            defaultValue: "建议：这条路线较长，建议分两天或增加中途休息点。"
        )
    }

    static var routeInvalidationStatus: String {
        text("status.route.invalidate", defaultValue: "请重新生成路线。")
    }

    static var routeStartUpdated: String {
        text("status.route.start_updated", defaultValue: "起点已更新")
    }

    static var routeEndUpdated: String {
        text("status.route.end_updated", defaultValue: "终点已更新")
    }

    static var routeLoopEnabled: String {
        text("status.route.loop_enabled", defaultValue: "已切换为环线")
    }

    static var routeLoopDisabled: String {
        text(
            "status.route.loop_disabled",
            defaultValue: "已切换为非环线"
        )
    }

    static var routeSegmentModeUpdated: String {
        text(
            "status.route.segment_mode_updated",
            defaultValue: "分段通行方式已更新"
        )
    }

    static func routeAdded(_ name: String) -> String {
        format("status.route.added", defaultValue: "已添加：%@", name)
    }

    static var routeOrderUpdated: String {
        text("status.route.order_updated", defaultValue: "顺序已更新")
    }

    static func routeDeleted(_ name: String) -> String {
        format("status.route.deleted", defaultValue: "已删除：%@", name)
    }

    static var routeMinimumStops: String {
        text(
            "status.route.minimum_stops",
            defaultValue: "至少需要两个地点才能生成路线。"
        )
    }

    static var routeCannotCalculate: String {
        text(
            "status.route.cannot_calculate",
            defaultValue: "无法计算路线，请尝试更换地点或出行方式。"
        )
    }

    static var routeTransitFallbackStatus: String {
        text(
            "status.route.transit_fallback",
            defaultValue: "部分公共交通分段未找到可用公交方案，已改用步行或驾车。"
        )
    }

    static var routeExternalTransitStatus: String {
        text(
            "status.route.external_transit",
            defaultValue: "部分公共交通分段需在 Apple 地图中查看详细路线。"
        )
    }

    static var routeUpdatedWithFallback: String {
        text(
            "status.route.updated_with_fallback",
            defaultValue: "路线已更新，但部分分段使用了替代方式或直线估算。"
        )
    }

    static func routeUpdatedSegments(_ count: Int) -> String {
        format(
            "status.route.updated_segments",
            defaultValue: "路线已更新，共 %lld 段。",
            Int64(count)
        )
    }

    static func routeGenerationFailed(_ message: String) -> String {
        format(
            "status.route.generation_failed",
            defaultValue: "路线计算失败：%@",
            message
        )
    }

    static var searchDuplicatePlace: String {
        text(
            "status.search.duplicate_place",
            defaultValue: "该地点已在行程中。"
        )
    }

    static var searchNoResults: String {
        text(
            "status.search.no_results",
            defaultValue: "未找到相关地点，请尝试更具体的关键词。"
        )
    }

    static func searchFailed(_ message: String) -> String {
        format("status.search.failed", defaultValue: "搜索失败：%@", message)
    }

    static func routeStartAdjusted(_ stopName: String) -> String {
        format(
            "route.adjustment.start_adjusted",
            defaultValue: "起点已调整为%@",
            stopName
        )
    }

    static func routeEndSynced(_ stopName: String) -> String {
        format(
            "route.adjustment.end_synced",
            defaultValue: "终点已同步为%@",
            stopName
        )
    }

    static func routeEndAdjusted(_ stopName: String) -> String {
        format(
            "route.adjustment.end_adjusted",
            defaultValue: "终点已调整为%@",
            stopName
        )
    }

    static func routeMessage(base: String, followup: String) -> String {
        format(
            "route.message.without_adjustment",
            defaultValue: "%1$@。%2$@",
            base,
            followup
        )
    }

    static func routeMessage(base: String, adjustment: String, followup: String) -> String {
        format(
            "route.message.with_adjustment",
            defaultValue: "%1$@%2$@。%3$@",
            base,
            adjustment,
            followup
        )
    }

    static var routeStopRoleStartEnd: String {
        text("route.stop_role.start_end", defaultValue: "（起点 / 终点）")
    }

    static var routeStopRoleStart: String {
        text("route.stop_role.start", defaultValue: "（起点）")
    }

    static var routeStopRoleEnd: String {
        text("route.stop_role.end", defaultValue: "（终点）")
    }

    static func routeSegmentModeOriginalSelection(actual: String, original: String) -> String {
        format(
            "route.segment.mode.original_selection",
            defaultValue: "%1$@（原选择：%2$@）",
            actual,
            original
        )
    }

    static var markdownTitle: String {
        text("markdown.title", defaultValue: "路线规划文档")
    }

    static var markdownOverviewSection: String {
        text("markdown.section.overview", defaultValue: "概览")
    }

    static func markdownGeneratedAt(_ timestamp: String) -> String {
        format("markdown.generated_at", defaultValue: "生成时间：%@", timestamp)
    }

    static func markdownStart(_ name: String) -> String {
        format("markdown.start", defaultValue: "起点：%@", name)
    }

    static func markdownEnd(_ name: String) -> String {
        format("markdown.end", defaultValue: "终点：%@", name)
    }

    static func markdownIsLoop(_ value: String) -> String {
        format("markdown.is_loop", defaultValue: "是否环线：%@", value)
    }

    static func markdownRouteOrder(_ order: String) -> String {
        format("markdown.route_order", defaultValue: "路线顺序：%@", order)
    }

    static func markdownTotalDuration(_ duration: String) -> String {
        format("markdown.total_duration", defaultValue: "总时长：%@", duration)
    }

    static func markdownTotalDistance(_ distance: String) -> String {
        format("markdown.total_distance", defaultValue: "总路程：%@", distance)
    }

    static func markdownTotalDistanceTransitNote(_ distance: String) -> String {
        format(
            "markdown.total_distance_transit_note",
            defaultValue: "总路程：%@（不含需在 Apple 地图中查看的公共交通实际轨迹）",
            distance
        )
    }

    static func markdownCurrentStatus(_ status: String) -> String {
        format("markdown.current_status", defaultValue: "当前状态：%@", status)
    }

    static func markdownTravelSuggestion(_ suggestion: String) -> String {
        format("markdown.travel_suggestion", defaultValue: "行程建议：%@", suggestion)
    }

    static var markdownPlacesSection: String {
        text("markdown.section.places", defaultValue: "地点列表")
    }

    static var markdownNoPlaces: String {
        text("markdown.no_places", defaultValue: "暂无地点")
    }

    static func markdownAddress(_ address: String) -> String {
        format("markdown.address", defaultValue: "地址：%@", address)
    }

    static var markdownSegmentsSection: String {
        text("markdown.section.segments", defaultValue: "分段规划")
    }

    static var markdownNoRoute: String {
        text("markdown.no_route", defaultValue: "暂无已生成路线。")
    }

    static func markdownSegmentTitle(_ index: Int) -> String {
        format("markdown.segment.title", defaultValue: "第%lld段", Int64(index))
    }

    static func markdownSegmentStartEnd(from: String, to: String) -> String {
        format(
            "markdown.segment.start_end",
            defaultValue: "起止：%@ → %@",
            from,
            to
        )
    }

    static func markdownSegmentMode(_ mode: String) -> String {
        format("markdown.segment.mode", defaultValue: "通行方式：%@", mode)
    }

    static func markdownSegmentDuration(_ duration: String) -> String {
        format("markdown.segment.duration", defaultValue: "通行时间：%@", duration)
    }

    static var routeServiceStraightLineFallback: String {
        text(
            "route.service.unable_to_calculate_straight_line",
            defaultValue: "该分段无法通过地图服务计算，已使用直线连接。"
        )
    }

    static func routeServiceStraightLineAfterReason(_ reason: String) -> String {
        format(
            "route.service.straight_line_after_reason",
            defaultValue: "%@，已使用直线连接。",
            reason
        )
    }

    static var routeServiceTransitNoSolutionNoFallback: String {
        text(
            "route.service.transit_no_solution_no_fallback",
            defaultValue: "原选择为公共交通，当前地区/时段未找到可用公交方案，且无法改用步行或驾车，已使用直线连接。"
        )
    }

    static func routeServicePreferredFallback(preferredMode: String, resolvedMode: String) -> String {
        format(
            "route.service.preferred_route_fallback",
            defaultValue: "未找到%@可达路线，已改用%@计算。",
            preferredMode,
            resolvedMode
        )
    }

    static func routeServiceTransitFallbackMode(_ mode: String) -> String {
        format(
            "route.service.transit_fallback_mode",
            defaultValue: "原选择为公共交通，当前地区/时段未找到可用公交方案，已改用%@计算。",
            mode
        )
    }

    static var routeServiceAppleMapsTransitRouteName: String {
        text(
            "route.service.apple_maps_transit_route_name",
            defaultValue: "Apple 地图公共交通"
        )
    }

    static var routeServiceSameCoordinate: String {
        text(
            "route.service.same_coordinate",
            defaultValue: "该分段起终点坐标相同，已按原地停留处理。"
        )
    }

    static func routeServiceModeUnavailable(_ mode: String) -> String {
        format(
            "route.service.mode_unavailable",
            defaultValue: "%@暂不可用",
            mode
        )
    }

    static func routeServiceModeFailed(_ mode: String) -> String {
        format(
            "route.service.mode_failed",
            defaultValue: "%@计算失败",
            mode
        )
    }

    static func routeServiceModeNotFound(_ mode: String) -> String {
        format(
            "route.service.mode_not_found",
            defaultValue: "未找到%@可达路线",
            mode
        )
    }

    static var routeServiceRequestThrottled: String {
        text(
            "route.service.request_throttled",
            defaultValue: "地图服务请求过于频繁"
        )
    }

    static var routeServiceUnavailable: String {
        text(
            "route.service.unavailable",
            defaultValue: "地图服务暂时不可用"
        )
    }

    static var routeServiceContinueToDestination: String {
        text(
            "route.service.continue_to_destination",
            defaultValue: "继续前往目的地"
        )
    }

    static func routeServiceCoordinateFallback(latitude: Double, longitude: Double) -> String {
        format(
            "route.service.coordinate_fallback",
            defaultValue: "纬度 %.4f, 经度 %.4f",
            latitude,
            longitude
        )
    }

    static func travelModeName(_ mode: TravelMode) -> String {
        switch mode {
        case .driving:
            return text("travel_mode.driving", defaultValue: "驾车")
        case .walking:
            return text("travel_mode.walking", defaultValue: "步行")
        case .transit:
            return text("travel_mode.transit", defaultValue: "公共交通")
        }
    }

    static func transitProviderName(_ provider: TransitRouteProvider) -> String {
        switch provider {
        case .appleMaps:
            return text("transit.provider.apple_maps", defaultValue: "Apple 地图")
        }
    }

    static func transitPreferenceName(_ preference: TransitPreference) -> String {
        switch preference {
        case .bus:
            return text("transit.preference.bus", defaultValue: "公交")
        case .subway:
            return text("transit.preference.subway", defaultValue: "地铁")
        case .commuter:
            return text("transit.preference.commuter", defaultValue: "通勤铁路")
        case .ferry:
            return text("transit.preference.ferry", defaultValue: "轮渡")
        }
    }
}
