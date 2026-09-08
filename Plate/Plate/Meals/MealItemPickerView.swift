import SwiftUI
import SwiftData
import PhotosUI

enum MealItemSource {
    case manual(name: String, calories: Double, protein: Double)
    case recipe(Recipe, servings: Double)
    case recipeSnapshot(Recipe, servings: Double, source: MealItem)
    case ingredientGrams(Ingredient, grams: Double)
    case ingredientCount(Ingredient, count: Int)
    case estimated(
        name: String,
        description: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        confidence: String,
        advice: String,
        portionNotes: String,
        photoData: Data?
    )

    init?(reusing item: MealItem) {
        if let recipe = item.recipe, let servings = item.servings {
            self = .recipeSnapshot(recipe, servings: servings, source: item)
        } else if let ingredient = item.ingredient, let grams = item.grams {
            self = .ingredientGrams(ingredient, grams: grams)
        } else if let ingredient = item.ingredient, let count = item.count {
            self = .ingredientCount(ingredient, count: count)
        } else if let name = item.estimatedName, let calories = item.estimatedCalories {
            self = .estimated(
                name: name,
                description: item.estimatedDescription ?? "",
                calories: calories,
                protein: item.estimatedProtein ?? 0,
                carbs: item.estimatedCarbs ?? 0,
                fat: item.estimatedFat ?? 0,
                confidence: "沿用常用记录",
                advice: item.estimateAdvice ?? "",
                portionNotes: item.estimatePortionNotes ?? "",
                photoData: nil
            )
        } else {
            return nil
        }
    }

    func makeMealItem() -> MealItem {
        switch self {
        case .manual(let name, let calories, let protein):
            MealItem(
                estimatedName: name,
                description: "",
                calories: calories,
                protein: protein,
                carbs: 0,
                fat: 0,
                confidence: "手动记录",
                advice: "",
                portionNotes: ""
            )
        case .recipe(let recipe, let servings):
            MealItem(recipe: recipe, servings: servings)
        case .recipeSnapshot(let recipe, let servings, let source):
            MealItem(recipe: recipe, servings: servings, preservingNutritionFrom: source)
        case .ingredientGrams(let ingredient, let grams):
            MealItem(ingredient: ingredient, grams: grams)
        case .ingredientCount(let ingredient, let count):
            MealItem(ingredient: ingredient, count: count)
        case .estimated(
            let name,
            let description,
            let calories,
            let protein,
            let carbs,
            let fat,
            let confidence,
            let advice,
            let portionNotes,
            let photoData
        ):
            MealItem(
                estimatedName: name,
                description: description,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                confidence: confidence,
                advice: advice,
                portionNotes: portionNotes,
                photoData: photoData
            )
        }
    }
}

