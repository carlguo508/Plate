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
    @State private var pendingReplacement: WorkoutKind?

    init(day: DayPlan, planDate: Date) {
        self.day = day
        self.planDate = planDate
        let dayStart = Calendar.current.startOfDay(for: planDate)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? planDate
        _workouts = Query(filter: #Predicate<WorkoutEntry> { $0.date >= dayStart && $0.date < dayEnd })
    }

    private var workout: WorkoutEntry? { workouts.sorted { $0.date < $1.date }.first }

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

            if let workout {
                Section("今日训练") {
                    HStack {
                        Label(
                            workout.kind == .strength ? "力量训练" : "有氧 / 球类",
                            systemImage: workout.kind == .strength ? "dumbbell" : "figure.run"
                        )
                        .fontWeight(.semibold)
                        Spacer()
                        Button("更换") {
                            requestWorkout(workout.kind == .strength ? .cardio : .strength)
                        }
                        .font(.caption)
                    }

                    if workout.kind == .strength {
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
                        Button {
                            showingStrengthLog = true
                        } label: {
                            Label("继续记录", systemImage: "plus.circle")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.cardioActivity ?? "—").font(.body)
                            HStack(spacing: 8) {
                                Text("\(workout.cardioDurationMinutes ?? 0) 分钟")
                                Text("强度：\(intensityLabel(workout.cardioIntensity))")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Button {
                            showingCardioLog = true
                        } label: {
                            Label("编辑记录", systemImage: "pencil")
                        }
                    }
                }
            } else {
                Section("今天练什么？") {
                    Button {
                        requestWorkout(.strength)
                    } label: {
                        Label("力量训练", systemImage: "dumbbell")
                    }
                    Button {
                        requestWorkout(.cardio)
                    } label: {
                        Label("有氧 / 球类", systemImage: "figure.run")
                    }
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
            CardioLogSheet(
                date: planDate,
                defaultActivity: day.plannedCardio ?? "",
                existing: workout?.kind == .cardio ? workout : nil
            )
        }
        .confirmationDialog(
            "更换今天的训练？",
            isPresented: Binding(
                get: { pendingReplacement != nil && workout != nil },
                set: { if !$0 { pendingReplacement = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除原记录并更换", role: .destructive) {
                guard let kind = pendingReplacement else { return }
                replaceWorkout(with: kind)
            }
            Button("取消", role: .cancel) {
                pendingReplacement = nil
            }
        } message: {
            Text("一天只保留一种训练。原有训练内容会被删除。")
        }
    }

    private func requestWorkout(_ kind: WorkoutKind) {
        if let workout, workout.kind != kind {
            pendingReplacement = kind
        } else {
            openLog(for: kind)
        }
    }

    private func replaceWorkout(with kind: WorkoutKind) {
        for entry in workouts {
            context.delete(entry)
        }
        try? context.save()
        pendingReplacement = nil
        openLog(for: kind)
    }

    private func openLog(for kind: WorkoutKind) {
        switch kind {
        case .strength:
            showingStrengthLog = true
        case .cardio:
            showingCardioLog = true
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

    @Query(sort: \WorkoutEntry.date, order: .reverse) private var allWorkouts: [WorkoutEntry]

    private var workout: WorkoutEntry? { workouts.first }

    /// Most recent strength session strictly before this day — the source for "repeat last".
    private var previousStrength: WorkoutEntry? {
        let dayStart = Calendar.current.startOfDay(for: date)
        return allWorkouts.first { $0.kind == .strength && $0.date < dayStart && !$0.sets.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                if (workout?.sets.isEmpty ?? true), let prev = previousStrength {
                    Section {
                        Button {
                            repeatWorkout(prev)
                        } label: {
                            Label("复制上次力量训练（\(distinctExerciseCount(prev)) 个动作）", systemImage: "arrow.clockwise")
                        }
                    } footer: {
                        Text("载入上次每个动作 + 当时的重量/次数，你再微调。")
                    }
                }
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
                    SuggestionChips(
                        suggestions: SuggestionService.strengthExercises(in: context),
                        selected: exerciseName
                    ) { picked in
                        exerciseName = picked
                    }
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

    private func distinctExerciseCount(_ w: WorkoutEntry) -> Int {
        Set(w.sets.map(\.exerciseName)).count
    }

    /// Copy each set from a prior workout into today's, preserving exercise order and weight/reps.
    private func repeatWorkout(_ source: WorkoutEntry) {
        WorkoutDayService.enforceSingleWorkout(kind: .strength, on: date, in: context)
        let entry: WorkoutEntry
        if let existing = workout {
            entry = existing
        } else {
            entry = WorkoutEntry.strength(date: date)
            context.insert(entry)
        }
        for srcSet in source.sets.sorted(by: { $0.order < $1.order }) {
            let copy = ExerciseSet(
                exerciseName: srcSet.exerciseName,
                weightKg: srcSet.weightKg,
                reps: srcSet.reps,
                order: entry.sets.count
            )
            copy.workout = entry
            entry.sets.append(copy)
            context.insert(copy)
        }
        try? context.save()
    }

    private func addSet() {
        WorkoutDayService.enforceSingleWorkout(kind: .strength, on: date, in: context)
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
    let existing: WorkoutEntry?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var activity: String = ""
    @State private var minutesText: String = "60"
    @State private var intensity: CardioIntensity = .medium

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SuggestionChips(
                        suggestions: SuggestionService.cardioActivities(in: context),
                        selected: activity
                    ) { picked in
                        activity = picked
                    }
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
            .onAppear {
                guard activity.isEmpty else { return }
                activity = existing?.cardioActivity ?? defaultActivity
                if let minutes = existing?.cardioDurationMinutes {
                    minutesText = String(minutes)
                }
                if let savedIntensity = existing?.cardioIntensity {
                    intensity = savedIntensity
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        WorkoutDayService.enforceSingleWorkout(kind: .cardio, on: date, in: context)
                        if let existing {
                            existing.cardioActivity = activity.trimmingCharacters(in: .whitespaces)
                            existing.cardioDurationMinutes = Int(minutesText) ?? 0
                            existing.cardioIntensity = intensity
                        } else {
                            let workout = WorkoutEntry.cardio(
                                activity: activity.trimmingCharacters(in: .whitespaces),
                                durationMinutes: Int(minutesText) ?? 0,
                                intensity: intensity,
                                date: date
                            )
                            context.insert(workout)
                        }
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

// MARK: - Suggestion chips

private struct SuggestionChips: View {
    let suggestions: [String]
    let selected: String
    let onTap: (String) -> Void

    var body: some View {
        if suggestions.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(suggestions, id: \.self) { item in
                        Button {
                            onTap(item)
                        } label: {
                            Text(item)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(item == selected ? Color.accentColor : Color(.tertiarySystemBackground))
                                .foregroundStyle(item == selected ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }
}
