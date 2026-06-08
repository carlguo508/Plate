import Foundation
import Testing
import SwiftData
@testable import Plate

@MainActor
struct ModelTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Ingredient.self,
            Recipe.self, RecipeIngredient.self, RecipeNote.self,
            MealEntry.self, MealItem.self,
            WorkoutEntry.self, ExerciseSet.self,
            WeeklyPlan.self, DayPlan.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Ingredient

    @Test func ingredientCanBeInsertedAndFetched() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let egg = Ingredient(
            name: "鸡蛋", category: .protein,
            caloriesPer100g: 144, proteinPer100g: 13, carbsPer100g: 0.7, fatPer100g: 9,
            defaultUnitGrams: 50
        )
        ctx.insert(egg)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Ingredient>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "鸡蛋")
        #expect(fetched.first?.defaultUnitGrams == 50)
    }

    // MARK: - Recipe nutrition math

    @Test func recipeTotalsMixGramsAndCounts() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let egg = Ingredient(
            name: "鸡蛋", category: .protein,
            caloriesPer100g: 144, proteinPer100g: 13, carbsPer100g: 0.7, fatPer100g: 9,
            defaultUnitGrams: 50
        )
        let tomato = Ingredient(
            name: "西红柿", category: .vegetable,
            caloriesPer100g: 18, proteinPer100g: 0.9, carbsPer100g: 3.9, fatPer100g: 0.2,
            defaultUnitGrams: 150
        )
        ctx.insert(egg)
        ctx.insert(tomato)

        let recipe = Recipe(name: "番茄炒蛋", servings: 2)
        recipe.ingredients.append(RecipeIngredient(ingredient: egg, count: 2))      // 2 eggs = 100g
        recipe.ingredients.append(RecipeIngredient(ingredient: tomato, grams: 200)) // 200g tomato
        ctx.insert(recipe)
        try ctx.save()

        // 100g egg = 144 kcal; 200g tomato = 36 kcal → total = 180 kcal
        #expect(abs(recipe.totalCalories - 180) < 0.01)
        // per serving (servings = 2) → 90 kcal
        #expect(abs(recipe.perServingCalories - 90) < 0.01)
    }

    // MARK: - MealEntry referencing recipe and loose ingredient

    @Test func mealEntryAggregatesRecipeAndLooseItems() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let chicken = Ingredient(
            name: "鸡胸肉", category: .protein,
            caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6
        )
        let banana = Ingredient(
            name: "香蕉", category: .fruit,
            caloriesPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23, fatPer100g: 0.3,
            defaultUnitGrams: 120
        )
        ctx.insert(chicken)
        ctx.insert(banana)

        let recipe = Recipe(name: "白灼鸡胸", servings: 1)
        recipe.ingredients.append(RecipeIngredient(ingredient: chicken, grams: 200))
        ctx.insert(recipe)

        let meal = MealEntry(mealType: .lunch)
        meal.items.append(MealItem(recipe: recipe, servings: 1))     // 200g chicken → 330 kcal
        meal.items.append(MealItem(ingredient: banana, count: 1))    // 1 banana ≈ 120g → ~107 kcal
        ctx.insert(meal)
        try ctx.save()

        let expected = (200.0 / 100 * 165) + (120.0 / 100 * 89) // 330 + 106.8 = 436.8
        #expect(abs(meal.totalCalories - expected) < 0.1)
    }

    @Test func mealCopyPreservesAllSupportedItemQuantities() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let egg = Ingredient(
            name: "鸡蛋", category: .protein,
            caloriesPer100g: 144, proteinPer100g: 13, carbsPer100g: 0.7, fatPer100g: 9,
            defaultUnitGrams: 50
        )
        let rice = Ingredient(
            name: "白米饭", category: .grain,
            caloriesPer100g: 116, proteinPer100g: 2.6, carbsPer100g: 25.6, fatPer100g: 0.3
        )
        let recipe = Recipe(name: "蛋炒饭", servings: 2)
        recipe.ingredients.append(RecipeIngredient(ingredient: egg, count: 2))

        let source = MealEntry(date: .now, mealType: .lunch)
        source.items.append(MealItem(recipe: recipe, servings: 1.5))
        source.items.append(MealItem(ingredient: rice, grams: 180))
        source.items.append(MealItem(ingredient: egg, count: 1))
        source.items.append(MealItem(
            estimatedName: "外食盖饭",
            description: "一碗",
            calories: 650,
            protein: 35,
            carbs: 80,
            fat: 20
        ))
        ctx.insert(source)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: source.date)!
        let copied = MealCopyService.copy(source, to: tomorrow, in: ctx)
        try ctx.save()

        #expect(copied.mealType == .lunch)
        #expect(copied.items.count == 4)
        #expect(copied.items.contains { $0.recipe === recipe && $0.servings == 1.5 })
        #expect(copied.items.contains { $0.ingredient === rice && $0.grams == 180 })
        #expect(copied.items.contains { $0.ingredient === egg && $0.count == 1 })
        #expect(copied.items.contains {
            $0.estimatedName == "外食盖饭" && $0.calories == 650 && $0.protein == 35
        })
    }

    // MARK: - Workout

    @Test func strengthWorkoutTracksSets() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let workout = WorkoutEntry.strength(notes: "felt strong")
        workout.sets.append(ExerciseSet(exerciseName: "卧推", weightKg: 60, reps: 8, order: 0))
        workout.sets.append(ExerciseSet(exerciseName: "卧推", weightKg: 60, reps: 8, order: 1))
        ctx.insert(workout)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<WorkoutEntry>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.kind == .strength)
        #expect(fetched.first?.sets.count == 2)
    }

    @Test func cardioWorkoutCapturesIntensity() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let workout = WorkoutEntry.cardio(activity: "篮球", durationMinutes: 90, intensity: .high)
        ctx.insert(workout)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<WorkoutEntry>())
        #expect(fetched.first?.cardioActivity == "篮球")
        #expect(fetched.first?.cardioDurationMinutes == 90)
        #expect(fetched.first?.cardioIntensity == .high)
    }

    @Test func workoutDayKeepsOnlyOneKind() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let date = Date()
        ctx.insert(WorkoutEntry.strength(date: date))
        ctx.insert(WorkoutEntry.cardio(
            activity: "篮球",
            durationMinutes: 60,
            intensity: .medium,
            date: date
        ))
        try ctx.save()

        WorkoutDayService.enforceSingleWorkout(kind: .cardio, on: date, in: ctx)
        try ctx.save()

        let workouts = try ctx.fetch(FetchDescriptor<WorkoutEntry>())
        #expect(workouts.count == 1)
        #expect(workouts.first?.kind == .cardio)
    }

    // MARK: - WeeklyPlan

    @Test func weeklyPlanHoldsSevenDayPlans() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let plan = WeeklyPlan(weekStartDate: Date())
        for i in 0..<7 {
            plan.days.append(DayPlan(dayIndex: i, strengthType: i == 0 ? .push : .rest))
        }
        ctx.insert(plan)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<WeeklyPlan>())
        #expect(fetched.first?.days.count == 7)
        #expect(fetched.first?.days.first(where: { $0.dayIndex == 0 })?.strengthType == .push)
    }
}

@MainActor
struct SeedDataTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Ingredient.self,
            Recipe.self, RecipeIngredient.self, RecipeNote.self,
            MealEntry.self, MealItem.self,
            WorkoutEntry.self, ExerciseSet.self,
            WeeklyPlan.self, DayPlan.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func seedInsertsBuiltInIngredients() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        SeedData.seedIfNeeded(context: ctx)

        let all = try ctx.fetch(FetchDescriptor<Ingredient>())
        #expect(all.count == BuiltInIngredients.all.count)
        #expect(all.allSatisfy { $0.isBuiltIn })
    }

    @Test func seedIsIdempotent() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        SeedData.seedIfNeeded(context: ctx)
        SeedData.seedIfNeeded(context: ctx)

        let all = try ctx.fetch(FetchDescriptor<Ingredient>())
        #expect(all.count == BuiltInIngredients.all.count)
    }
}
