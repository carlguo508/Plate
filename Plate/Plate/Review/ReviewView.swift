import SwiftUI
import SwiftData
import Charts

struct ReviewView: View {
    @Environment(\.modelContext) private var context
    @State private var range: Range = .week
    @Query(sort: \MealEntry.date) private var meals: [MealEntry]
    @Query(sort: \WorkoutEntry.date) private var workouts: [WorkoutEntry]
    @Query(sort: \BodyWeightEntry.date) private var weights: [BodyWeightEntry]
    @State private var selectedExercise: String?

    enum Range: String, CaseIterable, Identifiable {
        case week = "7天"
        case month = "30天"
        var id: String { rawValue }
        var days: Int { self == .week ? 7 : 30 }
    }

    private var dayBuckets: [DayBucket] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<range.days).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let dayMeals = meals.filter { cal.isDate($0.date, inSameDayAs: date) }
            let dayWorkouts = workouts.filter { cal.isDate($0.date, inSameDayAs: date) }
            return DayBucket(
                date: date,
                kcal: dayMeals.reduce(0) { $0 + $1.totalCalories },
                protein: dayMeals.reduce(0) { $0 + $1.totalProtein },
                hadStrength: dayWorkouts.contains { $0.kind == .strength },
                hadCardio: dayWorkouts.contains { $0.kind == .cardio }
            )
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("", selection: $range) {
                        ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)

                if !weightPoints.isEmpty {
                    Section("体重趋势") { weightChart }
                }
                Section("热量摄入") { kcalChart }
                Section("蛋白质摄入") { proteinChart }
                Section("训练日") { trainingChart }
                if !exerciseNames.isEmpty {
                    Section("动作进步") { exerciseProgressChart }
                }
                Section { summaryCard }
                    .listRowBackground(Color.clear)
            }
            .navigationTitle("回顾")
        }
    }

    // MARK: - Charts

    private var kcalChart: some View {
        Chart {
            ForEach(dayBuckets) { bucket in
                BarMark(
                    x: .value("日期", bucket.date, unit: .day),
                    y: .value("热量", bucket.kcal)
                )
                .foregroundStyle(.orange)
            }
            RuleMark(y: .value("目标", Goals.dailyKcal))
                .foregroundStyle(.gray)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("目标 \(NutritionFormat.kcal(Goals.dailyKcal))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 180)
    }

    private var proteinChart: some View {
        Chart(dayBuckets) { bucket in
            LineMark(
                x: .value("日期", bucket.date, unit: .day),
                y: .value("蛋白", bucket.protein)
            )
            .foregroundStyle(.blue)
            PointMark(
                x: .value("日期", bucket.date, unit: .day),
                y: .value("蛋白", bucket.protein)
            )
            .foregroundStyle(.blue)
        }
        .frame(height: 160)
    }

    private var trainingChart: some View {
        Chart(dayBuckets) { bucket in
            BarMark(
                x: .value("日期", bucket.date, unit: .day),
                y: .value("训练", bucket.trainingScore)
            )
            .foregroundStyle(by: .value("类型", bucket.label))
        }
        .chartForegroundStyleScale([
            "力量": Color.purple,
            "有氧": Color.green,
            "力量+有氧": Color.indigo,
            "休息": Color.gray.opacity(0.3),
        ])
        .frame(height: 140)
    }

    // MARK: - Weight trend

    private var weightChart: some View {
        let unit = WeightPreference.current
        return Chart {
            ForEach(weightPoints) { point in
                LineMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("体重", WeightConvert.display(point.kg, in: unit)),
                    series: .value("线", "实测")
                )
                .foregroundStyle(.green.opacity(0.4))
                PointMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("体重", WeightConvert.display(point.kg, in: unit))
                )
                .foregroundStyle(.green.opacity(0.4))
                .symbolSize(20)
            }
            ForEach(weightPoints) { point in
                if let avg = point.movingAvgKg {
                    LineMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("7日均值", WeightConvert.display(avg, in: unit)),
                        series: .value("线", "7日均值")
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 180)
    }

    // MARK: - Exercise progress

    private var exerciseProgressChart: some View {
        let current = selectedExercise ?? exerciseNames.first
        let unit = WeightPreference.current
        return VStack(alignment: .leading, spacing: 8) {
            Picker("动作", selection: Binding(
                get: { current ?? "" },
                set: { selectedExercise = $0 }
            )) {
                ForEach(exerciseNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .pickerStyle(.menu)

            let points = topSetProgress(for: current)
            if points.count < 2 {
                Text("至少记录两次才能看到趋势")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("最大重量", WeightConvert.display(point.kg, in: unit))
                    )
                    .foregroundStyle(.purple)
                    PointMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("最大重量", WeightConvert.display(point.kg, in: unit))
                    )
                    .foregroundStyle(.purple)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 160)
                Text("每次训练该动作的最大重量（\(unit.label)）")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            stat("日均热量", String(Int(avgKcal.rounded())) + " kcal")
            stat("日均蛋白", String(Int(avgProtein.rounded())) + " g")
            stat("训练天数", "\(trainingDayCount) / \(range.days)")
        }
        .padding(.vertical, 4)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.body).fontWeight(.semibold).monospacedDigit()
        }
    }

    // MARK: - Aggregates

    private var nonEmptyDays: [DayBucket] { dayBuckets.filter { $0.kcal > 0 } }
    private var avgKcal: Double {
        nonEmptyDays.isEmpty ? 0 : nonEmptyDays.reduce(0) { $0 + $1.kcal } / Double(nonEmptyDays.count)
    }
    private var avgProtein: Double {
        nonEmptyDays.isEmpty ? 0 : nonEmptyDays.reduce(0) { $0 + $1.protein } / Double(nonEmptyDays.count)
    }
    private var trainingDayCount: Int {
        dayBuckets.filter { $0.hadStrength || $0.hadCardio }.count
    }

    // MARK: - Weight / exercise aggregates

    /// One point per day with a reading, within the selected range, plus a 7-day moving average.
    private var weightPoints: [WeightPoint] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -range.days, to: cal.startOfDay(for: .now)) ?? .distantPast
        let inRange = weights
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
        return inRange.enumerated().map { index, entry in
            // 7-day moving average: average of readings within 7 days up to and including this one
            let windowStart = cal.date(byAdding: .day, value: -6, to: entry.date) ?? entry.date
            let window = inRange.filter { $0.date >= windowStart && $0.date <= entry.date }
            let avg = window.isEmpty ? nil : window.reduce(0) { $0 + $1.weightKg } / Double(window.count)
            return WeightPoint(date: entry.date, kg: entry.weightKg, movingAvgKg: avg)
        }
    }

    private var exerciseNames: [String] {
        let names = workouts
            .filter { $0.kind == .strength }
            .flatMap { $0.sets.map(\.exerciseName) }
        return Array(Set(names)).sorted()
    }

    /// Top-set (max weight) per training day for the given exercise, within range.
    private func topSetProgress(for exercise: String?) -> [WeightPoint] {
        guard let exercise else { return [] }
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -range.days, to: cal.startOfDay(for: .now)) ?? .distantPast
        var maxByDay: [Date: Double] = [:]
        for workout in workouts where workout.kind == .strength && workout.date >= cutoff {
            let day = cal.startOfDay(for: workout.date)
            for set in workout.sets where set.exerciseName == exercise {
                maxByDay[day] = max(maxByDay[day] ?? 0, set.weightKg)
            }
        }
        return maxByDay
            .map { WeightPoint(date: $0.key, kg: $0.value, movingAvgKg: nil) }
            .sorted { $0.date < $1.date }
    }
}

private struct WeightPoint: Identifiable {
    let date: Date
    let kg: Double
    let movingAvgKg: Double?
    var id: Date { date }
}

private struct DayBucket: Identifiable {
    let date: Date
    let kcal: Double
    let protein: Double
    let hadStrength: Bool
    let hadCardio: Bool
    var id: Date { date }

    var trainingScore: Int {
        if hadStrength && hadCardio { return 2 }
        if hadStrength || hadCardio { return 1 }
        return 0
    }

    var label: String {
        switch (hadStrength, hadCardio) {
        case (true, true): "力量+有氧"
        case (true, false): "力量"
        case (false, true): "有氧"
        case (false, false): "休息"
        }
    }
}
