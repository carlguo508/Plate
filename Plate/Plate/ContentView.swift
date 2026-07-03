import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    /// Views like TodayView capture "today" in their init-time query predicates. Bumping this
    /// key when the calendar day changes recreates them so they never show a stale day.
    @State private var dayKey = Calendar.current.startOfDay(for: .now)

    var body: some View {
        TabView {
            TodayView()
                .id(dayKey)
                .tabItem { Label("今天", systemImage: "calendar") }
            RecipeListView()
                .tabItem { Label("菜谱", systemImage: "fork.knife") }
            DiaryView()
                .id(dayKey)
                .tabItem { Label("饮食", systemImage: "book.pages") }
            TrainingTabView()
                .id(dayKey)
                .tabItem { Label("训练", systemImage: "dumbbell") }
            ReviewView()
                .tabItem { Label("回顾", systemImage: "chart.line.uptrend.xyaxis") }
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: .NSCalendarDayChanged)
                .receive(on: DispatchQueue.main)
        ) { _ in
            dayKey = Calendar.current.startOfDay(for: .now)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                dayKey = Calendar.current.startOfDay(for: .now)
            }
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
            BodyWeightEntry.self,
        ], inMemory: true)
}
