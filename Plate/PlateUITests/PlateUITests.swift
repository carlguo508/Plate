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

    /// Walks every MVP tab and the core food/training flows so a broken screen fails fast.
    @MainActor
    func testTabsAndCoreScreensSmoke() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        // 今天
        XCTAssertTrue(app.staticTexts["饮食"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["训练"].exists)
        XCTAssertTrue(app.staticTexts["体重"].exists)
        app.buttons["记一餐"].tap()
        app.buttons["早餐"].tap()
        XCTAssertTrue(app.navigationBars["加食物"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["AI 估算"].exists)
        app.buttons["取消"].tap()

        // 饮食保留为按日期统一补录和修改的入口
        tabBar.buttons["饮食"].tap()
        XCTAssertTrue(app.navigationBars["饮食"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["常用餐"].exists)

        // 训练直接进入记录，不再先生成周计划
        tabBar.buttons["训练"].tap()
        XCTAssertTrue(app.navigationBars["训练"].waitForExistence(timeout: 5))
        let strengthButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "力量训练")
        ).firstMatch
        XCTAssertTrue(strengthButton.waitForExistence(timeout: 5))
        strengthButton.tap()
        XCTAssertTrue(app.navigationBars["力量记录"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()

        // 趋势
        tabBar.buttons["趋势"].tap()
        XCTAssertTrue(app.navigationBars["趋势"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["热量摄入"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
