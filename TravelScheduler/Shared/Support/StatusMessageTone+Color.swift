import SwiftUI

extension TripPlannerViewModel.StatusMessage.Tone {
    var color: Color {
        switch self {
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
