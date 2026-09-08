import Foundation
import SwiftData

enum WorkoutDayService {
    /// Keeps at most one workout of `kind` on the day without deleting a different workout type.
    static func enforceSingleWorkout(
        kind: WorkoutKind,
        on date: Date,
        in context: ModelContext
    ) {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let descriptor = FetchDescriptor<WorkoutEntry>(
            predicate: #Predicate { $0.date >= dayStart && $0.date < dayEnd },
            sortBy: [SortDescriptor(\.date)]
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        var keptMatchingEntry = false

        for entry in entries {
            guard entry.kind == kind else { continue }
            if keptMatchingEntry {
                context.delete(entry)
            } else {
                keptMatchingEntry = true
            }
        }
    }
}
