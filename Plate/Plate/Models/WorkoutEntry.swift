import Foundation
import SwiftData

enum WorkoutKind: String, Codable {
    case strength, cardio
}

enum CardioIntensity: String, Codable, CaseIterable {
    case low, medium, high
}

@Model
final class WorkoutEntry {
    var date: Date
    var kind: WorkoutKind
    var notes: String

    // Strength-only
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workout)
    var sets: [ExerciseSet] = []

    // Cardio-only
    var cardioActivity: String?         // e.g. "篮球", "跑步"
    var cardioDurationMinutes: Int?
    var cardioIntensity: CardioIntensity?

    private init(date: Date, kind: WorkoutKind, notes: String) {
        self.date = date
        self.kind = kind
        self.notes = notes
    }

    static func strength(date: Date = .now, notes: String = "") -> WorkoutEntry {
        WorkoutEntry(date: date, kind: .strength, notes: notes)
    }

    static func cardio(
        activity: String,
        durationMinutes: Int,
        intensity: CardioIntensity,
        date: Date = .now,
        notes: String = ""
    ) -> WorkoutEntry {
        let w = WorkoutEntry(date: date, kind: .cardio, notes: notes)
        w.cardioActivity = activity
        w.cardioDurationMinutes = durationMinutes
        w.cardioIntensity = intensity
        return w
    }
}

/// One set of one exercise during a strength workout.
@Model
final class ExerciseSet {
    var exerciseName: String
    var weightKg: Double
    var reps: Int
    var order: Int
    var workout: WorkoutEntry?

    init(exerciseName: String, weightKg: Double, reps: Int, order: Int = 0) {
        self.exerciseName = exerciseName
        self.weightKg = weightKg
        self.reps = reps
        self.order = order
    }
}
