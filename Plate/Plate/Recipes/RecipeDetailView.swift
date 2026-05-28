import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var context

    @State private var showingEdit = false
    @State private var showingAddNote = false
    @State private var perServing = true

    var body: some View {
        List {
            Section {
                nutritionCard
            }

            Section("食材") {
                ForEach(recipe.ingredients) { item in
                    IngredientRow(item: item, recipeTotalCalories: recipe.totalCalories)
                }
            }

            if !recipe.steps.isEmpty {
                Section("做法") {
                    Text(recipe.steps)
                        .font(.body)
                        .padding(.vertical, 4)
                }
            }

            Section {
                ForEach(recipe.notes.sorted(by: { $0.createdAt > $1.createdAt })) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.createdAt, format: .dateTime.year().month().day())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(note.body)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { offsets in
                    let sorted = recipe.notes.sorted(by: { $0.createdAt > $1.createdAt })
                    for index in offsets {
                        context.delete(sorted[index])
                    }
                    try? context.save()
                }
            } header: {
                HStack {
                    Text("笔记")
                    Spacer()
                    Button {
                        showingAddNote = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("编辑") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            RecipeEditView(existing: recipe)
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteSheet(recipe: recipe)
        }
    }

    private var nutritionCard: some View {
        VStack(spacing: 12) {
            Picker("", selection: $perServing) {
                Text("每份").tag(true)
                Text("总计").tag(false)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 0) {
                nutrientCell(
                    "热量",
                    NutritionFormat.kcal(perServing ? recipe.perServingCalories : recipe.totalCalories),
                    "kcal"
                )
                Divider()
                nutrientCell(
                    "蛋白",
                    String(format: "%.1f", perServing ? recipe.perServingProtein : recipe.totalProtein),
                    "g"
                )
                Divider()
                nutrientCell(
                    "碳水",
                    String(format: "%.1f", perServing ? recipe.perServingCarbs : recipe.totalCarbs),
                    "g"
                )
                Divider()
                nutrientCell(
                    "脂肪",
                    String(format: "%.1f", perServing ? recipe.perServingFat : recipe.totalFat),
                    "g"
                )
            }
            .frame(height: 56)

            Text("一份 = 1 / \(recipe.servings) 锅")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func nutrientCell(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.title3).fontWeight(.semibold)
                Text(unit).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct IngredientRow: View {
    let item: RecipeIngredient
    let recipeTotalCalories: Double

    private var grams: Double {
        if let g = item.grams { return g }
        if let c = item.count, let unit = item.ingredient?.defaultUnitGrams { return Double(c) * unit }
        return 0
    }

    private var calories: Double {
        guard let ing = item.ingredient else { return 0 }
        return grams / 100 * ing.caloriesPer100g
    }

    private var quantityText: String {
        if let g = item.grams { return "\(Int(g.rounded())) g" }
        if let c = item.count { return "\(c) 个" }
        return ""
    }

    private var percentText: String {
        guard recipeTotalCalories > 0 else { return "" }
        return "\(Int((calories / recipeTotalCalories * 100).rounded()))%"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.ingredient?.name ?? "—")
                    .font(.body)
                Text(quantityText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(NutritionFormat.kcal(calories) + " kcal")
                    .font(.caption)
                    .monospacedDigit()
                if !percentText.isEmpty {
                    Text(percentText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct AddNoteSheet: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("笔记内容") {
                    TextField("这次做的怎么样？哪里要改进？", text: $noteText, axis: .vertical)
                        .lineLimit(4...12)
                }
            }
            .navigationTitle("新笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let note = RecipeNote(body: noteText)
                        note.recipe = recipe
                        context.insert(note)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
