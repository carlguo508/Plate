import SwiftUI
import SwiftData

struct TrainingTabView: View {
    @Environment(\.modelContext) private var context
    @State private var selectedWeekAnchor: Date = .now
    @State private var showingTemplate = false

    private var plan: WeeklyPlan {
        WeekPlanService.planForWeek(of: selectedWeekAnchor, in: context)
    }

    private var conflicts: [Int: String] {
        WeekPlanService.conflicts(in: plan)
    }

    var body: some View {
        NavigationStack {
            List {
                Section { weekHeader }
                    .listRowBackground(Color.clear)

                Section {
                    ForEach(plan.days.sorted(by: { $0.dayIndex < $1.dayIndex })) { day in
                        NavigationLink {
                            DayDetailView(day: day, planDate: dateForDay(day))
                        } label: {
                            DayRow(
                                day: day,
                                planDate: dateForDay(day),
                                conflictNote: conflicts[day.dayIndex]
                            )
                        }
                    }
                    .onMove(perform: swapDays)
                } footer: {
                    Text("点右上角「调整」拖动两天来对调训练类型。")
                        .font(.caption2)
                }
            }
            .navigationTitle("训练")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingTemplate = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingTemplate) {
                DefaultTemplateEditor()
            }
        }
    }

    private func dateForDay(_ day: DayPlan) -> Date {
        WeekPlanService.date(forDay: day.dayIndex, in: plan)
    }

    /// Swap strength assignments between two weekdays. The day cells stay anchored to their weekday;
    /// only the planned strength type moves. Planned cardio is left untouched (it usually ties to a fixed event).
    private func swapDays(from source: IndexSet, to destination: Int) {
        let sorted = plan.days.sorted(by: { $0.dayIndex < $1.dayIndex })
        guard let src = source.first else { return }
        let dst = destination > src ? destination - 1 : destination
        guard dst >= 0, dst < sorted.count, dst != src else { return }
        let tmp = sorted[src].strengthType
        sorted[src].strengthType = sorted[dst].strengthType
        sorted[dst].strengthType = tmp
        try? context.save()
    }

    private var weekHeader: some View {
        HStack {
            Button { shiftWeek(by: -1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            VStack(spacing: 2) {
                Text(weekTitle)
                    .font(.headline)
                if !isCurrentWeek {
                    Button("回到本周") { selectedWeekAnchor = .now }
                        .font(.caption)
                }
            }
            Spacer()
            Button { shiftWeek(by: 1) } label: { Image(systemName: "chevron.right") }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.vertical, 4)
    }

    private var weekTitle: String {
        let start = WeekPlanService.mondayStart(of: selectedWeekAnchor)
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    private var isCurrentWeek: Bool {
        WeekPlanService.mondayStart(of: selectedWeekAnchor) == WeekPlanService.mondayStart(of: .now)
    }

    private func shiftWeek(by weeks: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: weeks * 7, to: selectedWeekAnchor) {
            selectedWeekAnchor = next
        }
    }
}

private struct DayRow: View {
    let day: DayPlan
    let planDate: Date
    let conflictNote: String?

    private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text("周\(weekdayLabels[day.dayIndex])")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(planDate, format: .dateTime.day())
                    .font(.headline)
                    .frame(width: 32, height: 32)
                    .background(isToday ? Color.accentColor : Color.clear)
                    .foregroundStyle(isToday ? .white : .primary)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(DefaultTemplate.displayLabel(DefaultTemplate.raw(from: day.strengthType)))
                        .font(.body)
                        .fontWeight(day.strengthType == .rest ? .regular : .semibold)
                        .foregroundStyle(day.strengthType == .rest ? .secondary : .primary)
                    Spacer()
                }
                if let cardio = day.plannedCardio, !cardio.isEmpty {
                    Label(cardio, systemImage: "figure.run")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                if let note = conflictNote {
                    Label(note, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(planDate)
    }
}

// MARK: - Default Template Editor

private struct DefaultTemplateEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var days: [String] = DefaultTemplate.load()
    @State private var weightUnit: WeightUnit = WeightPreference.current

    private let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("这是你的每周固定计划。每周开始时，app 会以此为底版生成本周排程，你可以随时调整某一周。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("重量单位") {
                    Picker("单位", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("每周训练模板") {
                    ForEach(0..<7, id: \.self) { i in
                        HStack {
                            Text(weekdays[i])
                                .frame(width: 50, alignment: .leading)
                            Spacer()
                            Picker("", selection: $days[i]) {
                                ForEach(DefaultTemplate.standardCodes, id: \.self) { code in
                                    Text(DefaultTemplate.displayLabel(code)).tag(code)
                                }
                                // include current custom value if present
                                if !DefaultTemplate.standardCodes.contains(days[i]) {
                                    Text(days[i]).tag(days[i])
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }
            }
            .navigationTitle("训练设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        DefaultTemplate.save(days)
                        WeightPreference.current = weightUnit
                        dismiss()
                    }
                }
            }
        }
    }
}
