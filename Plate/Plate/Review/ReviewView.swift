import SwiftUI
import SwiftData
import Charts

struct ReviewView: View {
    @Environment(\.modelContext) private var context
    @State private var range: Range = .week
    @Query(sort: \MealEntry.date) private var meals: [MealEntry]
    @Query(sort: \WorkoutEntry.date) private var workouts: [WorkoutEntry]

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

                Section("热量摄入") { kcalChart }
                Section("蛋白质摄入") { proteinChart }
                Section("训练日") { trainingChart }
                Section { summaryCard }
                    .listRowBackground(Color.clear)
            }
            .navigationTitle("回顾")
        }
    }

    // MARK: - Charts

    private var kcalChart: some View {
        Chart(dayBuckets) { bucket in
            BarMark(
                x: .value("日期", bucket.date, unit: .day),
                y: .value("热量", bucket.kcal)
            )
            .foregroundStyle(.orange)
        }
        .chartForegroundStyleScale(["热量": Color.orange, "目标": Color.gray])
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let yRange = proxy.plotFrame.map({ geo[$0] }) {
                    let y = (1 - Goals.dailyKcal / max(maxKcal, Goals.dailyKcal)) * yRange.height + yRange.minY
                    Path { p in
                        p.move(to: CGPoint(x: yRange.minX, y: y))
                        p.addLine(to: CGPoint(x: yRange.maxX, y: y))
                    }
                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
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

    private var maxKcal: Double { dayBuckets.map(\.kcal).max() ?? 0 }
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
