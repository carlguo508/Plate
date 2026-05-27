import Foundation
import SwiftData

enum SeedData {
    /// Inserts built-in ingredients on first launch. Idempotent: a second call is a no-op.
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Ingredient>(predicate: #Predicate { $0.isBuiltIn == true })
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for definition in BuiltInIngredients.all {
            let ingredient = Ingredient(
                name: definition.name,
                category: definition.category,
                caloriesPer100g: definition.kcal100g,
                proteinPer100g: definition.protein100g,
                carbsPer100g: definition.carbs100g,
                fatPer100g: definition.fat100g,
                defaultUnitGrams: definition.defaultUnitGrams,
                isBuiltIn: true
            )
            context.insert(ingredient)
        }

        try? context.save()
    }
}
