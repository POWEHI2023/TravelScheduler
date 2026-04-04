import Foundation
import MapKit

protocol PlaceSearchServing {
    func search(keyword: String, limit: Int) async throws -> [MKMapItem]
}

struct MapKitPlaceSearchService: PlaceSearchServing {
    func search(keyword: String, limit: Int) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword

        let response = try await MKLocalSearch(request: request).start()
        return Array(response.mapItems.prefix(limit))
    }
}
