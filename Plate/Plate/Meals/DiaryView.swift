import SwiftUI
import SwiftData

struct DiaryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MealEntry.date, order: .reverse) private var allMeals: [MealEntry]
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var pickerTarget: MealType?

    private var todaysMeals: [MealEntry] {
        let cal = Calendar.current
        return allMeals.filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private func mealEntry(for type: MealType) -> MealEntry? {
        todaysMeals.first(where: { $0.mealType == type })
    }

    private func yesterdaysMeal(for type: MealType) -> MealEntry? {
        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: selectedDate) else { return nil }
        return allMeals.first { cal.isDate($0.date, inSameDayAs: yesterday) && $0.mealType == type }
    }

    private func copyMeal(_ source: MealEntry, to type: MealType) {
        if let existing = mealEntry(for: type) {
            MealCopyService.copyItems(from: source, to: existing, in: context)
        } else {
            MealCopyService.copy(source, to: selectedDate, mealType: type, in: context)
        }
        try? context.save()
    }

    private var dailyTotals: (kcal: Double, p: Double, c: Double, f: Double) {
        todaysMeals.reduce((0, 0, 0, 0)) { acc, meal in
            (acc.0 + meal.totalCalories, acc.1 + meal.totalProtein, acc.2 + meal.totalCarbs, acc.3 + meal.totalFat)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section { dateHeader }
                    .listRowBackground(Color.clear)
                Section { totalsCard }
                    .listRowBackground(Color.clear)

                ForEach(MealType.allCases, id: \.self) { type in
                    mealSection(type: type)
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle("饮食")
            .sheet(item: $pickerTarget) { type in
                MealItemPickerView { source in
                    addItem(source, mealType: type)
                }
            }
        }
    }

    // MARK: - Subviews

    private var dateHeader: some View {
        HStack {
            Button { shiftDate(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            VStack(spacing: 2) {
                Text(selectedDate, format: .dateTime.year().month().day().weekday(.wide))
                    .font(.headline)
                if !Calendar.current.isDateInToday(selectedDate) {
                    Button("回到今天") {
                        selectedDate = Calendar.current.startOfDay(for: .now)
                    }
                    .font(.caption)
                }
            }
            Spacer()
            Button { shiftDate(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.vertical, 4)
    }

    private var totalsCard: some View {
        HStack(spacing: 0) {
            totalCell("热量", NutritionFormat.kcal(dailyTotals.kcal), "kcal")
            Divider()
            totalCell("蛋白", String(format: "%.0f", dailyTotals.p), "g")
            Divider()
            totalCell("碳水", String(format: "%.0f", dailyTotals.c), "g")
            Divider()
            totalCell("脂肪", String(format: "%.0f", dailyTotals.f), "g")
        }
        .frame(height: 56)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func totalCell(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.title3).fontWeight(.semibold)
                Text(unit).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func mealSection(type: MealType) -> some View {
        Section {
            if let meal = mealEntry(for: type) {
                ForEach(meal.items) { item in
                    MealItemRow(item: item)
                }
                .onDelete { offsets in
                    deleteItems(offsets, from: meal)
                }
            }
            Button {
                pickerTarget = type
            } label: {
                Label("加食物", systemImage: "plus.circle")
                    .font(.callout)
            }
            if mealEntry(for: type)?.items.isEmpty ?? true,
               let yesterday = yesterdaysMeal(for: type), !yesterday.items.isEmpty {
                Button {
                    copyMeal(yesterday, to: type)
                } label: {
                    Label("复制昨天（\(yesterday.items.count) 项）", systemImage: "doc.on.doc")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack {
                Text(type.displayName)
                Spacer()
                if let meal = mealEntry(for: type), !meal.items.isEmpty {
                    Text("\(NutritionFormat.kcal(meal.totalCalories)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func shiftDate(by days: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = Calendar.current.startOfDay(for: next)
    }

    private func addItem(_ source: MealItemSource, mealType: MealType) {
        let meal: MealEntry
        if let existing = mealEntry(for: mealType) {
            meal = existing
        } else {
            meal = MealEntry(date: selectedDate, mealType: mealType)
            context.insert(meal)
        }
        let item = source.makeMealItem()
        item.meal = meal
        meal.items.append(item)
        context.insert(item)
        try? context.save()
    }

    private func deleteItems(_ offsets: IndexSet, from meal: MealEntry) {
        for index in offsets {
            context.delete(meal.items[index])
        }
        // Clean up empty meals so headers stay tidy
        if meal.items.count == offsets.count {
            context.delete(meal)
        }
        try? context.save()
    }
}

private extension MealType {
    var displayName: String {
        switch self {
        case .breakfast: "早餐"
        case .lunch: "午餐"
        case .dinner: "晚餐"
        case .snack: "加餐"
        }
    }
}

extension MealType: Identifiable {
    public var id: String { rawValue }
}

private struct MealItemRow: View {
    let item: MealItem

    private var name: String {
        item.recipe?.name ?? item.ingredient?.name ?? item.estimatedName ?? "—"
    }

    private var quantityText: String {
        if let s = item.servings { return s == 1 ? "1 份" : String(format: "%.1f 份", s) }
        if let g = item.grams { return "\(Int(g.rounded())) g" }
        if let c = item.count { return "\(c) 个" }
        if item.estimatedName != nil { return item.estimatedDescription ?? "估算记录" }
        return ""
    }

    var body: some View {
        HStack {
            if let data = item.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body)
                Text(quantityText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(NutritionFormat.kcal(item.calories)) kcal")
                .font(.caption)
                .monospacedDigit()
        }
    }
}
