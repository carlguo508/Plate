import Foundation

enum StrengthRoutine: String, CaseIterable, Identifiable {
    case push
    case pull
    case legs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .push: "练胸"
        case .pull: "练背"
        case .legs: "练腿"
        }
    }

    var muscleGroups: String {
        switch self {
        case .push: "胸 · 肩 · 三头"
        case .pull: "背 · 二头"
        case .legs: "腿"
        }
    }

    var savedNames: [String] {
        switch self {
        case .push: ["练胸", "胸"]
        case .pull: ["练背", "背"]
        case .legs: ["练腿", "腿"]
        }
    }

    var defaultTemplate: WorkoutTemplate {
        WorkoutTemplate(name: title, sets: defaultSets)
    }

    func template(from savedTemplates: [WorkoutTemplate]) -> WorkoutTemplate {
        savedTemplates.first { template in
            savedNames.contains { name in
                template.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
        } ?? defaultTemplate
    }

    private var defaultSets: [WorkoutTemplateSet] {
        let exercises: [(String, Int)]
        switch self {
        case .push:
            exercises = [
                ("卧推", 8),
                ("上斜哑铃卧推", 10),
                ("肩推", 10),
                ("侧平举", 12),
                ("绳索下压", 12),
            ]
        case .pull:
            exercises = [
                ("高位下拉", 10),
                ("坐姿划船", 10),
                ("单臂哑铃划船", 10),
                ("杠铃弯举", 10),
                ("锤式弯举", 12),
            ]
        case .legs:
            exercises = [
                ("深蹲", 8),
                ("罗马尼亚硬拉", 10),
                ("腿举", 10),
                ("腿弯举", 12),
                ("提踵", 15),
            ]
        }

        return exercises.flatMap { exercise, reps in
            (0..<3).map { _ in
                WorkoutTemplateSet(exerciseName: exercise, weightKg: 0, reps: reps)
            }
        }
    }
}
