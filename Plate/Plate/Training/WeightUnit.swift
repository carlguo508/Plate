import Foundation

enum WeightUnit: String, CaseIterable, Identifiable {
    case lb, kg
    var id: String { rawValue }
    var label: String { rawValue }
}

/// User's preferred weight unit. Storage is always in kilograms; this only affects display and input.
enum WeightPreference {
    private static let key = "training.weightUnit"

    static var current: WeightUnit {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key) else { return .lb }
            return WeightUnit(rawValue: raw) ?? .lb
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}

/// kg → lb / lb → kg conversion. Stored canonical value is always kg.
enum WeightConvert {
    static let kgPerLb: Double = 0.45359237
    static let lbPerKg: Double = 1.0 / kgPerLb

    static func display(_ kg: Double, in unit: WeightUnit) -> Double {
        switch unit {
        case .kg: kg
        case .lb: kg * lbPerKg
        }
    }

    static func toKg(_ value: Double, from unit: WeightUnit) -> Double {
        switch unit {
        case .kg: value
        case .lb: value * kgPerLb
        }
    }

    /// "60" or "132" — rounded display string in the chosen unit.
    static func formatted(_ kg: Double, in unit: WeightUnit) -> String {
        let displayed = display(kg, in: unit)
        if abs(displayed - displayed.rounded()) < 0.05 {
            return String(Int(displayed.rounded()))
        }
        return String(format: "%.1f", displayed)
    }
}
