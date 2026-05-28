import SwiftUI
import SwiftData

struct RecipeEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// If non-nil, we're editing in place; otherwise creating a new recipe.
    var existing: Recipe?

    @State private var name: String = ""
    @State private var servings: Int = 1
    @State private var steps: String = ""
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var draftIngredients: [DraftIngredient] = []
    @State private var showingPicker = false

    /// In-memory edit buffer. We commit to SwiftData only on save.
    struct DraftIngredient: Identifiable {
        let id = UUID()
        let ingredient: Ingredient
        var grams: Double?
        var count: Int?
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("菜名", text: $name)
                    Stepper("一锅 \(servings) 份", value: $servings, in: 1...20)
                }

                Section {
                    ForEach($draftIngredients) { $item in
                        ingredientRow(item: item)
                    }
                    .onDelete { offsets in
                        draftIngredients.remove(atOffsets: offsets)
                    }
                    Button {
                        showingPicker = true
                    } label: {
                        Label("添加食材", systemImage: "plus.circle")
                    }
                } header: {
                    Text("食材")
                }

                Section("做法") {
                    TextField("步骤说明…", text: $steps, axis: .vertical)
                        .lineLimit(4...20)
                }

                Section {
                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag).font(.caption)
                                        Button {
                                            tags.removeAll { $0 == tag }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    HStack {
                        TextField("新增标签（如 减脂、家常）", text: $newTag)
                            .onSubmit(addTag)
                        Button("添加", action: addTag)
                            .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("标签")
                }
            }
            .navigationTitle(existing == nil ? "新菜谱" : "编辑菜谱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingPicker) {
                IngredientPickerView { ingredient, grams, count in
                    draftIngredients.append(
                        DraftIngredient(ingredient: ingredient, grams: grams, count: count)
                    )
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    @ViewBuilder
    private func ingredientRow(item: DraftIngredient) -> some View {
        HStack {
            Text(item.ingredient.name)
            Spacer()
            if let g = item.grams {
                Text("\(Int(g.rounded())) g").foregroundStyle(.secondary)
            } else if let c = item.count {
                Text("\(c) 个").foregroundStyle(.secondary)
            }
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTag = ""
    }

    private func loadExisting() {
        guard let existing, draftIngredients.isEmpty, name.isEmpty else { return }
        name = existing.name
        servings = existing.servings
        steps = existing.steps
        tags = existing.tags
        draftIngredients = existing.ingredients.compactMap { item in
            guard let ing = item.ingredient else { return nil }
            return DraftIngredient(ingredient: ing, grams: item.grams, count: item.count)
        }
    }

    private func save() {
        let recipe: Recipe
        if let existing {
            recipe = existing
            recipe.name = name
            recipe.servings = servings
            recipe.steps = steps
            recipe.tags = tags
            recipe.updatedAt = .now
            // Replace ingredients
            for item in recipe.ingredients {
                context.delete(item)
            }
            recipe.ingredients = []
        } else {
            recipe = Recipe(name: name, steps: steps, servings: servings, tags: tags)
            context.insert(recipe)
        }

        for draft in draftIngredients {
            let item: RecipeIngredient
            if let g = draft.grams {
                item = RecipeIngredient(ingredient: draft.ingredient, grams: g)
            } else if let c = draft.count {
                item = RecipeIngredient(ingredient: draft.ingredient, count: c)
            } else {
                continue
            }
            item.recipe = recipe
            recipe.ingredients.append(item)
            context.insert(item)
        }

        try? context.save()
        dismiss()
    }
}
