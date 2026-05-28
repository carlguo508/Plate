import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            RecipeListView()
                .tabItem { Label("菜谱", systemImage: "fork.knife") }
            DiaryView()
                .tabItem { Label("饮食", systemImage: "book.pages") }
            TrainingTabView()
                .tabItem { Label("训练", systemImage: "dumbbell") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Ingredient.self,
            Recipe.self, RecipeIngredient.self, RecipeNote.self,
            MealEntry.self, MealItem.self,
        ], inMemory: true)
}
