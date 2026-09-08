import Foundation

enum ReviewWindow {
    static func startDate(days: Int, today: Date, calendar: Calendar = .current) -> Date {
        let normalizedToday = calendar.startOfDay(for: today)
        return calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: normalizedToday)
            ?? normalizedToday
    }
}
