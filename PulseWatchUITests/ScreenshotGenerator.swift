import XCTest

/// App Store 截图自动生成器
/// 通过 UI Test 自动导航关键页面并截图
final class ScreenshotGenerator: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true

        app = XCUIApplication()
        // 启用演示模式 + 跳过 Onboarding
        app.launchArguments += [
            "-pulse.demo.enabled", "YES",
            "-pulse.onboarding.completed", "YES"
        ]
        app.launch()

        // 等待 app 加载完成
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should appear")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Screenshots

    /// 1. Dashboard — 评分大圆环 + 指标网格
    func test_01_Dashboard() throws {
        // 确保在 Today tab
        let todayTab = app.tabBars.buttons["Today"]
        if todayTab.exists {
            todayTab.tap()
        }
        sleep(3) // 等待动画和数据加载

        takeScreenshot(name: "01_Dashboard")
    }

    /// 2. Dashboard 下滑 — 趋势图区域
    func test_02_DashboardTrends() throws {
        let todayTab = app.tabBars.buttons["Today"]
        if todayTab.exists {
            todayTab.tap()
        }
        sleep(2)

        // 向下滑动到趋势图区域
        app.swipeUp()
        sleep(1)
        app.swipeUp()
        sleep(1)

        takeScreenshot(name: "02_Dashboard_Trends")
    }

    /// 3. Exercise tab — 训练记录
    func test_03_Exercise() throws {
        let exerciseTab = app.tabBars.buttons["Exercise"]
        if exerciseTab.exists {
            exerciseTab.tap()
        }
        sleep(3)

        takeScreenshot(name: "03_Exercise")
    }

    /// 4. Trends tab — 历史趋势图
    func test_04_Trends() throws {
        let trendsTab = app.tabBars.buttons["Trends"]
        if trendsTab.exists {
            trendsTab.tap()
        }
        sleep(3)

        takeScreenshot(name: "04_Trends")
    }

    /// 5. Trends 下滑 — 周报对比区域
    func test_05_TrendsDetail() throws {
        let trendsTab = app.tabBars.buttons["Trends"]
        if trendsTab.exists {
            trendsTab.tap()
        }
        sleep(2)

        // 向下滑动查看更多趋势数据
        app.swipeUp()
        sleep(1)

        takeScreenshot(name: "05_Trends_Detail")
    }

    /// 6. Settings — 设置页面
    func test_06_Settings() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
        }
        sleep(2)

        takeScreenshot(name: "06_Settings")
    }

    // MARK: - Helper

    private func takeScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
