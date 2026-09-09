import SwiftUI
import SwiftData

/// Two-step modal: pick an ingredient, then enter quantity. Calls `onPick` with the result.
struct IngredientPickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @State private var searchText = ""
    @State private var selected: Ingredient?
    @State private var showingAddIngredient = false
    @State private var pendingAddedIngredient: Ingredient?

    let onPick: (Ingredient, _ grams: Double?, _ count: Int?) -> Void

    private var filtered: [Ingredient] {
        let visible = ingredients.filter { $0.hiddenAt == nil }
        guard !searchText.isEmpty else { return visible }
        return visible.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { ing in
                    Button {
                        selected = ing
                    } label: {
                        HStack {
                            Text(ing.name)
                            Spacer()
                            Text("\(NutritionFormat.kcal(ing.caloriesPer100g)) kcal/100g")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: hideIngredients)
            }
            .searchable(text: $searchText, prompt: "搜索食材")
            .navigationTitle("选择食材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddIngredient = true
                    } label: {
                        Label("新增食材", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $selected) { ing in
                QuantitySheet(ingredient: ing) { grams, count in
                    onPick(ing, grams, count)
                    dismiss()
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingAddIngredient, onDismiss: {
                selected = pendingAddedIngredient
                pendingAddedIngredient = nil
            }) {
                AddIngredientSheet { ingredient in
                    pendingAddedIngredient = ingredient
                }
            }
        }
    }

    private func hideIngredients(at offsets: IndexSet) {
        for index in offsets {
            IngredientLibraryService.hide(filtered[index], in: context)
        }
    }
}

private struct QuantitySheet: View {
    let ingredient: Ingredient
    let onConfirm: (_ grams: Double?, _ count: Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var byCount: Bool
    @State private var gramsText: String = "100"
    @State private var countText: String = "1"

    init(ingredient: Ingredient, onConfirm: @escaping (Double?, Int?) -> Void) {
        self.ingredient = ingredient
        self.onConfirm = onConfirm
        _byCount = State(initialValue: ingredient.defaultUnitGrams != nil)
    }

    private var canSwitchToCount: Bool {
        ingredient.defaultUnitGrams != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("\(ingredient.name) — 多少？") {
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
                            Text("个 (≈\(Int(unit)) g/个)")
                                .foregroundStyle(.secondary)
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
                    Button("确定") {
                        if byCount {
                            onConfirm(nil, Int(countText) ?? 1)
                        } else {
                            onConfirm(Double(gramsText) ?? 100, nil)
                        }
                    }
                }
            }
        }
    }
}
