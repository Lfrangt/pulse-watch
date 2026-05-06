import SwiftUI

// Stress mode derived from the 0–100 stress score (HRV + RHR composite).
// Extracted from the deleted StressDetailView during Phase 2-S02; kept as a
// shared model since several views map score → label/color.

enum StressLevel {
    case low, moderate, high

    static func from(score: Int) -> StressLevel {
        switch score {
        case 0..<35:  return .low
        case 35..<65: return .moderate
        default:      return .high
        }
    }

    var label: String {
        switch self {
        case .low:      return String(localized: "Low Stress")
        case .moderate: return String(localized: "Moderate Stress")
        case .high:     return String(localized: "High Stress")
        }
    }

    /// DS-tokenised semantic color. low = good, moderate = warn, high = bad.
    var color: Color {
        switch self {
        case .low:      return DS.Color.good
        case .moderate: return DS.Color.warn
        case .high:     return DS.Color.bad
        }
    }
}
