import Foundation
import SwiftData

/// Builds suggestion lists for the cardio and strength log sheets. User-typed values from past
/// workouts are surfaced first (most recent first); built-in seeds fill in behind so day-one users
/// also have things to tap.
enum SuggestionService {
    static let seedCardio: [String] = [
        "篮球", "跑步", "骑车", "游泳", "羽毛球",
        "网球", "足球", "瑜伽", "登山", "椭圆机",
        "划船机", "跳绳",
    ]

    static let seedStrength: [String] = [
        "卧推", "深蹲", "硬拉", "肩推", "引体向上",
        "划船", "高位下拉", "腿举", "罗马尼亚硬拉", "弓步蹲",
        "哑铃推举", "哑铃飞鸟", "二头弯举", "三头下压", "腿屈伸",
        "腿弯举", "臀推",
    ]

    static func cardioActivities(in context: ModelContext) -> [String] {
        let all = (try? context.fetch(FetchDescriptor<WorkoutEntry>())) ?? []
        return ordered(
            historyValues: all
                .filter { $0.kind == .cardio }
                .sorted(by: { $0.date > $1.date })
                .compactMap { $0.cardioActivity?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty },
            seeds: seedCardio
        )
    }

    static func strengthExercises(in context: ModelContext) -> [String] {
        let all = (try? context.fetch(FetchDescriptor<ExerciseSet>())) ?? []
        return ordered(
            historyValues: all
                .sorted(by: { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) })
                .map { $0.exerciseName.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty },
            seeds: seedStrength
        )
    }

    /// Recent unique history first, then seeds that aren't already in history.
    private static func ordered(historyValues: [String], seeds: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in historyValues where !seen.contains(value) {
            result.append(value)
            seen.insert(value)
        }
        for seed in seeds where !seen.contains(seed) {
            result.append(seed)
            seen.insert(seed)
        }
        return result
    }
}
