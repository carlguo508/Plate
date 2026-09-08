import Foundation

struct WorkoutTemplate: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var sets: [WorkoutTemplateSet]
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        sets: [WorkoutTemplateSet],
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.updatedAt = updatedAt
    }
}

struct WorkoutTemplateSet: Codable, Equatable {
    var exerciseName: String
    var weightKg: Double
    var reps: Int
}

enum WorkoutTemplateStore {
    static let key = "training.workoutTemplates"

    static func load(from defaults: UserDefaults = .standard) -> [WorkoutTemplate] {
        guard let data = defaults.data(forKey: key),
              let templates = try? JSONDecoder().decode([WorkoutTemplate].self, from: data) else {
            return []
        }
        return templates.sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    static func save(
        name: String,
        sets: [WorkoutTemplateSet],
        in defaults: UserDefaults = .standard
    ) -> [WorkoutTemplate] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !sets.isEmpty else { return load(from: defaults) }

        var templates = load(from: defaults)
        if let index = templates.firstIndex(where: { normalized($0.name) == normalized(trimmed) }) {
            templates[index].name = trimmed
            templates[index].sets = sets
            templates[index].updatedAt = .now
        } else {
            templates.append(WorkoutTemplate(name: trimmed, sets: sets))
        }
        persist(templates, in: defaults)
        return load(from: defaults)
    }

    @discardableResult
    static func delete(_ template: WorkoutTemplate, from defaults: UserDefaults = .standard) -> [WorkoutTemplate] {
        let templates = load(from: defaults).filter { $0.id != template.id }
        persist(templates, in: defaults)
        return templates
    }

    private static func persist(_ templates: [WorkoutTemplate], in defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(templates) else { return }
        defaults.set(data, forKey: key)
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
