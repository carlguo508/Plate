import Foundation

/// Daily nutrition targets — stored in UserDefaults so they sync with iCloud key-value if enabled later.
enum Goals {
    private static let kcalKey = "goals.dailyKcal"
    private static let proteinKey = "goals.dailyProteinG"

    static var dailyKcal: Double {
        get {
            let stored = UserDefaults.standard.double(forKey: kcalKey)
            return stored > 0 ? stored : 2000
        }
        set { UserDefaults.standard.set(newValue, forKey: kcalKey) }
    }

    static var dailyProtein: Double {
        get {
            let stored = UserDefaults.standard.double(forKey: proteinKey)
            return stored > 0 ? stored : 120
        }
        set { UserDefaults.standard.set(newValue, forKey: proteinKey) }
    }
}
