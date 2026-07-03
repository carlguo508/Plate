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
    }

    /// Walks every tab and the core "add food" flow so a broken screen fails fast.
    @MainActor
    func testTabsAndCoreScreensSmoke() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        // 今天
        XCTAssertTrue(app.staticTexts["今日热量"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["今日训练"].exists)
        XCTAssertTrue(app.staticTexts["体重"].exists)

        // 菜谱
        tabBar.buttons["菜谱"].tap()
        XCTAssertTrue(app.navigationBars["菜谱"].waitForExistence(timeout: 5))

        // 饮食 → 加食物 → 食材列表（内置食材应已种子化）
        tabBar.buttons["饮食"].tap()
        XCTAssertTrue(app.navigationBars["饮食"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label == %@", "加食物")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["加食物"].waitForExistence(timeout: 5))
        app.buttons["食材"].tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5), "内置食材列表不应为空")
        app.buttons["取消"].tap()

        // 训练（本周计划应自动生成 7 天）
        tabBar.buttons["训练"].tap()
        XCTAssertTrue(app.navigationBars["训练"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["周一"].waitForExistence(timeout: 5))

        // 回顾
        tabBar.buttons["回顾"].tap()
        XCTAssertTrue(app.navigationBars["回顾"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["热量摄入"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
