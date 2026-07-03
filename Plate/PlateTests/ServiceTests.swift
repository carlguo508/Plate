import Foundation
import Testing
import SwiftData
@testable import Plate

@MainActor
struct ServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Ingredient.self,
            Recipe.self, RecipeIngredient.self, RecipeNote.self,
            MealEntry.self, MealItem.self,
            WorkoutEntry.self, ExerciseSet.self,
            WeeklyPlan.self, DayPlan.self,
            BodyWeightEntry.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeEgg() -> Ingredient {
        Ingredient(
            name: "鸡蛋", category: .protein,
            caloriesPer100g: 144, proteinPer100g: 13, carbsPer100g: 0.7, fatPer100g: 9,
            defaultUnitGrams: 50
        )
    }

    // MARK: - Recipe deletion must not wipe logged meal history

    @Test func deletingRecipePreservesLoggedMealNutrition() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let egg = makeEgg()
        ctx.insert(egg)
        let recipe = Recipe(name: "番茄炒蛋", servings: 2)
        recipe.ingredients.append(RecipeIngredient(ingredient: egg, count: 4)) // 200g egg = 288 kcal, 144/serving
        ctx.insert(recipe)

        let meal = MealEntry(mealType: .lunch)
        let item = MealItem(recipe: recipe, servings: 1.5)
        item.meal = meal
        meal.items.append(item)
        ctx.insert(meal)
        try ctx.save()

        let caloriesBefore = item.calories
        let proteinBefore = item.protein
        #expect(caloriesBefore > 0)

        RecipeDeletionService.delete(recipe, in: ctx)
        try ctx.save()

        let recipes = try ctx.fetch(FetchDescriptor<Recipe>())
        #expect(recipes.isEmpty)

        let items = try ctx.fetch(FetchDescriptor<MealItem>())
        #expect(items.count == 1)
        let survivor = try #require(items.first)
        #expect(survivor.estimatedName == "番茄炒蛋")
        #expect(abs(survivor.calories - caloriesBefore) < 0.01)
        #expect(abs(survivor.protein - proteinBefore) < 0.01)
    }

    @Test func deletingUnloggedRecipeJustDeletes() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let recipe = Recipe(name: "白灼菜心", servings: 1)
        ctx.insert(recipe)
        try ctx.save()

        RecipeDeletionService.delete(recipe, in: ctx)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<Recipe>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<MealItem>()).isEmpty)
    }

    // MARK: - WeekPlanService

    @Test func mondayStartNormalizesMidweekDates() {
        var cal = Calendar.current
        cal.firstWeekday = 2
        // 2026-07-02 is a Thursday; its Monday is 2026-06-29.
        let thursday = DateComponents(calendar: .current, year: 2026, month: 7, day: 2, hour: 15).date!
        let monday = WeekPlanService.mondayStart(of: thursday)
        let comps = Calendar.current.dateComponents([.year, .month, .day, .weekday, .hour], from: monday)
        #expect(comps.weekday == 2) // Monday
        #expect(comps.year == 2026)
        #expect(comps.month == 6)
        #expect(comps.day == 29)
        #expect(comps.hour == 0)
    }

    @Test func planForWeekCreatesSevenDaysAndIsIdempotent() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let first = WeekPlanService.planForWeek(of: .now, in: ctx)
        #expect(first.days.count == 7)
        #expect(Set(first.days.map(\.dayIndex)) == Set(0..<7))

        let second = WeekPlanService.planForWeek(of: .now, in: ctx)
        #expect(second === first)
        #expect(try ctx.fetch(FetchDescriptor<WeeklyPlan>()).count == 1)
    }

    @Test func legsDayAdjacentToBasketballIsFlagged() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let plan = WeeklyPlan(weekStartDate: WeekPlanService.mondayStart(of: .now))
        for i in 0..<7 {
            plan.days.append(DayPlan(dayIndex: i))
        }
        plan.days.first { $0.dayIndex == 2 }?.strengthType = .legs
        plan.days.first { $0.dayIndex == 1 }?.plannedCardio = "篮球 19:00"
        ctx.insert(plan)

        let conflicts = WeekPlanService.conflicts(in: plan)
        #expect(conflicts[2] != nil)
        #expect(conflicts[1] == nil)
    }

    @Test func legsDayWithoutHeavyCardioNearbyHasNoConflict() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let plan = WeeklyPlan(weekStartDate: WeekPlanService.mondayStart(of: .now))
        for i in 0..<7 {
            plan.days.append(DayPlan(dayIndex: i))
        }
        plan.days.first { $0.dayIndex == 2 }?.strengthType = .legs
        plan.days.first { $0.dayIndex == 1 }?.plannedCardio = "瑜伽"
        ctx.insert(plan)

        #expect(WeekPlanService.conflicts(in: plan).isEmpty)
    }

    // MARK: - WeightConvert

    @Test func weightConversionRoundTrips() {
        let kg = WeightConvert.toKg(132.0, from: .lb)
        #expect(abs(kg - 59.874) < 0.01)
        #expect(abs(WeightConvert.display(kg, in: .lb) - 132.0) < 0.0001)
        #expect(WeightConvert.display(70, in: .kg) == 70)
    }

    @Test func weightFormattingDropsTrivialDecimals() {
        #expect(WeightConvert.formatted(70, in: .kg) == "70")
        #expect(WeightConvert.formatted(70.55, in: .kg) == "70.5")
    }

    // MARK: - DefaultTemplate

    @Test func strengthTypeRawRoundTrip() {
        for code in DefaultTemplate.standardCodes {
            #expect(DefaultTemplate.raw(from: DefaultTemplate.strengthType(from: code)) == code)
        }
        #expect(DefaultTemplate.strengthType(from: "手臂日") == .custom("手臂日"))
        #expect(DefaultTemplate.raw(from: .custom("手臂日")) == "手臂日")
    }

    // MARK: - SuggestionService

    @Test func cardioSuggestionsPutRecentHistoryBeforeSeeds() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let older = WorkoutEntry.cardio(
            activity: "爬楼梯", durationMinutes: 20, intensity: .medium,
            date: Calendar.current.date(byAdding: .day, value: -3, to: .now)!
        )
        let newer = WorkoutEntry.cardio(
            activity: "篮球", durationMinutes: 60, intensity: .high,
            date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        )
        ctx.insert(older)
        ctx.insert(newer)
        try ctx.save()

        let suggestions = SuggestionService.cardioActivities(in: ctx)
        #expect(suggestions.first == "篮球")
        #expect(suggestions[1] == "爬楼梯")
        // Seeds still present, deduplicated
        #expect(suggestions.filter { $0 == "篮球" }.count == 1)
        #expect(suggestions.contains("游泳"))
    }

    // MARK: - MealCopyService merging

    @Test func copyItemsAppendsIntoExistingMeal() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let egg = makeEgg()
        ctx.insert(egg)

        let source = MealEntry(
            date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
            mealType: .breakfast
        )
        source.items.append(MealItem(ingredient: egg, count: 2))
        ctx.insert(source)

        let target = MealEntry(date: .now, mealType: .breakfast)
        target.items.append(MealItem(ingredient: egg, count: 1))
        ctx.insert(target)
        try ctx.save()

        MealCopyService.copyItems(from: source, to: target, in: ctx)
        try ctx.save()

        #expect(target.items.count == 2)
        #expect(source.items.count == 1)
    }

    // MARK: - FrequentMealService

    @Test func frequentMealsNormalizeNamesAndRespectLimit() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let meal = MealEntry(date: .now, mealType: .breakfast)
        for name in ["Latte", "latte ", "LATTE"] {
            let item = MealItem(
                estimatedName: name, description: "", calories: 200,
                protein: 10, carbs: 20, fat: 8
            )
            item.meal = meal
            meal.items.append(item)
        }
        for i in 0..<10 {
            let item = MealItem(
                estimatedName: "食物\(i)", description: "", calories: 100,
                protein: 5, carbs: 10, fat: 3
            )
            item.meal = meal
            meal.items.append(item)
        }
        ctx.insert(meal)
        try ctx.save()

        let options = FrequentMealService.options(from: [meal], preferredMealType: .breakfast)
        #expect(options.count == 8) // limit
        #expect(options.first?.usageCount == 3) // three lattes merged
    }

    @Test func unnamedOrUnusableItemsAreExcludedFromFrequentMeals() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let meal = MealEntry(date: .now, mealType: .lunch)
        // Ingredient item without grams or count can't be reused
        let egg = makeEgg()
        ctx.insert(egg)
        let broken = MealItem(ingredient: egg, grams: 100)
        broken.grams = nil
        broken.meal = meal
        meal.items.append(broken)
        ctx.insert(meal)
        try ctx.save()

        #expect(FrequentMealService.options(from: [meal], preferredMealType: nil).isEmpty)
    }

    // MARK: - EnergyBalanceService edge cases

    @Test func strengthEstimateIsBoundedAndZeroWithoutSets() {
        let empty = WorkoutEntry.strength()
        #expect(EnergyBalanceService.estimatedExerciseCalories(empty, bodyWeightKg: 70) == 0)

        let small = WorkoutEntry.strength()
        small.sets.append(ExerciseSet(exerciseName: "卧推", weightKg: 60, reps: 8))
        #expect(EnergyBalanceService.estimatedExerciseCalories(small, bodyWeightKg: 70) == 80)

        let huge = WorkoutEntry.strength()
        for i in 0..<100 {
            huge.sets.append(ExerciseSet(exerciseName: "深蹲", weightKg: 100, reps: 5, order: i))
        }
        #expect(EnergyBalanceService.estimatedExerciseCalories(huge, bodyWeightKg: 70) == 500)
    }

    @Test func unknownCardioActivityUsesDefaultMET() {
        let workout = WorkoutEntry.cardio(activity: "攀岩", durationMinutes: 60, intensity: .medium)
        // default MET 6: 6 * 3.5 * 70 / 200 * 60 = 441
        let estimate = EnergyBalanceService.estimatedExerciseCalories(workout, bodyWeightKg: 70)
        #expect(abs(estimate - 441) < 0.01)
    }

    // MARK: - MealItem edge cases

    @Test func countItemWithoutDefaultUnitGramsHasZeroNutrition() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let rice = Ingredient(
            name: "白米饭", category: .grain,
            caloriesPer100g: 116, proteinPer100g: 2.6, carbsPer100g: 25.6, fatPer100g: 0.3
        )
        ctx.insert(rice)
        let item = MealItem(ingredient: rice, count: 2)
        ctx.insert(item)
        #expect(item.calories == 0)
    }

    @Test func zeroServingsRecipeDoesNotDivideByZero() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let egg = makeEgg()
        ctx.insert(egg)
        let recipe = Recipe(name: "测试", servings: 0)
        recipe.ingredients.append(RecipeIngredient(ingredient: egg, grams: 100))
        ctx.insert(recipe)
        #expect(recipe.perServingCalories == 0)
        #expect(recipe.totalCalories == 144)
    }

    // MARK: - WorkoutDayService duplicates

    @Test func duplicateWorkoutsOfSameKindAreCollapsed() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let date = Date()
        ctx.insert(WorkoutEntry.cardio(activity: "跑步", durationMinutes: 30, intensity: .low, date: date))
        ctx.insert(WorkoutEntry.cardio(activity: "篮球", durationMinutes: 60, intensity: .high, date: date))
        try ctx.save()

        WorkoutDayService.enforceSingleWorkout(kind: .cardio, on: date, in: ctx)
        try ctx.save()

        let remaining = try ctx.fetch(FetchDescriptor<WorkoutEntry>())
        #expect(remaining.count == 1)
    }
}
