import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]

    @State private var searchText: String = ""
    @State private var selectedTag: String?
    @State private var showingNewRecipe = false

    private var allTags: [String] {
        Array(Set(recipes.flatMap { $0.tags })).sorted()
    }

    private var filteredRecipes: [Recipe] {
        recipes.filter { recipe in
            let matchesSearch = searchText.isEmpty
                || recipe.name.localizedCaseInsensitiveContains(searchText)
            let matchesTag = selectedTag.map { recipe.tags.contains($0) } ?? true
            return matchesSearch && matchesTag
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("菜谱")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewRecipe = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewRecipe) {
                RecipeEditView()
            }
        }
    }

    private var list: some View {
        List {
            if !allTags.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            tagChip(label: "全部", isSelected: selectedTag == nil) {
                                selectedTag = nil
                            }
                            ForEach(allTags, id: \.self) { tag in
                                tagChip(label: tag, isSelected: selectedTag == tag) {
                                    selectedTag = selectedTag == tag ? nil : tag
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
            }

            Section {
                ForEach(filteredRecipes) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe)
                    } label: {
                        RecipeRow(recipe: recipe)
                    }
                }
                .onDelete(perform: deleteRecipes)
            }
        }
        .searchable(text: $searchText, prompt: "搜索菜谱")
    }

    private func tagChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有菜谱", systemImage: "fork.knife")
        } description: {
            Text("点右上角 + 添加你的第一道菜")
        } actions: {
            Button("新建菜谱") { showingNewRecipe = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func deleteRecipes(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredRecipes[index])
        }
        try? context.save()
    }
}

private struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recipe.name)
                .font(.headline)
            HStack(spacing: 12) {
                Label(NutritionFormat.kcal(recipe.perServingCalories) + " kcal", systemImage: "flame")
                Label(NutritionFormat.grams(recipe.perServingProtein) + " 蛋白", systemImage: "bolt")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if !recipe.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(recipe.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    RecipeListView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
