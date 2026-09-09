import SwiftUI
import SwiftData

enum IngredientLibraryService {
    @discardableResult
    static func add(
        name: String,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        defaultUnitGrams: Double?,
        in context: ModelContext
    ) -> Ingredient? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, caloriesPer100g >= 0 else { return nil }

        let ingredient = Ingredient(
            name: trimmed,
            category: .other,
            caloriesPer100g: caloriesPer100g,
            proteinPer100g: max(0, proteinPer100g),
            carbsPer100g: max(0, carbsPer100g),
            fatPer100g: max(0, fatPer100g),
            defaultUnitGrams: defaultUnitGrams.flatMap { $0 > 0 ? $0 : nil }
        )
        context.insert(ingredient)
        try? context.save()
        return ingredient
    }

    static func hide(_ ingredient: Ingredient, in context: ModelContext) {
        ingredient.hiddenAt = .now
        try? context.save()
    }
}

struct AddIngredientSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var unitGrams = ""

    var onSave: ((Ingredient) -> Void)?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Double(calories) ?? -1) >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("食材") {
                    TextField("名称", text: $name)
                        .accessibilityIdentifier("ingredient-name")
                    nutritionField("热量", text: $calories, unit: "kcal", identifier: "ingredient-calories")
                    nutritionField("蛋白质", text: $protein, unit: "g", identifier: "ingredient-protein")
                    nutritionField("碳水", text: $carbs, unit: "g", identifier: "ingredient-carbs")
                    nutritionField("脂肪", text: $fat, unit: "g", identifier: "ingredient-fat")
                }
                Section {
                    nutritionField("每个约重（可选）", text: $unitGrams, unit: "g", identifier: "ingredient-unit-grams")
                } footer: {
                    Text("营养数据按每 100 g 填写。填了单个重量后，记录时也可以按个数加入。")
                }
            }
            .navigationTitle("新增食材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("save-ingredient")
                }
            }
        }
    }

    private func nutritionField(
        _ label: String,
        text: Binding<String>,
        unit: String,
        identifier: String
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .accessibilityIdentifier(identifier)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }

    private func save() {
        guard let ingredient = IngredientLibraryService.add(
            name: name,
            caloriesPer100g: Double(calories) ?? 0,
            proteinPer100g: Double(protein) ?? 0,
            carbsPer100g: Double(carbs) ?? 0,
            fatPer100g: Double(fat) ?? 0,
            defaultUnitGrams: Double(unitGrams),
            in: context
        ) else { return }
        onSave?(ingredient)
        dismiss()
    }
}
