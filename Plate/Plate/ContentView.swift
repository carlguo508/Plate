import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(filter: #Predicate<Ingredient> { $0.isBuiltIn == true })
    private var builtInIngredients: [Ingredient]

    var body: some View {
        VStack(spacing: 16) {
            Text("Plate")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("\(builtInIngredients.count) built-in ingredients seeded")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Ingredient.self, inMemory: true)
}
