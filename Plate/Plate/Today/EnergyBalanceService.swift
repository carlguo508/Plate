import Foundation

struct DailyEnergyBalance: Equatable {
    let intakeCalories: Double
    let protein: Double
    let exerciseCalories: Double
    let totalBurnCalories: Double

    var calorieGap: Double { totalBurnCalories - intakeCalories }

    var advice: String {
        if intakeCalories <= 0 {
            return "先记录今天吃的东西，热量缺口才有参考意义。"
        }
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 19 && intakeCalories < Goals.dailyKcal * 0.75 {
            return "今天的饮食还可能没记录完，先继续正常记录，晚上再看全天缺口。"
        }
        if protein < Goals.dailyProtein * 0.75 {
            let remaining = max(0, Goals.dailyProtein - protein)
            return "蛋白质还差约 \(Int(remaining.rounded())) g，下一餐可优先选瘦肉、鱼、蛋或奶。"
        }
        if calorieGap > 700 {
            return "按全天估算，缺口偏大。优先补足蛋白质和正常正餐，避免长期过度节食。"
        }
        if calorieGap >= 300 {
            return "目前处在温和热量缺口范围，继续关注一到两周的体重趋势。"
        }
        if calorieGap >= 0 {
            return "今天接近维持或小幅缺口，是否调整可结合本周平均体重。"
        }
        return "今天摄入暂时高于估算消耗。单日不用紧张，观察一周平均更有意义。"
    }
}

enum EnergyBalanceService {
    static func calculate(
        meals: [MealEntry],
        workouts: [WorkoutEntry],
        bodyWeightKg: Double?
    ) -> DailyEnergyBalance {
        let weight = bodyWeightKg ?? 70
        let exercise = workouts.reduce(0) { $0 + estimatedExerciseCalories($1, bodyWeightKg: weight) }
        return DailyEnergyBalance(
            intakeCalories: meals.reduce(0) { $0 + $1.totalCalories },
            protein: meals.reduce(0) { $0 + $1.totalProtein },
            exerciseCalories: exercise,
            totalBurnCalories: Goals.baselineDailyBurn + exercise
        )
    }

    static func estimatedExerciseCalories(_ workout: WorkoutEntry, bodyWeightKg: Double) -> Double {
        switch workout.kind {
        case .strength:
            guard !workout.sets.isEmpty else { return 0 }
            return min(500, max(80, Double(workout.sets.count) * 10 * bodyWeightKg / 70))
        case .cardio:
            let minutes = Double(workout.cardioDurationMinutes ?? 0)
            guard minutes > 0 else { return 0 }
            let met = cardioMET(
                activity: workout.cardioActivity ?? "",
                intensity: workout.cardioIntensity ?? .medium
            )
            return met * 3.5 * bodyWeightKg / 200 * minutes
        }
    }

    private static func cardioMET(activity: String, intensity: CardioIntensity) -> Double {
        let normalized = activity.lowercased()
        let base: Double
        if normalized.contains("篮球") || normalized.contains("basketball") {
            base = 7
        } else if normalized.contains("跑") || normalized.contains("run") {
            base = 8
        } else if normalized.contains("游泳") || normalized.contains("swim") {
            base = 7
        } else if normalized.contains("骑") || normalized.contains("cycle") || normalized.contains("bike") {
            base = 6
        } else if normalized.contains("走") || normalized.contains("walk") {
            base = 3.5
        } else {
            base = 6
        }

        return switch intensity {
        case .low: base * 0.75
        case .medium: base
        case .high: base * 1.25
        }
    }
}
