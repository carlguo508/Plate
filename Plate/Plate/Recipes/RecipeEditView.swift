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
    @State private var mode: Mode = .quick
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""

    private enum Mode: String, CaseIterable, Identifiable {
        case quick = "快捷"
        case detailed = "按食材"
        var id: String { rawValue }
    }

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
                Section {
                    Picker("记录方式", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(mode == .quick ? "直接保存每份热量和蛋白质，适合常吃的餐。" : "按食材计算营养，适合需要保留做法的菜谱。")
                }

                Section("基本信息") {
                    TextField("菜名", text: $name)
                    if mode == .quick {
                        HStack {
                            TextField("每份热量", text: $caloriesText)
                                .keyboardType(.decimalPad)
                            Text("kcal").foregroundStyle(.secondary)
                        }
                        HStack {
                            TextField("每份蛋白质", text: $proteinText)
                                .keyboardType(.decimalPad)
                            Text("g").foregroundStyle(.secondary)
                        }
                    } else {
                        Stepper("一锅 \(servings) 份", value: $servings, in: 1...20)
                    }
                }

                if mode == .detailed {
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
            }
            .navigationTitle(existing == nil ? "新菜谱" : "编辑菜谱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(!canSave)
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

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if mode == .quick {
            return (Double(caloriesText) ?? -1) >= 0 && (Double(proteinText) ?? -1) >= 0
        }
        return !draftIngredients.isEmpty
    }

    private func loadExisting() {
        guard let existing, draftIngredients.isEmpty, name.isEmpty else { return }
        name = existing.name
        servings = existing.servings
        steps = existing.steps
        tags = existing.tags
        if let calories = existing.manualCaloriesPerServing,
           let protein = existing.manualProteinPerServing {
            mode = .quick
            caloriesText = NutritionFormat.editableNumber(calories)
            proteinText = NutritionFormat.editableNumber(protein)
        } else {
            mode = .detailed
        }
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
            recipe.updatedAt = .now
            if mode == .quick {
                recipe.manualCaloriesPerServing = Double(caloriesText) ?? 0
                recipe.manualProteinPerServing = Double(proteinText) ?? 0
            } else {
                recipe.manualCaloriesPerServing = nil
                recipe.manualProteinPerServing = nil
                recipe.servings = servings
                recipe.steps = steps
                recipe.tags = tags
                for item in recipe.ingredients {
                    context.delete(item)
                }
                recipe.ingredients = []
            }
        } else {
            recipe = Recipe(
                name: name,
                steps: mode == .detailed ? steps : "",
                servings: mode == .detailed ? servings : 1,
                tags: mode == .detailed ? tags : [],
                manualCaloriesPerServing: mode == .quick ? Double(caloriesText) : nil,
                manualProteinPerServing: mode == .quick ? Double(proteinText) : nil
            )
            context.insert(recipe)
        }

        for draft in mode == .detailed ? draftIngredients : [] {
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
