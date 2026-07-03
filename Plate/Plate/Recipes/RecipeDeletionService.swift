import Foundation
import SwiftData

/// Deletes a recipe without corrupting meal history. `MealItem` references a live `Recipe`,
/// so a plain delete would silently zero the nutrition of every past diary entry that used it.
/// Before deleting, referencing items are converted into fixed estimated snapshots.
enum RecipeDeletionService {
    static func delete(_ recipe: Recipe, in context: ModelContext) {
        let allItems = (try? context.fetch(FetchDescriptor<MealItem>())) ?? []
        for item in allItems where item.recipe === recipe {
            snapshot(item)
        }
        context.delete(recipe)
    }

    private static func snapshot(_ item: MealItem) {
        guard let recipe = item.recipe, let servings = item.servings else { return }
        item.estimatedName = recipe.name
        item.estimatedDescription = servings == 1 ? "1 份" : String(format: "%.1f 份", servings)
        item.estimatedCalories = recipe.perServingCalories * servings
        item.estimatedProtein = recipe.perServingProtein * servings
        item.estimatedCarbs = recipe.perServingCarbs * servings
        item.estimatedFat = recipe.perServingFat * servings
        item.estimateConfidence = "菜谱已删除，保留当时数值"
        item.recipe = nil
        item.servings = nil
    }
}
