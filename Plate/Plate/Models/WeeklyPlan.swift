import Foundation
import SwiftData

/// Categorical label for a planned training day. Free-form `custom` allows user variants.
enum StrengthDayType: Codable, Equatable {
    case rest
    case push
    case pull
    case legs
    case upper
    case lower
    case full
    case custom(String)
}

@Model
final class WeeklyPlan {
    /// Always normalized to Monday 00:00 of the represented week.
    var weekStartDate: Date

    @Relationship(deleteRule: .cascade, inverse: \DayPlan.weeklyPlan)
    var days: [DayPlan] = []

    init(weekStartDate: Date) {
        self.weekStartDate = weekStartDate
    }
}

@Model
final class DayPlan {
    /// 0 = Mon, 1 = Tue, ..., 6 = Sun
    var dayIndex: Int
    var strengthType: StrengthDayType
    /// Free-text label for known sports/cardio that day (e.g. "篮球 19:00")
    var plannedCardio: String?
    /// Surfaced if planner detected a constraint conflict (e.g. legs the day before basketball).
    var conflictNote: String?
    var weeklyPlan: WeeklyPlan?

    init(
        dayIndex: Int,
        strengthType: StrengthDayType = .rest,
        plannedCardio: String? = nil,
        conflictNote: String? = nil
    ) {
        self.dayIndex = dayIndex
        self.strengthType = strengthType
        self.plannedCardio = plannedCardio
        self.conflictNote = conflictNote
    }
}
