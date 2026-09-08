import SwiftData

/// Idempotently upgrades recipe-backed history created before nutrition snapshots existed.
enum MealNutritionSnapshotService {
    static func backfillMissingRecipeSnapshots(in context: ModelContext) {
        let items = (try? context.fetch(FetchDescriptor<MealItem>())) ?? []
        var changed = false

        for item in items {
            guard let recipe = item.recipe, let servings = item.servings else { continue }
            if item.estimatedName == nil {
                item.estimatedName = recipe.name
                changed = true
            }
            if item.estimatedCalories == nil {
                item.estimatedCalories = recipe.perServingCalories * servings
                changed = true
            }
            if item.estimatedProtein == nil {
                item.estimatedProtein = recipe.perServingProtein * servings
                changed = true
            }
            if item.estimatedCarbs == nil {
                item.estimatedCarbs = recipe.perServingCarbs * servings
                changed = true
            }
            if item.estimatedFat == nil {
                item.estimatedFat = recipe.perServingFat * servings
                changed = true
            }
        }

        if changed {
            try? context.save()
        }
    }
}
