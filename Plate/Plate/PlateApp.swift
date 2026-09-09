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
            if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset") {
                Self.resetUITestData(in: container.mainContext)
            }
            MealNutritionSnapshotService.backfillMissingRecipeSnapshots(in: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private static func resetUITestData(in context: ModelContext) {
        for entry in (try? context.fetch(FetchDescriptor<MealEntry>())) ?? [] {
            context.delete(entry)
        }
        for entry in (try? context.fetch(FetchDescriptor<WorkoutEntry>())) ?? [] {
            context.delete(entry)
        }
        for entry in (try? context.fetch(FetchDescriptor<BodyWeightEntry>())) ?? [] {
            context.delete(entry)
        }
        UserDefaults.standard.removeObject(forKey: WorkoutTemplateStore.key)
        try? context.save()
    }

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
