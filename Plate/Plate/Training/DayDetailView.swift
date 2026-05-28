import SwiftUI
import SwiftData

struct DayDetailView: View {
    @Bindable var day: DayPlan
    let planDate: Date

    @Environment(\.modelContext) private var context
    @Query private var workouts: [WorkoutEntry]
    @State private var cardioText: String = ""
    @State private var showingStrengthLog = false
    @State private var showingCardioLog = false

    init(day: DayPlan, planDate: Date) {
        self.day = day
        self.planDate = planDate
        let dayStart = Calendar.current.startOfDay(for: planDate)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? planDate
        _workouts = Query(filter: #Predicate<WorkoutEntry> { $0.date >= dayStart && $0.date < dayEnd })
    }

    private var strengthWorkout: WorkoutEntry? {
        workouts.first { $0.kind == .strength }
    }

    private var cardioWorkouts: [WorkoutEntry] {
        workouts.filter { $0.kind == .cardio }
    }

    var body: some View {
        Form {
            Section("计划") {
                Picker("力量训练", selection: Binding(
                    get: { DefaultTemplate.raw(from: day.strengthType) },
                    set: { day.strengthType = DefaultTemplate.strengthType(from: $0); try? context.save() }
                )) {
                    ForEach(DefaultTemplate.standardCodes, id: \.self) { code in
                        Text(DefaultTemplate.displayLabel(code)).tag(code)
                    }
                }
                HStack {
                    Text("计划球类 / 有氧")
                    Spacer()
                    TextField("如：篮球", text: $cardioText)
                        .multilineTextAlignment(.trailing)
                        .onSubmit(saveCardio)
                        .onChange(of: cardioText) { _, _ in saveCardio() }
                }
            }

            Section("力量记录") {
                if let workout = strengthWorkout {
                    ForEach(workout.sets.sorted(by: { $0.order < $1.order })) { set in
                        HStack {
                            Text(set.exerciseName)
                            Spacer()
                            Text("\(WeightConvert.formatted(set.weightKg, in: WeightPreference.current)) \(WeightPreference.current.label) × \(set.reps)")
                                .font(.caption)
                                .monospacedDigit()
                        }
                    }
                    .onDelete { offsets in
                        let sorted = workout.sets.sorted(by: { $0.order < $1.order })
                        for index in offsets {
                            context.delete(sorted[index])
                        }
                        try? context.save()
                    }
                }
                Button {
                    showingStrengthLog = true
                } label: {
                    Label("记录力量训练", systemImage: "dumbbell")
                }
            }

            Section("有氧 / 球类记录") {
                ForEach(cardioWorkouts) { workout in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.cardioActivity ?? "—").font(.body)
                        HStack(spacing: 8) {
                            Text("\(workout.cardioDurationMinutes ?? 0) 分钟")
                            Text("强度：\(intensityLabel(workout.cardioIntensity))")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(cardioWorkouts[index])
                    }
                    try? context.save()
                }
                Button {
                    showingCardioLog = true
                } label: {
                    Label("记录有氧 / 球类", systemImage: "figure.run")
                }
            }
        }
        .navigationTitle(planDate.formatted(.dateTime.month().day().weekday(.wide)))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cardioText = day.plannedCardio ?? ""
        }
        .sheet(isPresented: $showingStrengthLog) {
            StrengthLogSheet(date: planDate)
        }
        .sheet(isPresented: $showingCardioLog) {
            CardioLogSheet(date: planDate, defaultActivity: day.plannedCardio ?? "")
        }
    }

    private func saveCardio() {
        let trimmed = cardioText.trimmingCharacters(in: .whitespaces)
        day.plannedCardio = trimmed.isEmpty ? nil : trimmed
        try? context.save()
    }

    private func intensityLabel(_ intensity: CardioIntensity?) -> String {
        switch intensity {
        case .high: "高"
        case .medium: "中"
        case .low: "低"
        case .none: "—"
        }
    }
}

// MARK: - Strength log

private struct StrengthLogSheet: View {
    let date: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var exerciseName: String = ""
    @State private var weightText: String = ""
    @State private var repsText: String = ""

    @Query private var workouts: [WorkoutEntry]

    init(date: Date) {
        self.date = date
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let strengthKind = WorkoutKind.strength
        _workouts = Query(filter: #Predicate<WorkoutEntry> {
            $0.date >= dayStart && $0.date < dayEnd && $0.kind == strengthKind
        })
    }

    private var workout: WorkoutEntry? { workouts.first }

    var body: some View {
        NavigationStack {
            Form {
                if let workout {
                    Section("已记录的组") {
                        ForEach(workout.sets.sorted(by: { $0.order < $1.order })) { set in
                            HStack {
                                Text(set.exerciseName)
                                Spacer()
                                Text("\(WeightConvert.formatted(set.weightKg, in: WeightPreference.current)) \(WeightPreference.current.label) × \(set.reps)")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                Section("加一组") {
                    TextField("动作（如 卧推）", text: $exerciseName)
                    HStack {
                        TextField("重量", text: $weightText)
                            .keyboardType(.decimalPad)
                        Text(WeightPreference.current.label).foregroundStyle(.secondary)
                        TextField("次数", text: $repsText)
                            .keyboardType(.numberPad)
                        Text("reps").foregroundStyle(.secondary)
                    }
                    Button("加入") { addSet() }
                        .disabled(!canAdd)
                }
            }
            .navigationTitle("力量记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var canAdd: Bool {
        !exerciseName.trimmingCharacters(in: .whitespaces).isEmpty
            && (Double(weightText) ?? -1) >= 0
            && (Int(repsText) ?? 0) > 0
    }

    private func addSet() {
        let entry: WorkoutEntry
        if let existing = workout {
            entry = existing
        } else {
            entry = WorkoutEntry.strength(date: date)
            context.insert(entry)
        }
        let order = entry.sets.count
        let input = Double(weightText) ?? 0
        let kg = WeightConvert.toKg(input, from: WeightPreference.current)
        let set = ExerciseSet(
            exerciseName: exerciseName.trimmingCharacters(in: .whitespaces),
            weightKg: kg,
            reps: Int(repsText) ?? 0,
            order: order
        )
        set.workout = entry
        entry.sets.append(set)
        context.insert(set)
        try? context.save()
        weightText = ""
        repsText = ""
    }
}

// MARK: - Cardio log

private struct CardioLogSheet: View {
    let date: Date
    let defaultActivity: String

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var activity: String = ""
    @State private var minutesText: String = "60"
    @State private var intensity: CardioIntensity = .medium

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("项目（如 篮球）", text: $activity)
                    HStack {
                        TextField("时长", text: $minutesText)
                            .keyboardType(.numberPad)
                        Text("分钟").foregroundStyle(.secondary)
                    }
                    Picker("强度", selection: $intensity) {
                        Text("低").tag(CardioIntensity.low)
                        Text("中").tag(CardioIntensity.medium)
                        Text("高").tag(CardioIntensity.high)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("有氧记录")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if activity.isEmpty { activity = defaultActivity } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let workout = WorkoutEntry.cardio(
                            activity: activity.trimmingCharacters(in: .whitespaces),
                            durationMinutes: Int(minutesText) ?? 0,
                            intensity: intensity,
                            date: date
                        )
                        context.insert(workout)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(activity.trimmingCharacters(in: .whitespaces).isEmpty
                        || (Int(minutesText) ?? 0) <= 0)
                }
            }
        }
    }
}
