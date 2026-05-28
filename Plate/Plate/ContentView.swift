import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        RecipeListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Ingredient.self,
            Recipe.self, RecipeIngredient.self, RecipeNote.self,
        ], inMemory: true)
}
