import Foundation
import SwiftData

@Model
final class Recipe {
    var name: String
    var steps: String
    var servings: Int
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var ingredients: [RecipeIngredient] = []

    @Relationship(deleteRule: .cascade, inverse: \RecipeNote.recipe)
    var notes: [RecipeNote] = []

    init(
        name: String,
        steps: String = "",
        servings: Int = 1,
        tags: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.name = name
        self.steps = steps
        self.servings = servings
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Nutrition (computed, not stored)

    /// Total grams of `ingredient` used in the whole recipe, resolving count-based quantities via `defaultUnitGrams`.
    private func grams(of item: RecipeIngredient) -> Double {
        if let g = item.grams { return g }
        if let c = item.count, let unit = item.ingredient?.defaultUnitGrams { return Double(c) * unit }
        return 0
    }

    var totalCalories: Double { ingredients.reduce(0) { $0 + nutrientTotal($1, \Ingredient.caloriesPer100g) } }
    var totalProtein: Double { ingredients.reduce(0) { $0 + nutrientTotal($1, \Ingredient.proteinPer100g) } }
    var totalCarbs: Double { ingredients.reduce(0) { $0 + nutrientTotal($1, \Ingredient.carbsPer100g) } }
    var totalFat: Double { ingredients.reduce(0) { $0 + nutrientTotal($1, \Ingredient.fatPer100g) } }

    var perServingCalories: Double { servings > 0 ? totalCalories / Double(servings) : 0 }
    var perServingProtein: Double { servings > 0 ? totalProtein / Double(servings) : 0 }
    var perServingCarbs: Double { servings > 0 ? totalCarbs / Double(servings) : 0 }
    var perServingFat: Double { servings > 0 ? totalFat / Double(servings) : 0 }

    private func nutrientTotal(_ item: RecipeIngredient, _ keyPath: KeyPath<Ingredient, Double>) -> Double {
        guard let ing = item.ingredient else { return 0 }
        return grams(of: item) / 100.0 * ing[keyPath: keyPath]
    }
}

/// One ingredient line in a recipe. Quantity is expressed as either `grams` OR `count` (exactly one non-nil).
@Model
final class RecipeIngredient {
    var ingredient: Ingredient?
    var grams: Double?
    var count: Int?
    var recipe: Recipe?

    init(ingredient: Ingredient, grams: Double) {
        self.ingredient = ingredient
        self.grams = grams
        self.count = nil
    }

    init(ingredient: Ingredient, count: Int) {
        self.ingredient = ingredient
        self.grams = nil
        self.count = count
    }
}

/// A timestamped note attached to a recipe — used for iterative cooking journal entries.
@Model
final class RecipeNote {
    var body: String
    var createdAt: Date
    var recipe: Recipe?

    init(body: String, createdAt: Date = .now) {
        self.body = body
        self.createdAt = createdAt
    }
}
