import Foundation

enum NutritionFormat {
    /// "165" — calories, integer rounded
    static func kcal(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    /// "31.0 g" — macros, one decimal
    static func grams(_ value: Double) -> String {
        String(format: "%.1f g", value)
    }

    /// "200 g" — ingredient gram amount
    static func gramsInt(_ value: Double) -> String {
        "\(Int(value.rounded())) g"
    }
}
