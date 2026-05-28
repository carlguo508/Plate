import SwiftUI
import SwiftData

enum MealItemSource {
    case recipe(Recipe, servings: Double)
    case ingredientGrams(Ingredient, grams: Double)
    case ingredientCount(Ingredient, count: Int)
}

struct MealItemPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .recipes

    let onPick: (MealItemSource) -> Void

    enum Tab: String, CaseIterable, Identifiable {
        case recipes = "菜谱"
        case ingredients = "食材"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                switch tab {
                case .recipes:
                    RecipePickList(onPick: { source in
                        onPick(source); dismiss()
                    })
                case .ingredients:
                    IngredientPickList(onPick: { source in
                        onPick(source); dismiss()
                    })
                }
            }
            .navigationTitle("加食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

private struct RecipePickList: View {
    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]
    @State private var search = ""
    @State private var selected: Recipe?

    let onPick: (MealItemSource) -> Void

    private var filtered: [Recipe] {
        guard !search.isEmpty else { return recipes }
        return recipes.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        Group {
            if recipes.isEmpty {
                ContentUnavailableView("还没有菜谱", systemImage: "fork.knife",
                    description: Text("去「菜谱」tab 添加一些"))
            } else {
                List(filtered) { recipe in
                    Button { selected = recipe } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(recipe.name)
                                Text("\(NutritionFormat.kcal(recipe.perServingCalories)) kcal / 份")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .searchable(text: $search)
            }
        }
        .sheet(item: $selected) { recipe in
            ServingsSheet(recipe: recipe) { servings in
                onPick(.recipe(recipe, servings: servings))
            }
            .presentationDetents([.medium])
        }
    }
}

private struct ServingsSheet: View {
    let recipe: Recipe
    let onConfirm: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var servings: Double = 1

    private let options: [Double] = [0.5, 1.0, 1.5, 2.0]

    var body: some View {
        NavigationStack {
            Form {
                Section("\(recipe.name) — 几份？") {
                    HStack {
                        ForEach(options, id: \.self) { opt in
                            Button {
                                servings = opt
                            } label: {
                                Text(opt == 1 ? "1" : String(format: "%.1f", opt))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(servings == opt ? Color.accentColor : Color(.tertiarySystemBackground))
                                    .foregroundStyle(servings == opt ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    HStack {
                        Text("自定义")
                        Spacer()
                        Stepper(value: $servings, in: 0.1...10, step: 0.1) {
                            Text(String(format: "%.1f 份", servings))
                                .monospacedDigit()
                        }
                    }
                }
                Section {
                    HStack {
                        Text("摄入热量")
                        Spacer()
                        Text("\(NutritionFormat.kcal(recipe.perServingCalories * servings)) kcal")
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle("份数")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入") {
                        onConfirm(servings)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct IngredientPickList: View {
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @State private var search = ""
    @State private var selected: Ingredient?

    let onPick: (MealItemSource) -> Void

    private var filtered: [Ingredient] {
        guard !search.isEmpty else { return ingredients }
        return ingredients.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List(filtered) { ing in
            Button { selected = ing } label: {
                HStack {
                    Text(ing.name)
                    Spacer()
                    Text("\(NutritionFormat.kcal(ing.caloriesPer100g)) kcal/100g")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .searchable(text: $search)
        .sheet(item: $selected) { ing in
            IngredientQuantitySheet(ingredient: ing) { source in
                onPick(source)
            }
            .presentationDetents([.medium])
        }
    }
}

private struct IngredientQuantitySheet: View {
    let ingredient: Ingredient
    let onConfirm: (MealItemSource) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var byCount: Bool
    @State private var gramsText = "100"
    @State private var countText = "1"

    init(ingredient: Ingredient, onConfirm: @escaping (MealItemSource) -> Void) {
        self.ingredient = ingredient
        self.onConfirm = onConfirm
        _byCount = State(initialValue: ingredient.defaultUnitGrams != nil)
    }

    private var canSwitchToCount: Bool { ingredient.defaultUnitGrams != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("\(ingredient.name)") {
                    if canSwitchToCount {
                        Picker("单位", selection: $byCount) {
                            Text("按个数").tag(true)
                            Text("按克数").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                    if byCount, let unit = ingredient.defaultUnitGrams {
                        HStack {
                            TextField("个数", text: $countText)
                                .keyboardType(.numberPad)
                            Text("个 (≈\(Int(unit)) g/个)").foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            TextField("克数", text: $gramsText)
                                .keyboardType(.decimalPad)
                            Text("g").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("数量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入") {
                        if byCount {
                            onConfirm(.ingredientCount(ingredient, count: Int(countText) ?? 1))
                        } else {
                            onConfirm(.ingredientGrams(ingredient, grams: Double(gramsText) ?? 100))
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
