import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var todaysMeals: [MealEntry]
    @Query private var todaysWorkouts: [WorkoutEntry]
    @Query private var todaysWeights: [BodyWeightEntry]
    @Query private var yesterdaysMeals: [MealEntry]
    @State private var showingGoals = false
    @State private var showingWeight = false
    @State private var showingMealPicker = false
    @State private var showingMealTypeChoice = false
    @State private var pendingMealType: MealType = .lunch
    @State private var goalsTick = 0  // forces re-render after goals update
    @State private var latestPriorWeight: BodyWeightEntry?

    init() {
        let dayStart = Calendar.current.startOfDay(for: .now)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? .now
        let yesterdayStart = Calendar.current.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart
        _todaysMeals = Query(filter: #Predicate<MealEntry> {
            $0.date >= dayStart && $0.date < dayEnd
        })
        _todaysWorkouts = Query(filter: #Predicate<WorkoutEntry> {
            $0.date >= dayStart && $0.date < dayEnd
        })
        _todaysWeights = Query(filter: #Predicate<BodyWeightEntry> {
            $0.date >= dayStart && $0.date < dayEnd
        })
        _yesterdaysMeals = Query(filter: #Predicate<MealEntry> {
            $0.date >= yesterdayStart && $0.date < dayStart
        })
    }

    private var todaysWeight: BodyWeightEntry? { todaysWeights.first }

    private var totalKcal: Double { todaysMeals.reduce(0) { $0 + $1.totalCalories } }
    private var totalProtein: Double { todaysMeals.reduce(0) { $0 + $1.totalProtein } }
    private var currentWeightKg: Double? { todaysWeight?.weightKg ?? latestPriorWeight?.weightKg }
    private var energyBalance: DailyEnergyBalance {
        EnergyBalanceService.calculate(
            meals: todaysMeals,
            workouts: todaysWorkouts,
            bodyWeightKg: currentWeightKg
        )
    }

    private var copyableYesterdayMeals: [MealEntry] {
        let recordedTypes = Set(todaysMeals.map(\.mealType))
        return yesterdaysMeals.filter {
            !recordedTypes.contains($0.mealType) && !$0.items.isEmpty
        }
    }

    private var todaysDayPlan: DayPlan? {
        let plan = WeekPlanService.planForWeek(of: .now, in: context)
        let weekday = Calendar.current.component(.weekday, from: .now)
        // Calendar weekday: 1=Sun, 2=Mon, ... 7=Sat → app dayIndex: 0=Mon..6=Sun
        let dayIndex = (weekday + 5) % 7
        return plan.days.first { $0.dayIndex == dayIndex }
    }

    var body: some View {
        NavigationStack {
            List {
                Section { dateHeader }
                    .listRowBackground(Color.clear)

                Section("体重") { weightCard }
                Section("今日训练") { trainingCard }
                Section("今日热量") { energyBalanceCard }
                Section("今日饮食") {
                    nutritionCard
                    Button {
                        showingMealTypeChoice = true
                    } label: {
                        Label("加食物", systemImage: "plus.circle")
                            .font(.callout)
                    }
                    if !copyableYesterdayMeals.isEmpty {
                        Button {
                            copyYesterdayMeals()
                        } label: {
                            Label(
                                "复制昨天未记录的餐（\(copyableYesterdayMeals.count) 餐）",
                                systemImage: "doc.on.doc"
                            )
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                if !todaysMeals.isEmpty {
                    Section("今天吃的") { mealList }
                }
            }
            .navigationTitle("今天")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingGoals = true } label: {
                        Image(systemName: "target")
                    }
                }
            }
            .sheet(isPresented: $showingGoals, onDismiss: { goalsTick += 1 }) {
                GoalsSheet()
            }
            .sheet(isPresented: $showingWeight, onDismiss: { goalsTick += 1 }) {
                WeightLogSheet(existing: todaysWeight, suggested: latestPriorWeight)
            }
            .confirmationDialog("记到哪一餐？", isPresented: $showingMealTypeChoice, titleVisibility: .visible) {
                ForEach(MealType.allCases, id: \.self) { type in
                    Button(mealLabel(type)) {
                        pendingMealType = type
                        showingMealPicker = true
                    }
                }
            }
            .sheet(isPresented: $showingMealPicker) {
                MealItemPickerView(
                    bodyWeightKg: currentWeightKg,
                    currentDailyCalories: totalKcal,
                    estimatedDailyBurn: energyBalance.totalBurnCalories,
                    preferredMealType: pendingMealType
                ) { source in
                    addItem(source, mealType: pendingMealType)
                }
            }
            .task {
                loadLatestPriorWeight()
            }
        }
        .id(goalsTick)
    }

    private func addItem(_ source: MealItemSource, mealType: MealType) {
        let dayStart = Calendar.current.startOfDay(for: .now)
        let meal: MealEntry
        if let existing = todaysMeals.first(where: { $0.mealType == mealType }) {
            meal = existing
        } else {
            meal = MealEntry(date: dayStart, mealType: mealType)
            context.insert(meal)
        }
        let item = source.makeMealItem()
        item.meal = meal
        meal.items.append(item)
        context.insert(item)
        try? context.save()
    }

    private func copyYesterdayMeals() {
        let today = Calendar.current.startOfDay(for: .now)
        for sourceMeal in copyableYesterdayMeals {
            MealCopyService.copy(sourceMeal, to: today, in: context)
        }
        try? context.save()
    }

    @ViewBuilder
    private var weightCard: some View {
        HStack {
            Button {
                showingWeight = true
            } label: {
                if let w = todaysWeight {
                    HStack(spacing: 8) {
                        Text("\(WeightConvert.formatted(w.weightKg, in: WeightPreference.current)) \(WeightPreference.current.label)")
                            .font(.title3).fontWeight(.semibold)
                        Text("今日已记").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("记录今日体重")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if todaysWeight == nil, let latestPriorWeight {
                Button {
                    reuseWeight(latestPriorWeight)
                } label: {
                    Text("沿用 \(WeightConvert.formatted(latestPriorWeight.weightKg, in: WeightPreference.current))")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Image(systemName: "scalemass")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func reuseWeight(_ source: BodyWeightEntry) {
        context.insert(BodyWeightEntry(date: .now, weightKg: source.weightKg))
        try? context.save()
    }

    private func loadLatestPriorWeight() {
        guard latestPriorWeight == nil else { return }
        let today = Calendar.current.startOfDay(for: .now)
        var descriptor = FetchDescriptor<BodyWeightEntry>(
            predicate: #Predicate { $0.date < today },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        latestPriorWeight = try? context.fetch(descriptor).first
    }

    private var dateHeader: some View {
        Text(Date.now, format: .dateTime.year().month(.wide).day().weekday(.wide))
            .font(.headline)
    }

    @ViewBuilder
    private var trainingCard: some View {
        if let day = todaysDayPlan {
            NavigationLink {
                DayDetailView(day: day, planDate: Calendar.current.startOfDay(for: .now))
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "dumbbell")
                        Text("计划：\(DefaultTemplate.displayLabel(DefaultTemplate.raw(from: day.strengthType)))")
                            .fontWeight(.semibold)
                        Spacer()
                        if !todaysWorkouts.isEmpty {
                            Label("已完成", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                    if let cardio = day.plannedCardio, !cardio.isEmpty {
                        Label(cardio, systemImage: "figure.run")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    if let strength = todaysWorkouts.first(where: { $0.kind == .strength }), !strength.sets.isEmpty {
                        Text("\(strength.sets.count) 组 / \(distinctExercises(strength)) 个动作")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(todaysWorkouts.filter { $0.kind == .cardio }) { cardio in
                        Text("\(cardio.cardioActivity ?? "") · \(cardio.cardioDurationMinutes ?? 0) 分钟 · \(intensityLabel(cardio.cardioIntensity))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        } else {
            Text("还没生成本周计划")
                .foregroundStyle(.secondary)
        }
    }

    private func distinctExercises(_ workout: WorkoutEntry) -> Int {
        Set(workout.sets.map(\.exerciseName)).count
    }

    private func intensityLabel(_ intensity: CardioIntensity?) -> String {
        switch intensity {
        case .high: "高强度"
        case .medium: "中等强度"
        case .low: "低强度"
        case .none: "—"
        }
    }

    private var nutritionCard: some View {
        VStack(spacing: 12) {
            ProgressRow(
                label: "热量",
                value: totalKcal,
                goal: Goals.dailyKcal,
                unit: "kcal",
                tint: .orange
            )
            ProgressRow(
                label: "蛋白质",
                value: totalProtein,
                goal: Goals.dailyProtein,
                unit: "g",
                tint: .blue
            )
        }
        .padding(.vertical, 4)
    }

    private var energyBalanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                energyValue("已摄入", value: energyBalance.intakeCalories, tint: .orange)
                Divider()
                energyValue("估算消耗", value: energyBalance.totalBurnCalories, tint: .blue)
                Divider()
                energyValue(
                    energyBalance.calorieGap >= 0 ? "估算缺口" : "估算超出",
                    value: abs(energyBalance.calorieGap),
                    tint: energyBalance.calorieGap >= 0 ? .green : .red
                )
            }
            if energyBalance.exerciseCalories > 0 {
                Text("训练约 \(NutritionFormat.kcal(energyBalance.exerciseCalories)) kcal，已计入消耗")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(energyBalance.advice)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("消耗为全天粗估，重点看 7 天体重和摄入趋势。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func energyValue(_ label: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(NutritionFormat.kcal(value))")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(tint)
            Text("kcal")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mealList: some View {
        ForEach(todaysMeals.sorted(by: { mealOrder($0.mealType) < mealOrder($1.mealType) })) { meal in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(mealLabel(meal.mealType)).fontWeight(.medium)
                    Spacer()
                    Text("\(NutritionFormat.kcal(meal.totalCalories)) kcal")
                        .font(.caption)
                        .monospacedDigit()
                }
                ForEach(meal.items) { item in
                    Text("· \(itemName(item))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func itemName(_ item: MealItem) -> String {
        item.recipe?.name ?? item.ingredient?.name ?? item.estimatedName ?? "—"
    }

    private func mealOrder(_ type: MealType) -> Int {
        switch type {
        case .breakfast: 0
        case .lunch: 1
        case .dinner: 2
        case .snack: 3
        }
    }

    private func mealLabel(_ type: MealType) -> String {
        switch type {
        case .breakfast: "早餐"
        case .lunch: "午餐"
        case .dinner: "晚餐"
        case .snack: "加餐"
        }
    }
}

private struct ProgressRow: View {
    let label: String
    let value: Double
    let goal: Double
    let unit: String
    let tint: Color

    private var ratio: Double { goal > 0 ? min(value / goal, 1.0) : 0 }
    private var displayValue: Int { Int(value.rounded()) }
    private var displayGoal: Int { Int(goal.rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(displayValue) / \(displayGoal) \(unit)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: ratio)
                .tint(tint)
        }
    }
}

private struct GoalsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kcalText: String = String(Int(Goals.dailyKcal))
    @State private var proteinText: String = String(Int(Goals.dailyProtein))
    @State private var baselineBurnText: String = String(Int(Goals.baselineDailyBurn))
    @State private var aiEndpoint = Goals.aiEndpoint
    @State private var aiAccessToken = Goals.aiAccessToken

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("每天的目标摄入。可以根据增肌/减脂目标随时调整。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("每日目标") {
                    HStack {
                        Text("热量")
                        Spacer()
                        TextField("kcal", text: $kcalText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kcal").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("蛋白质")
                        Spacer()
                        TextField("g", text: $proteinText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("基础日消耗")
                        Spacer()
                        TextField("kcal", text: $baselineBurnText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kcal").foregroundStyle(.secondary)
                    }
                }
                Section {
                    TextField("https://.../api/analyze-meal", text: $aiEndpoint)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    SecureField("访问令牌（可选）", text: $aiAccessToken)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("AI 营养估算")
                } footer: {
                    Text("这里填写你部署的代理地址。OpenAI API Key 只放在服务端，不能写入 App。")
                }
            }
            .navigationTitle("每日目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let k = Double(kcalText), k > 0 { Goals.dailyKcal = k }
                        if let p = Double(proteinText), p > 0 { Goals.dailyProtein = p }
                        if let b = Double(baselineBurnText), b > 0 { Goals.baselineDailyBurn = b }
                        Goals.aiEndpoint = aiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
                        Goals.aiAccessToken = aiAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct WeightLogSheet: View {
    let existing: BodyWeightEntry?
    let suggested: BodyWeightEntry?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var weightText: String = ""

    private var unit: WeightUnit { WeightPreference.current }

    var body: some View {
        NavigationStack {
            Form {
                Section("今日体重") {
                    HStack {
                        TextField("体重", text: $weightText)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .monospacedDigit()
                        Text(unit.label).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        adjustButton(systemName: "minus", delta: -0.1)
                        adjustButton(systemName: "plus", delta: 0.1)
                    }
                }
                if existing == nil, let suggested {
                    Section {
                        Button {
                            weightText = WeightConvert.formatted(suggested.weightKg, in: unit)
                            save()
                        } label: {
                            Label(
                                "沿用上次 \(WeightConvert.formatted(suggested.weightKg, in: unit)) \(unit.label)",
                                systemImage: "arrow.uturn.backward.circle"
                            )
                        }
                    } footer: {
                        Text("体重没明显变化时，一次点击即可完成记录。")
                    }
                }
            }
            .navigationTitle("记录体重")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if weightText.isEmpty, let existing {
                    weightText = WeightConvert.formatted(existing.weightKg, in: unit)
                } else if weightText.isEmpty, let suggested {
                    weightText = WeightConvert.formatted(suggested.weightKg, in: unit)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled((Double(weightText) ?? 0) <= 0)
                }
            }
        }
    }

    private func adjustButton(systemName: String, delta: Double) -> some View {
        Button {
            let current = Double(weightText) ?? 0
            weightText = String(format: "%.1f", max(0, current + delta))
        } label: {
            Image(systemName: systemName)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
    }

    private func save() {
        guard let input = Double(weightText), input > 0 else { return }
        let kg = WeightConvert.toKg(input, from: unit)
        if let existing {
            existing.weightKg = kg
        } else {
            let entry = BodyWeightEntry(date: .now, weightKg: kg)
            context.insert(entry)
        }
        try? context.save()
        dismiss()
    }
}