struct MealItemPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MealEntry.date, order: .reverse) private var mealHistory: [MealEntry]
    @State private var tab: Tab = .quick

    let bodyWeightKg: Double?
    let currentDailyCalories: Double
    let estimatedDailyBurn: Double
    let preferredMealType: MealType?
    let onPick: (MealItemSource) -> Void

    init(
        bodyWeightKg: Double? = nil,
        currentDailyCalories: Double = 0,
        estimatedDailyBurn: Double = Goals.baselineDailyBurn,
        preferredMealType: MealType? = nil,
        onPick: @escaping (MealItemSource) -> Void
    ) {
        self.bodyWeightKg = bodyWeightKg
        self.currentDailyCalories = currentDailyCalories
        self.estimatedDailyBurn = estimatedDailyBurn
        self.preferredMealType = preferredMealType
        self.onPick = onPick
    }

    enum Tab: String, CaseIterable, Identifiable {
        case quick = "快速"
        case recipes = "菜谱"
        case ingredients = "食材"
        case estimate = "AI 估算"
        var id: String { rawValue }
    }

    private var frequentOptions: [FrequentMealOption] {
        FrequentMealService.options(from: mealHistory, preferredMealType: preferredMealType)
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
                case .quick:
                    QuickMealForm(options: frequentOptions) { source in
                        onPick(source); dismiss()
                    }
                case .recipes:
                    RecipePickList(onPick: { source in
                        onPick(source); dismiss()
                    })
                case .ingredients:
                    IngredientPickList(onPick: { source in
                        onPick(source); dismiss()
                    })
                case .estimate:
                    EstimatedMealForm(
                        bodyWeightKg: bodyWeightKg,
                        currentDailyCalories: currentDailyCalories,
                        estimatedDailyBurn: estimatedDailyBurn,
                        onPick: { source in
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

private struct QuickMealForm: View {
    let options: [FrequentMealOption]
    let onPick: (MealItemSource) -> Void

    @State private var name = ""
    @State private var caloriesText = ""
    @State private var proteinText = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && (Double(caloriesText) ?? -1) >= 0
    }

    var body: some View {
        Form {
            if !options.isEmpty {
                Section("常用") {
                    ForEach(options) { option in
                        Button {
                            guard let source = MealItemSource(reusing: option.item) else { return }
                            onPick(source)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(option.name)
                                        .foregroundStyle(.primary)
                                    Text("\(NutritionFormat.kcal(option.item.calories)) kcal · 蛋白 \(NutritionFormat.grams(option.item.protein))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                            }
                        }
                    }
                }
            }

            Section {
                TextField("名称，如 Chipotle 鸡肉碗", text: $name)
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("quick-meal-name")
                nutritionField(
                    "热量",
                    text: $caloriesText,
                    unit: "kcal",
                    identifier: "quick-meal-calories"
                )
                nutritionField(
                    "蛋白质（可选）",
                    text: $proteinText,
                    unit: "g",
                    identifier: "quick-meal-protein"
                )
            } header: {
                Text("直接记录")
            } footer: {
                Text("不用拆分食材。记录后，这项会自动出现在“常用”里供下次一键加入。")
            }

            Section {
                Button("加入这餐") {
                    onPick(.manual(
                        name: trimmedName,
                        calories: Double(caloriesText) ?? 0,
                        protein: Double(proteinText) ?? 0
                    ))
                }
                .frame(maxWidth: .infinity)
                .disabled(!canSave)
                .accessibilityIdentifier("save-quick-meal")
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
}

struct FrequentMealOption: Identifiable {
    let id: String
    let item: MealItem
    let usageCount: Int
    let isPreferredMealType: Bool

    var name: String {
        item.historicalName ?? "未命名"
    }
}

enum FrequentMealService {
    static func options(
        from meals: [MealEntry],
        preferredMealType: MealType?,
        limit: Int = 8
    ) -> [FrequentMealOption] {
        struct Accumulator {
            var latestItem: MealItem
            var usageCount: Int
            var preferredCount: Int
            var latestDate: Date
        }

        var grouped: [String: Accumulator] = [:]
        for meal in meals {
            for item in meal.items {
                let name = item.historicalName ?? ""
                let key = normalizedName(name)
                guard !key.isEmpty, MealItemSource(reusing: item) != nil else { continue }

                if var existing = grouped[key] {
                    existing.usageCount += 1
                    if meal.mealType == preferredMealType {
                        existing.preferredCount += 1
                    }
                    if meal.date > existing.latestDate {
                        existing.latestItem = item
                        existing.latestDate = meal.date
                    }
                    grouped[key] = existing
                } else {
                    grouped[key] = Accumulator(
                        latestItem: item,
                        usageCount: 1,
                        preferredCount: meal.mealType == preferredMealType ? 1 : 0,
                        latestDate: meal.date
                    )
                }
            }
        }

        return grouped.map { key, value in
            FrequentMealOption(
                id: key,
                item: value.latestItem,
                usageCount: value.usageCount,
                isPreferredMealType: value.preferredCount > 0
            )
        }
        .sorted {
            if $0.isPreferredMealType != $1.isPreferredMealType {
                return $0.isPreferredMealType
            }
            if $0.usageCount != $1.usageCount {
                return $0.usageCount > $1.usageCount
            }
            return ($0.item.meal?.date ?? .distantPast) > ($1.item.meal?.date ?? .distantPast)
        }
        .prefix(limit)
        .map { $0 }
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }
}

private struct EstimatedMealForm: View {
    let bodyWeightKg: Double?
    let currentDailyCalories: Double
    let estimatedDailyBurn: Double
    let onPick: (MealItemSource) -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var isLoadingPhoto = false
    @State private var photoError: String?
    @State private var name = ""
    @State private var description = ""
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var confidence = "手动估算"
    @State private var portionNotes = ""
    @State private var advice = ""
    @State private var isEstimating = false
    @State private var aiError: String?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Double(caloriesText) ?? -1) >= 0
    }

    var body: some View {
        Form {
            Section {
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                HStack {
                    Button {
                        photoError = nil
                        showingPhotoLibrary = false
                        showingCamera = true
                    } label: {
                        Label("拍照", systemImage: "camera")
                    }
                    Spacer()
                    Button {
                        photoError = nil
                        showingCamera = false
                        showingPhotoLibrary = true
                    } label: {
                        Label("选择照片", systemImage: "photo")
                    }
                }
                if isLoadingPhoto {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("正在读取照片…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let photoError {
                    Text(photoError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("拍照或选图完成后会自动估算并预填；保存前仍可手动修改。")
            }

            Section("吃了什么") {
                TextField("名称，如 牛肉盖饭", text: $name)
                TextField("补充份量、酱汁、用油等", text: $description, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("大致营养") {
                nutritionField("热量", text: $caloriesText, unit: "kcal")
                nutritionField("蛋白质", text: $proteinText, unit: "g")
                if !confidence.isEmpty {
                    Label(confidence, systemImage: "wand.and.stars")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if !portionNotes.isEmpty {
                    Text(portionNotes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    Task { await estimateWithAI() }
                } label: {
                    HStack {
                        Label("AI 估算这餐", systemImage: "sparkles")
                        Spacer()
                        if isEstimating {
                            ProgressView()
                        }
                    }
                }
                .disabled(isEstimating || (
                    photoData == nil
                        && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ))
                if let aiError {
                    Text(aiError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("需要先在「今天」右上角目标设置里填写服务端地址。AI 结果只是粗估，用来降低记录成本。")
            }

            Section {
                Button("加入这餐") {
                    onPick(.estimated(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                        calories: Double(caloriesText) ?? 0,
                        protein: Double(proteinText) ?? 0,
                        carbs: Double(carbsText) ?? 0,
                        fat: Double(fatText) ?? 0,
                        confidence: confidence,
                        advice: advice,
                        portionNotes: portionNotes,
                        photoData: photoData
                    ))
                }
                .frame(maxWidth: .infinity)
                .disabled(!canSave)
            }
        }
        .photosPicker(
            isPresented: $showingPhotoLibrary,
            selection: $selectedPhoto,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            showingPhotoLibrary = false
            showingCamera = false
            Task { await loadPhoto(item) }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { data in
                showingCamera = false
                photoData = compressedImageData(data)
                if photoData == nil {
                    photoError = "无法读取这张照片，请重新拍摄。"
                } else {
                    Task { await estimateWithAI() }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func nutritionField(_ label: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }

    @MainActor
    private func estimateWithAI() async {
        isEstimating = true
        aiError = nil
        defer { isEstimating = false }

        do {
            let estimate = try await NutritionAIService().estimateMeal(
                photoData: photoData,
                description: [name, description]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n"),
                bodyWeightKg: bodyWeightKg,
                currentDailyCalories: currentDailyCalories,
                estimatedDailyBurn: estimatedDailyBurn
            )
            name = estimate.name
            description = estimate.description
            caloriesText = numberText(estimate.calories)
            proteinText = numberText(estimate.protein)
            carbsText = numberText(estimate.carbs)
            fatText = numberText(estimate.fat)
            confidence = estimate.confidence
            portionNotes = estimate.portionNotes
            advice = estimate.advice
        } catch {
            aiError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func numberText(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", value)
    }

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem) async {
        isLoadingPhoto = true
        photoError = nil
        defer {
            isLoadingPhoto = false
            selectedPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let compressed = compressedImageData(data) else {
                photoError = "无法读取这张照片，请尝试选择另一张或重新拍摄。"
                return
            }
            photoData = compressed
            await estimateWithAI()
        } catch {
            photoError = "照片读取失败。若照片在 iCloud 中，请等待下载完成后重试。"
        }
    }

    private func compressedImageData(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 1600
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.72)
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (Data) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (Data) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.85) {
                onCapture(data)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
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
