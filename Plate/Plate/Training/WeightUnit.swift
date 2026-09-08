import Foundation

enum WeightUnit: String, CaseIterable, Identifiable {
    case lb, kg
    var id: String { rawValue }
    var label: String { rawValue }
}

/// User's preferred weight unit. Storage is always in kilograms; this only affects display and input.
enum WeightPreference {
    static let key = "training.weightUnit"
    private static let lbDefaultMigrationKey = "training.weightUnit.defaultedToLb.v2"

    static var current: WeightUnit {
        get { current(in: .standard) }
        set { set(newValue, in: .standard) }
    }

    static func current(in defaults: UserDefaults) -> WeightUnit {
        if !defaults.bool(forKey: lbDefaultMigrationKey) {
            defaults.set(WeightUnit.lb.rawValue, forKey: key)
            defaults.set(true, forKey: lbDefaultMigrationKey)
            return .lb
        }
        guard let raw = defaults.string(forKey: key) else { return .lb }
        return WeightUnit(rawValue: raw) ?? .lb
    }

    static func set(_ unit: WeightUnit, in defaults: UserDefaults) {
        defaults.set(unit.rawValue, forKey: key)
        defaults.set(true, forKey: lbDefaultMigrationKey)
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
