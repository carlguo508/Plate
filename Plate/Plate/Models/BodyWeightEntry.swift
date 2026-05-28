import Foundation
import SwiftData

/// One bodyweight reading. Stored in kilograms (canonical); display honors `WeightPreference`.
/// Convention: at most one entry per calendar day — logging again the same day updates it.
@Model
final class BodyWeightEntry {
    var date: Date
    var weightKg: Double

    init(date: Date = .now, weightKg: Double) {
        self.date = date
        self.weightKg = weightKg
    }
}
