import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今天", systemImage: "calendar") }
            RecipeListView()
                .tabItem { Label("菜谱", systemImage: "fork.knife") }
            DiaryView()
                .tabItem { Label("饮食", systemImage: "book.pages") }
            TrainingTabView()
                .tabItem { Label("训练", systemImage: "dumbbell") }
            ReviewView()
                .tabItem { Label("回顾", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Ingredient.self,
            Recipe.self, RecipeIngredient.self, RecipeNote.self,
            MealEntry.self, MealItem.self,
            WorkoutEntry.self, ExerciseSet.self,
            WeeklyPlan.self, DayPlan.self,
        ], inMemory: true)
}
