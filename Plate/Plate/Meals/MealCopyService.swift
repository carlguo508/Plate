import Foundation
import SwiftData

enum MealCopyService {
    @discardableResult
    static func copy(
        _ source: MealEntry,
        to date: Date,
        mealType: MealType? = nil,
        in context: ModelContext
    ) -> MealEntry {
        let meal = MealEntry(date: date, mealType: mealType ?? source.mealType)
        context.insert(meal)
        copyItems(from: source, to: meal, in: context)
        return meal
    }

    static func copyItems(from source: MealEntry, to meal: MealEntry, in context: ModelContext) {
        for sourceItem in source.items {
            guard let item = copyItem(sourceItem) else { continue }
            item.meal = meal
            meal.items.append(item)
            context.insert(item)
        }
    }

    private static func copyItem(_ source: MealItem) -> MealItem? {
        if let recipe = source.recipe, let servings = source.servings {
            return MealItem(recipe: recipe, servings: servings)
        }
        if let ingredient = source.ingredient, let grams = source.grams {
            return MealItem(ingredient: ingredient, grams: grams)
        }
        if let ingredient = source.ingredient, let count = source.count {
            return MealItem(ingredient: ingredient, count: count)
        }
        return nil
    }
}
