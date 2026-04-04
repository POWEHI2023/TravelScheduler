import CoreLocation
import Foundation

enum AppFormatters {
    private static let distanceFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }()

    private static let shortDurationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.minute]
        return formatter
    }()

    private static let longDurationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
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
        let formatter = duration >= 3600 ? longDurationFormatter : shortDurationFormatter
        return formatter.string(from: duration) ?? "--"
    }

    static func timestamp(_ date: Date) -> String {
        timestampFormatter.string(from: date)
    }
}
