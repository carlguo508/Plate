import Foundation

/// Plain-data definition of a built-in ingredient — used by `SeedData` to populate the store on first launch.
/// Nutrition values are per 100g of edible portion. Sources: USDA FoodData Central + China Food Composition Tables (rounded).
struct BuiltInIngredient {
    let name: String
    let category: IngredientCategory
    let kcal100g: Double
    let protein100g: Double
    let carbs100g: Double
    let fat100g: Double
    let defaultUnitGrams: Double?
}

enum BuiltInIngredients {
    static let all: [BuiltInIngredient] = [
        // MARK: 蛋白质
        .init(name: "鸡胸肉", category: .protein, kcal100g: 165, protein100g: 31.0, carbs100g: 0, fat100g: 3.6, defaultUnitGrams: nil),
        .init(name: "鸡腿", category: .protein, kcal100g: 181, protein100g: 24.0, carbs100g: 0, fat100g: 9.0, defaultUnitGrams: nil),
        .init(name: "鸡翅", category: .protein, kcal100g: 203, protein100g: 30.5, carbs100g: 0, fat100g: 8.1, defaultUnitGrams: 50),
        .init(name: "瘦牛肉", category: .protein, kcal100g: 250, protein100g: 26.0, carbs100g: 0, fat100g: 15.0, defaultUnitGrams: nil),
        .init(name: "牛腩", category: .protein, kcal100g: 332, protein100g: 17.0, carbs100g: 0, fat100g: 29.0, defaultUnitGrams: nil),
        .init(name: "猪里脊", category: .protein, kcal100g: 155, protein100g: 21.0, carbs100g: 0, fat100g: 7.9, defaultUnitGrams: nil),
        .init(name: "三文鱼", category: .protein, kcal100g: 208, protein100g: 20.0, carbs100g: 0, fat100g: 13.0, defaultUnitGrams: nil),
        .init(name: "虾", category: .protein, kcal100g: 99, protein100g: 24.0, carbs100g: 0.2, fat100g: 0.3, defaultUnitGrams: 10),
        .init(name: "鸡蛋", category: .protein, kcal100g: 144, protein100g: 13.0, carbs100g: 0.7, fat100g: 9.0, defaultUnitGrams: 50),
        .init(name: "鸭蛋", category: .protein, kcal100g: 180, protein100g: 13.0, carbs100g: 1.4, fat100g: 14.0, defaultUnitGrams: 70),
        .init(name: "老豆腐", category: .protein, kcal100g: 98, protein100g: 12.2, carbs100g: 4.8, fat100g: 4.8, defaultUnitGrams: nil),
        .init(name: "嫩豆腐", category: .protein, kcal100g: 55, protein100g: 5.0, carbs100g: 1.9, fat100g: 3.0, defaultUnitGrams: nil),
        .init(name: "豆浆", category: .protein, kcal100g: 31, protein100g: 1.8, carbs100g: 1.1, fat100g: 0.7, defaultUnitGrams: 250),

        // MARK: 乳制品
        .init(name: "牛奶", category: .dairy, kcal100g: 65, protein100g: 3.3, carbs100g: 4.9, fat100g: 3.6, defaultUnitGrams: 250),
        .init(name: "酸奶", category: .dairy, kcal100g: 72, protein100g: 2.5, carbs100g: 9.3, fat100g: 2.7, defaultUnitGrams: 100),
        .init(name: "希腊酸奶", category: .dairy, kcal100g: 97, protein100g: 9.0, carbs100g: 4.0, fat100g: 5.0, defaultUnitGrams: 150),
        .init(name: "奶酪", category: .dairy, kcal100g: 350, protein100g: 25.0, carbs100g: 1.3, fat100g: 28.0, defaultUnitGrams: 20),

        // MARK: 主食
        .init(name: "白米饭", category: .grain, kcal100g: 116, protein100g: 2.6, carbs100g: 25.6, fat100g: 0.3, defaultUnitGrams: nil),
        .init(name: "糙米饭", category: .grain, kcal100g: 112, protein100g: 2.6, carbs100g: 22.0, fat100g: 0.9, defaultUnitGrams: nil),
        .init(name: "燕麦", category: .grain, kcal100g: 367, protein100g: 15.0, carbs100g: 61.0, fat100g: 6.7, defaultUnitGrams: nil),
        .init(name: "面条（生）", category: .grain, kcal100g: 286, protein100g: 8.3, carbs100g: 58.0, fat100g: 1.6, defaultUnitGrams: nil),
        .init(name: "馒头", category: .grain, kcal100g: 223, protein100g: 7.0, carbs100g: 47.0, fat100g: 1.1, defaultUnitGrams: 100),
        .init(name: "意大利面（生）", category: .grain, kcal100g: 371, protein100g: 13.0, carbs100g: 75.0, fat100g: 1.5, defaultUnitGrams: nil),
        .init(name: "红薯", category: .grain, kcal100g: 86, protein100g: 1.6, carbs100g: 20.0, fat100g: 0.1, defaultUnitGrams: 150),
        .init(name: "土豆", category: .grain, kcal100g: 81, protein100g: 2.0, carbs100g: 17.0, fat100g: 0.2, defaultUnitGrams: 150),
        .init(name: "玉米", category: .grain, kcal100g: 86, protein100g: 3.2, carbs100g: 19.0, fat100g: 1.2, defaultUnitGrams: 200),
        .init(name: "全麦面包", category: .grain, kcal100g: 247, protein100g: 13.0, carbs100g: 41.0, fat100g: 3.4, defaultUnitGrams: 30),

        // MARK: 蔬菜
        .init(name: "西红柿", category: .vegetable, kcal100g: 18, protein100g: 0.9, carbs100g: 3.9, fat100g: 0.2, defaultUnitGrams: 150),
        .init(name: "黄瓜", category: .vegetable, kcal100g: 16, protein100g: 0.8, carbs100g: 3.6, fat100g: 0.2, defaultUnitGrams: 200),
        .init(name: "生菜", category: .vegetable, kcal100g: 15, protein100g: 1.4, carbs100g: 2.9, fat100g: 0.2, defaultUnitGrams: nil),
        .init(name: "菠菜", category: .vegetable, kcal100g: 23, protein100g: 2.9, carbs100g: 3.6, fat100g: 0.4, defaultUnitGrams: nil),
        .init(name: "西兰花", category: .vegetable, kcal100g: 34, protein100g: 2.8, carbs100g: 7.0, fat100g: 0.4, defaultUnitGrams: nil),
        .init(name: "胡萝卜", category: .vegetable, kcal100g: 41, protein100g: 0.9, carbs100g: 9.6, fat100g: 0.2, defaultUnitGrams: 100),
        .init(name: "青椒", category: .vegetable, kcal100g: 20, protein100g: 0.9, carbs100g: 4.6, fat100g: 0.2, defaultUnitGrams: 60),
        .init(name: "洋葱", category: .vegetable, kcal100g: 40, protein100g: 1.1, carbs100g: 9.3, fat100g: 0.1, defaultUnitGrams: 150),
        .init(name: "白菜", category: .vegetable, kcal100g: 17, protein100g: 1.5, carbs100g: 3.2, fat100g: 0.2, defaultUnitGrams: nil),
        .init(name: "茄子", category: .vegetable, kcal100g: 25, protein100g: 1.0, carbs100g: 5.9, fat100g: 0.2, defaultUnitGrams: 250),
        .init(name: "冬瓜", category: .vegetable, kcal100g: 13, protein100g: 0.4, carbs100g: 2.6, fat100g: 0.2, defaultUnitGrams: nil),
        .init(name: "南瓜", category: .vegetable, kcal100g: 26, protein100g: 0.7, carbs100g: 5.3, fat100g: 0.1, defaultUnitGrams: nil),
        .init(name: "蘑菇", category: .vegetable, kcal100g: 22, protein100g: 3.1, carbs100g: 3.3, fat100g: 0.3, defaultUnitGrams: nil),
        .init(name: "芹菜", category: .vegetable, kcal100g: 14, protein100g: 0.7, carbs100g: 3.0, fat100g: 0.2, defaultUnitGrams: nil),
        .init(name: "青菜", category: .vegetable, kcal100g: 15, protein100g: 1.5, carbs100g: 2.7, fat100g: 0.3, defaultUnitGrams: nil),

        // MARK: 水果
        .init(name: "苹果", category: .fruit, kcal100g: 52, protein100g: 0.3, carbs100g: 14.0, fat100g: 0.2, defaultUnitGrams: 200),
        .init(name: "香蕉", category: .fruit, kcal100g: 89, protein100g: 1.1, carbs100g: 23.0, fat100g: 0.3, defaultUnitGrams: 120),
        .init(name: "橙子", category: .fruit, kcal100g: 47, protein100g: 0.9, carbs100g: 12.0, fat100g: 0.1, defaultUnitGrams: 180),
        .init(name: "葡萄", category: .fruit, kcal100g: 69, protein100g: 0.7, carbs100g: 18.0, fat100g: 0.2, defaultUnitGrams: 5),
        .init(name: "蓝莓", category: .fruit, kcal100g: 57, protein100g: 0.7, carbs100g: 14.0, fat100g: 0.3, defaultUnitGrams: nil),
        .init(name: "西瓜", category: .fruit, kcal100g: 30, protein100g: 0.6, carbs100g: 7.6, fat100g: 0.2, defaultUnitGrams: nil),
        .init(name: "草莓", category: .fruit, kcal100g: 32, protein100g: 0.7, carbs100g: 7.7, fat100g: 0.3, defaultUnitGrams: 15),
        .init(name: "猕猴桃", category: .fruit, kcal100g: 61, protein100g: 1.1, carbs100g: 15.0, fat100g: 0.5, defaultUnitGrams: 80),

        // MARK: 油脂调料
        .init(name: "花生油", category: .fat, kcal100g: 899, protein100g: 0, carbs100g: 0, fat100g: 99.9, defaultUnitGrams: nil),
        .init(name: "橄榄油", category: .fat, kcal100g: 884, protein100g: 0, carbs100g: 0, fat100g: 100.0, defaultUnitGrams: nil),
        .init(name: "芝麻油", category: .fat, kcal100g: 884, protein100g: 0, carbs100g: 0, fat100g: 100.0, defaultUnitGrams: nil),
        .init(name: "酱油", category: .seasoning, kcal100g: 63, protein100g: 5.6, carbs100g: 9.0, fat100g: 0.1, defaultUnitGrams: nil),
        .init(name: "白糖", category: .seasoning, kcal100g: 400, protein100g: 0, carbs100g: 100.0, fat100g: 0, defaultUnitGrams: nil),
        .init(name: "盐", category: .seasoning, kcal100g: 0, protein100g: 0, carbs100g: 0, fat100g: 0, defaultUnitGrams: nil),

        // MARK: 坚果其他
        .init(name: "花生", category: .nut, kcal100g: 567, protein100g: 26.0, carbs100g: 16.0, fat100g: 49.0, defaultUnitGrams: nil),
        .init(name: "杏仁", category: .nut, kcal100g: 579, protein100g: 21.0, carbs100g: 22.0, fat100g: 50.0, defaultUnitGrams: 1.2),
        .init(name: "核桃", category: .nut, kcal100g: 654, protein100g: 15.0, carbs100g: 14.0, fat100g: 65.0, defaultUnitGrams: 5),
        .init(name: "芝麻", category: .nut, kcal100g: 573, protein100g: 18.0, carbs100g: 23.0, fat100g: 50.0, defaultUnitGrams: nil),
        .init(name: "黑巧克力", category: .other, kcal100g: 546, protein100g: 4.9, carbs100g: 61.0, fat100g: 31.0, defaultUnitGrams: 10),
    ]
}
