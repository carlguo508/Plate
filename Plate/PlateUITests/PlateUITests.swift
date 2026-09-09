//
//  PlateUITests.swift
//  PlateUITests
//
//  Created by Chenhao Guo on 5/27/26.
//

import XCTest

final class PlateUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<6 {
            if element.exists && element.isHittable {
                return true
            }
            app.swipeUp()
        }
        return element.waitForExistence(timeout: 2) && element.isHittable
    }

    /// Walks every MVP tab and the core food/training flows so a broken screen fails fast.
    @MainActor
    func testTabsAndCoreScreensSmoke() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        // 今天
        let todayTab = tabBar.buttons["今天"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()
        XCTAssertTrue(app.navigationBars["今天"].waitForExistence(timeout: 5))
        app.buttons["记录今日体重"].tap()
        XCTAssertTrue(app.navigationBars["记录体重"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["body-weight-kg"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["kg"].exists)
        app.buttons["取消"].tap()
        XCTAssertTrue(app.navigationBars["记录体重"].waitForNonExistence(timeout: 5))
        let logMealButton = app.buttons["记一餐"]
        XCTAssertTrue(reveal(logMealButton, in: app))
        logMealButton.tap()
        let breakfastButton = app.buttons["早餐"]
        XCTAssertTrue(breakfastButton.waitForExistence(timeout: 10))
        breakfastButton.tap()
        XCTAssertTrue(app.navigationBars["加食物"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["quick-meal-name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["quick-meal-calories"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["AI 估算"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()
        XCTAssertTrue(app.navigationBars["加食物"].waitForNonExistence(timeout: 5))

        // 饮食保留为按日期统一补录和修改的入口
        tabBar.buttons["饮食"].tap()
        XCTAssertTrue(app.navigationBars["饮食"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["常用餐"].waitForExistence(timeout: 5))

        // 训练直接进入记录，不再先生成周计划
        tabBar.buttons["训练"].tap()
        XCTAssertTrue(app.navigationBars["训练"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["training-weight-unit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["training-weight-unit"].buttons["lb"].isSelected)
        let strengthButton = app.buttons["start-routine-push"]
        XCTAssertTrue(strengthButton.waitForExistence(timeout: 5))
        strengthButton.tap()
        XCTAssertTrue(app.navigationBars["力量记录"].waitForExistence(timeout: 5))
        XCTAssertTrue(reveal(app.staticTexts["卧推"], in: app))
        app.buttons["完成"].tap()

        // 趋势
        tabBar.buttons["趋势"].tap()
        XCTAssertTrue(app.navigationBars["趋势"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["热量摄入"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSavedStrengthSetRemainsVisibleAfterReopening() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        let trainingTab = app.tabBars.buttons["训练"]
        XCTAssertTrue(trainingTab.waitForExistence(timeout: 5))
        trainingTab.tap()
        if !app.navigationBars["训练"].waitForExistence(timeout: 3) {
            trainingTab.tap()
        }
        XCTAssertTrue(app.navigationBars["训练"].waitForExistence(timeout: 5))
        let strengthButton = app.buttons["start-custom-strength"]
        XCTAssertTrue(strengthButton.waitForExistence(timeout: 10))
        strengthButton.tap()
        XCTAssertTrue(app.navigationBars["力量记录"].waitForExistence(timeout: 5))

        let exerciseName = "回显测试动作"
        let exerciseField = app.textFields["new-set-exercise"]
        XCTAssertTrue(exerciseField.waitForExistence(timeout: 5))
        exerciseField.tap()
        exerciseField.typeText(exerciseName)

        let weightField = app.textFields["new-set-weight"]
        weightField.tap()
        weightField.typeText("60")
        let repsField = app.textFields["new-set-reps"]
        repsField.tap()
        repsField.typeText("8")
        app.buttons["add-set"].tap()

        XCTAssertTrue(app.staticTexts[exerciseName].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()
        XCTAssertTrue(app.navigationBars["力量记录"].waitForNonExistence(timeout: 5))
        trainingTab.tap()
        if !app.navigationBars["训练"].waitForExistence(timeout: 3) {
            trainingTab.tap()
        }
        XCTAssertTrue(app.navigationBars["训练"].waitForExistence(timeout: 5))
        let reopenButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "力量训练")
        ).firstMatch
        XCTAssertTrue(reopenButton.waitForExistence(timeout: 5))
        reopenButton.tap()
        XCTAssertTrue(app.staticTexts[exerciseName].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields.matching(NSPredicate(
            format: "identifier == %@ AND value == %@", "saved-set-weight", "60"
        )).firstMatch.exists)
        XCTAssertTrue(app.textFields.matching(NSPredicate(
            format: "identifier == %@ AND value == %@", "saved-set-reps", "8"
        )).firstMatch.exists)

        app.buttons["save-workout-template"].tap()
        let templateName = "胸模板测试"
        let templateAlert = app.alerts["保存训练模板"]
        XCTAssertTrue(templateAlert.waitForExistence(timeout: 5))
        let templateField = templateAlert.textFields.firstMatch
        XCTAssertTrue(templateField.waitForExistence(timeout: 5))
        templateField.tap()
        templateField.typeText(templateName)
        templateAlert.buttons["保存"].tap()

        let deleteButtons = app.buttons.matching(identifier: "delete-saved-set")
        for _ in 0..<20 where deleteButtons.firstMatch.waitForExistence(timeout: 1) {
            deleteButtons.firstMatch.tap()
        }
        XCTAssertFalse(deleteButtons.firstMatch.exists)
        let templateButton = app.buttons["workout-template-\(templateName)"]
        XCTAssertTrue(templateButton.waitForExistence(timeout: 5))
        templateButton.tap()
        XCTAssertTrue(app.staticTexts[exerciseName].waitForExistence(timeout: 5))
    }

    @MainActor
    func testQuickMealCanBeLoggedWithCaloriesOnly() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        let todayTab = app.tabBars.buttons["今天"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()
        app.buttons["记一餐"].tap()
        app.buttons["加餐"].tap()
        XCTAssertTrue(app.navigationBars["加食物"].waitForExistence(timeout: 5))

        let mealName = "Chipotle UI 测试"
        let nameField = app.textFields["quick-meal-name"]
        nameField.tap()
        nameField.typeText(mealName)
        let calorieField = app.textFields["quick-meal-calories"]
        calorieField.tap()
        calorieField.typeText("720")
        app.swipeUp()

        let saveButton = app.buttons["save-quick-meal"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()
        XCTAssertTrue(app.navigationBars["加食物"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", mealName)
        ).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testIngredientCanBeAddedAndRemovedFromPicker() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        XCTAssertTrue(app.buttons["记一餐"].waitForExistence(timeout: 10))
        app.buttons["记一餐"].tap()
        XCTAssertTrue(app.buttons["早餐"].waitForExistence(timeout: 5))
        app.buttons["早餐"].tap()
        XCTAssertTrue(app.navigationBars["加食物"].waitForExistence(timeout: 5))
        app.buttons["食材"].tap()

        let addButton = app.buttons["add-ingredient"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        XCTAssertTrue(app.navigationBars["新增食材"].waitForExistence(timeout: 5))

        let name = "牛腱肉 UI \(UUID().uuidString.prefix(6))"
        let nameField = app.textFields["ingredient-name"]
        nameField.tap()
        nameField.typeText(name)
        let caloriesField = app.textFields["ingredient-calories"]
        caloriesField.tap()
        caloriesField.typeText("180")
        app.buttons["save-ingredient"].tap()

        XCTAssertTrue(app.navigationBars["数量"].waitForExistence(timeout: 5))
        app.navigationBars["数量"].buttons["取消"].tap()
        XCTAssertTrue(app.navigationBars["数量"].waitForNonExistence(timeout: 5))
        let searchField = app.searchFields["搜索食材"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText(name)
        let ingredient = app.staticTexts[name]
        XCTAssertTrue(ingredient.waitForExistence(timeout: 5))
        ingredient.swipeLeft()
        let deleteButton = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Delete", "删除"])
        ).firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()
        XCTAssertTrue(ingredient.waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing-reset"]
            app.launch()
        }
    }
}
