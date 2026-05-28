import Foundation

/// User's default weekly strength routine. Stored as 7 strings (Mon..Sun), each one of the
/// standard codes ("rest", "push", "pull", "legs", "upper", "lower", "full") or a free-form
/// custom label.
enum DefaultTemplate {
    private static let key = "training.defaultTemplate"

    static let fallback: [String] = ["push", "rest", "pull", "rest", "legs", "rest", "rest"]

    static let standardCodes: [String] = ["rest", "push", "pull", "legs", "upper", "lower", "full"]

    static func load() -> [String] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let arr = try? JSONDecoder().decode([String].self, from: data),
            arr.count == 7
        else {
            return fallback
        }
        return arr
    }

    static func save(_ days: [String]) {
        guard days.count == 7, let data = try? JSONEncoder().encode(days) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func strengthType(from raw: String) -> StrengthDayType {
        switch raw {
        case "rest": return .rest
        case "push": return .push
        case "pull": return .pull
        case "legs": return .legs
        case "upper": return .upper
        case "lower": return .lower
        case "full": return .full
        default: return .custom(raw)
        }
    }

    static func raw(from strength: StrengthDayType) -> String {
        switch strength {
        case .rest: return "rest"
        case .push: return "push"
        case .pull: return "pull"
        case .legs: return "legs"
        case .upper: return "upper"
        case .lower: return "lower"
        case .full: return "full"
        case .custom(let s): return s
        }
    }

    /// User-facing label, e.g. "腿" for `.legs`, falling back to the custom string.
    static func displayLabel(_ raw: String) -> String {
        switch raw {
        case "rest": return "休息"
        case "push": return "推"
        case "pull": return "拉"
        case "legs": return "腿"
        case "upper": return "上肢"
        case "lower": return "下肢"
        case "full": return "全身"
        default: return raw
        }
    }
}
