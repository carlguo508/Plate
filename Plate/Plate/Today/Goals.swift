import Foundation

/// Daily nutrition targets — stored in UserDefaults so they sync with iCloud key-value if enabled later.
enum Goals {
    private static let kcalKey = "goals.dailyKcal"
    private static let proteinKey = "goals.dailyProteinG"
    private static let baselineBurnKey = "goals.baselineDailyBurn"
    private static let aiEndpointKey = "ai.endpoint"
    private static let aiAccessTokenKey = "ai.accessToken"

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

    /// Estimated full-day expenditure before logged exercise is added.
    static var baselineDailyBurn: Double {
        get {
            let stored = UserDefaults.standard.double(forKey: baselineBurnKey)
            return stored > 0 ? stored : 2100
        }
        set { UserDefaults.standard.set(newValue, forKey: baselineBurnKey) }
    }

    static var aiEndpoint: String {
        get { UserDefaults.standard.string(forKey: aiEndpointKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: aiEndpointKey) }
    }

    static var aiAccessToken: String {
        get { UserDefaults.standard.string(forKey: aiAccessTokenKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: aiAccessTokenKey) }
    }
}
