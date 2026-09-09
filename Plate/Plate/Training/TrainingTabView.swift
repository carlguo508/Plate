import SwiftUI
import SwiftData

struct TrainingTabView: View {
    @Query(sort: \WorkoutEntry.date, order: .reverse) private var workouts: [WorkoutEntry]
    @State private var logDate = Calendar.current.startOfDay(for: .now)
    @State private var strengthRequest: StrengthLogRequest?
    @State private var showingCardioLog = false
    @State private var weightUnit = WeightPreference.current

    private var todaysWorkouts: [WorkoutEntry] {
        workouts.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var recentWorkouts: [WorkoutEntry] {
        workouts.filter { !Calendar.current.isDateInToday($0.date) }.prefix(12).map { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("重量单位") {
                    Picker("重量单位", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("training-weight-unit")
                    .onChange(of: weightUnit) { _, unit in
                        WeightPreference.current = unit
                    }
                }

                Section("今天") {
                    if todaysWorkouts.isEmpty {
                        Text("还没有训练记录")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(todaysWorkouts) { workout in
                            workoutRow(workout)
                        }
                    }

                    if todaysWorkouts.contains(where: { $0.kind == .strength }) {
                        Button {
                            let today = Calendar.current.startOfDay(for: .now)
                            logDate = today
                            strengthRequest = StrengthLogRequest(date: today)
                        } label: {
                            Label("继续力量训练", systemImage: "dumbbell.fill")
                                .fontWeight(.semibold)
                        }
                        .accessibilityIdentifier("continue-strength")
                    } else {
                        ForEach(StrengthRoutine.allCases) { routine in
                            Button {
                                let today = Calendar.current.startOfDay(for: .now)
                                logDate = today
                                strengthRequest = StrengthLogRequest(
                                    date: today,
                                    starterTemplate: routine.template(from: WorkoutTemplateStore.load())
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: routine == .legs ? "figure.strengthtraining.traditional" : "dumbbell.fill")
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(routine.title)
                                            .fontWeight(.semibold)
                                        Text(routine.muscleGroups)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .accessibilityIdentifier("start-routine-\(routine.rawValue)")
                        }
                        Button {
                            let today = Calendar.current.startOfDay(for: .now)
                            logDate = today
                            strengthRequest = StrengthLogRequest(date: today)
                        } label: {
                            Label("自定义训练", systemImage: "plus")
                        }
                        .accessibilityIdentifier("start-custom-strength")
                    }

                    Button {
                        logDate = Calendar.current.startOfDay(for: .now)
                        showingCardioLog = true
                    } label: {
                        Label("记录有氧", systemImage: "figure.run")
                    }
                }

                Section("最近训练") {
                    if recentWorkouts.isEmpty {
                        Text("完成第一次训练后，记录会出现在这里。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentWorkouts) { workout in
                            Button {
                                let workoutDate = Calendar.current.startOfDay(for: workout.date)
                                logDate = workoutDate
                                if workout.kind == .strength {
                                    strengthRequest = StrengthLogRequest(date: workoutDate)
                                } else {
                                    showingCardioLog = true
                                }
                            } label: {
                                workoutRow(workout)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("训练")
            .sheet(item: $strengthRequest, onDismiss: {
                weightUnit = WeightPreference.current
            }) { request in
                StrengthLogSheet(date: request.date, starterTemplate: request.starterTemplate)
            }
            .sheet(isPresented: $showingCardioLog) {
                CardioLogSheet(
                    date: logDate,
                    defaultActivity: "",
                    existing: workout(on: logDate, kind: .cardio)
                )
            }
        }
    }

    private func workout(on date: Date, kind: WorkoutKind) -> WorkoutEntry? {
        workouts.first { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.kind == kind }
    }

    private func workoutRow(_ workout: WorkoutEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: workout.kind == .strength ? "dumbbell.fill" : "figure.run")
                .foregroundStyle(workout.kind == .strength ? .purple : .green)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.kind == .strength ? "力量训练" : (workout.cardioActivity ?? "有氧"))
                    .fontWeight(.semibold)
                if workout.kind == .strength {
                    Text("\(Set(workout.sets.map(\.exerciseName)).count) 个动作 · \(workout.sets.count) 组")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(workout.cardioDurationMinutes ?? 0) 分钟")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !Calendar.current.isDateInToday(workout.date) {
                Text(workout.date, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct StrengthLogRequest: Identifiable {
    let id = UUID()
    let date: Date
    var starterTemplate: WorkoutTemplate? = nil
}
