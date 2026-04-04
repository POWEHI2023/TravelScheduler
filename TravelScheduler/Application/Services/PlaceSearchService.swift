import Foundation
import MapKit

@MainActor
protocol PlaceSearchServing: AnyObject {
    func search(keyword: String, limit: Int) async throws -> [MKMapItem]
    func cancelActiveSearch()
}

@MainActor
final class MapKitPlaceSearchService: PlaceSearchServing {
    private var activeSearch: MKLocalSearch?

    func search(keyword: String, limit: Int) async throws -> [MKMapItem] {
        activeSearch?.cancel()

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword

        let search = MKLocalSearch(request: request)
        activeSearch = search
        defer {
            if activeSearch === search {
                activeSearch = nil
            }
        }

        let response = try await search.start()
        return Array(response.mapItems.prefix(limit))
    }

    func cancelActiveSearch() {
        activeSearch?.cancel()
        activeSearch = nil
    }
}
