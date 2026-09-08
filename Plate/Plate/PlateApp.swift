import SwiftUI
import SwiftData

@main
struct PlateApp: App {
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Ingredient.self,
            Recipe.self,
            RecipeIngredient.self,
            RecipeNote.self,
            MealEntry.self,
            MealItem.self,
            WorkoutEntry.self,
            ExerciseSet.self,
            WeeklyPlan.self,
            DayPlan.self,
            BodyWeightEntry.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            MealNutritionSnapshotService.backfillMissingRecipeSnapshots(in: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    SeedData.seedIfNeeded(context: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
