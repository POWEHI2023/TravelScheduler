enum TravelMode: String, CaseIterable, Identifiable {
    case driving = "驾车"
    case walking = "步行"
    case transit = "公共交通"

    var id: String { rawValue }
}
