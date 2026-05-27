import Foundation
import SwiftData

enum IngredientCategory: String, Codable, CaseIterable {
    case protein, grain, vegetable, fruit, dairy, fat, seasoning, nut, other
}

@Model
final class Ingredient {
    var name: String
    var category: IngredientCategory
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    /// One natural unit in grams (e.g. 1 egg ≈ 50g). `nil` means this ingredient is only sensibly measured by mass.
    var defaultUnitGrams: Double?
    var isBuiltIn: Bool
    var createdAt: Date

    init(
        name: String,
        category: IngredientCategory,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        defaultUnitGrams: Double? = nil,
        isBuiltIn: Bool = false,
        createdAt: Date = .now
    ) {
        self.name = name
        self.category = category
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.defaultUnitGrams = defaultUnitGrams
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
    }
}
