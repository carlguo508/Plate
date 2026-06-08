import Foundation
import SwiftData

enum MealType: String, Codable, CaseIterable {
    case breakfast, lunch, dinner, snack
}

@Model
final class MealEntry {
    var date: Date
    var mealType: MealType

    @Relationship(deleteRule: .cascade, inverse: \MealItem.meal)
    var items: [MealItem] = []

    init(date: Date = .now, mealType: MealType) {
        self.date = date
        self.mealType = mealType
    }

    var totalCalories: Double { items.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { items.reduce(0) { $0 + $1.protein } }
    var totalCarbs: Double { items.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double { items.reduce(0) { $0 + $1.fat } }
}

/// One thing eaten: a recipe portion, a loose ingredient, or a saved estimate.
@Model
final class MealItem {
    var recipe: Recipe?
    /// Recipe portions (allows 0.5 / 1.5 etc.)
    var servings: Double?

    var ingredient: Ingredient?
    var grams: Double?
    var count: Int?

    var estimatedName: String?
    var estimatedDescription: String?
    var estimatedCalories: Double?
    var estimatedProtein: Double?
    var estimatedCarbs: Double?
    var estimatedFat: Double?
    var estimateConfidence: String?
    @Attribute(.externalStorage) var photoData: Data?

    var meal: MealEntry?

    init(recipe: Recipe, servings: Double) {
        self.recipe = recipe
        self.servings = servings
    }

    init(ingredient: Ingredient, grams: Double) {
        self.ingredient = ingredient
        self.grams = grams
    }

    init(ingredient: Ingredient, count: Int) {
        self.ingredient = ingredient
        self.count = count
    }

    init(
        estimatedName: String,
        description: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        confidence: String = "手动估算",
        photoData: Data? = nil
    ) {
        self.estimatedName = estimatedName
        self.estimatedDescription = description
        self.estimatedCalories = calories
        self.estimatedProtein = protein
        self.estimatedCarbs = carbs
        self.estimatedFat = fat
        self.estimateConfidence = confidence
        self.photoData = photoData
    }

    // MARK: - Nutrition

    var calories: Double { estimatedCalories ?? nutrient(\Recipe.perServingCalories, \Ingredient.caloriesPer100g) }
    var protein: Double { estimatedProtein ?? nutrient(\Recipe.perServingProtein, \Ingredient.proteinPer100g) }
    var carbs: Double { estimatedCarbs ?? nutrient(\Recipe.perServingCarbs, \Ingredient.carbsPer100g) }
    var fat: Double { estimatedFat ?? nutrient(\Recipe.perServingFat, \Ingredient.fatPer100g) }

    private func nutrient(
        _ recipeKeyPath: KeyPath<Recipe, Double>,
        _ ingredientKeyPath: KeyPath<Ingredient, Double>
    ) -> Double {
        if let recipe, let servings {
            return recipe[keyPath: recipeKeyPath] * servings
        }
        if let ingredient {
            let g = ingredientGrams(for: ingredient)
            return g / 100.0 * ingredient[keyPath: ingredientKeyPath]
        }
        return 0
    }

    private func ingredientGrams(for ingredient: Ingredient) -> Double {
        if let grams { return grams }
        if let count, let unit = ingredient.defaultUnitGrams { return Double(count) * unit }
        return 0
    }
}
