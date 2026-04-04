import Foundation
import MapKit

extension MKMapItem {
    var displayAddress: String {
        if let singleLine = addressRepresentations?.fullAddress(includingRegion: true, singleLine: true),
           !singleLine.isEmpty {
            return singleLine
        }

        if let fullAddress = address?.fullAddress, !fullAddress.isEmpty {
            return fullAddress.replacingOccurrences(of: "\n", with: ", ")
        }

        let coordinate = location.coordinate
        return L10n.routeServiceCoordinateFallback(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}
