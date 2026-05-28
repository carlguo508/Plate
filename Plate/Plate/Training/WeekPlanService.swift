import Foundation
import SwiftData

enum WeekPlanService {
    /// Monday 00:00 of the week containing `date`.
    static func mondayStart(of date: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }

    /// Returns the WeeklyPlan for the given week, creating one from the default template if missing.
    static func planForWeek(of date: Date, in context: ModelContext) -> WeeklyPlan {
        let start = mondayStart(of: date)
        let descriptor = FetchDescriptor<WeeklyPlan>(
            predicate: #Predicate { $0.weekStartDate == start }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let plan = WeeklyPlan(weekStartDate: start)
        context.insert(plan)
        let template = DefaultTemplate.load()
        for i in 0..<7 {
            let raw = i < template.count ? template[i] : "rest"
            let day = DayPlan(
                dayIndex: i,
                strengthType: DefaultTemplate.strengthType(from: raw)
            )
            day.weeklyPlan = plan
            plan.days.append(day)
            context.insert(day)
        }
        try? context.save()
        return plan
    }

    static func date(forDay dayIndex: Int, in plan: WeeklyPlan, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: dayIndex, to: plan.weekStartDate) ?? plan.weekStartDate
    }

    // MARK: - Conflict detection

    /// Activities that meaningfully stress the lower body — used to flag legs-day adjacency conflicts.
    static let heavyLowerBodyKeywords = ["篮球", "足球", "跑步", "网球", "羽毛球", "登山", "爬山", "马拉松"]

    /// Returns conflict notes by dayIndex for the given plan (computed, not stored).
    static func conflicts(in plan: WeeklyPlan) -> [Int: String] {
        var notes: [Int: String] = [:]
        let byIndex = Dictionary(uniqueKeysWithValues: plan.days.map { ($0.dayIndex, $0) })

        func hasHeavyCardio(_ day: DayPlan?) -> Bool {
            guard let text = day?.plannedCardio, !text.isEmpty else { return false }
            return heavyLowerBodyKeywords.contains(where: { text.contains($0) })
        }

        for day in plan.days where day.strengthType == .legs {
            let prev = byIndex[day.dayIndex - 1]
            let next = byIndex[day.dayIndex + 1]
            if hasHeavyCardio(prev) {
                notes[day.dayIndex] = "前一天有强度有氧（\(prev?.plannedCardio ?? "")），腿日恢复可能不够"
            } else if hasHeavyCardio(next) {
                notes[day.dayIndex] = "次日有强度有氧（\(next?.plannedCardio ?? "")），可能影响表现"
            }
        }
        return notes
    }
}
