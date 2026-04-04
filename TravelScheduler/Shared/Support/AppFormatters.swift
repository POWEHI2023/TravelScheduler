import CoreLocation
import Foundation

enum AppFormatters {
    private static let distanceFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func distance(_ distance: CLLocationDistance) -> String {
        let measurement = Measurement(value: distance / 1000, unit: UnitLength.kilometers)
        return distanceFormatter.string(from: measurement)
    }

    static func duration(_ duration: TimeInterval) -> String {
        durationFormatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute]
        return durationFormatter.string(from: duration) ?? "--"
    }

    static func timestamp(_ date: Date) -> String {
        timestampFormatter.string(from: date)
    }
}
