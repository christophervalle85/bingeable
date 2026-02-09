//
//  bingeableUITests.swift
//  bingeableUITests
//
//  Created by cvalle on 2/8/26.
//

import XCTest

final class bingeableUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = launchDiscoverApp()

        let heroCard = app.buttons["discover-hero-card"]
        XCTAssertTrue(heroCard.waitForExistence(timeout: 10))

        XCTAssertTrue(app.otherElements["discover-section-trending"].exists)
        XCTAssertTrue(app.otherElements["discover-section-popular"].exists)

        let savePredicate = NSPredicate(format: "identifier BEGINSWITH %@", "discover-save-")
        let saveButton = app.buttons.matching(savePredicate).firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 10))
        saveButton.tap()

        let cardPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "discover-card-")
        let card = app.buttons.matching(cardPredicate).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()

        XCTAssertTrue(app.otherElements["detail-library-section"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.otherElements["detail-providers-section"].exists)
    }

    @MainActor
    func testDiscoverVerticalScrollFromHeroDoesNotLock() throws {
        let app = launchDiscoverApp()

        let heroCarousel = app.otherElements["discover-hero-carousel"]
        XCTAssertTrue(heroCarousel.waitForExistence(timeout: 10))

        let initialHeroY = heroCarousel.frame.minY

        for _ in 0..<4 {
            dragUp(on: heroCarousel, distance: 240)
        }

        XCTAssertLessThan(heroCarousel.frame.minY, initialHeroY - 80)
        XCTAssertTrue(app.otherElements["discover-section-soon"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDiscoverVerticalScrollFromRailDoesNotLock() throws {
        let app = launchDiscoverApp()

        let heroCarousel = app.otherElements["discover-hero-carousel"]
        XCTAssertTrue(heroCarousel.waitForExistence(timeout: 10))
        let trendingRail = app.otherElements["discover-rail-trending"]
        XCTAssertTrue(trendingRail.waitForExistence(timeout: 10))

        let initialHeroY = heroCarousel.frame.minY

        for _ in 0..<4 {
            dragUp(on: trendingRail, distance: 240)
        }

        XCTAssertLessThan(heroCarousel.frame.minY, initialHeroY - 80)
        XCTAssertTrue(app.otherElements["discover-section-soon"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDiscoverHorizontalRailStillScrollable() throws {
        let app = launchDiscoverApp()

        let trendingRail = app.otherElements["discover-rail-trending"]
        XCTAssertTrue(trendingRail.waitForExistence(timeout: 10))

        let cardPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "discover-card-")
        let firstCard = app.buttons.matching(cardPredicate).firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10))

        let initialX = firstCard.frame.minX
        dragLeft(on: trendingRail, distance: 200)
        XCTAssertLessThan(firstCard.frame.minX, initialX - 20)
    }

    private func launchDiscoverApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DISCOVER_HERO_AUTOPLAY"] = "0"
        app.launch()
        continueAsGuestIfNeeded(app)
        return app
    }

    private func dragUp(on element: XCUIElement, distance: CGFloat) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        let end = start.withOffset(CGVector(dx: 0, dy: -distance))
        start.press(forDuration: 0.02, thenDragTo: end)
    }

    private func dragLeft(on element: XCUIElement, distance: CGFloat) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        let end = start.withOffset(CGVector(dx: -distance, dy: 0))
        start.press(forDuration: 0.02, thenDragTo: end)
    }

    private func continueAsGuestIfNeeded(_ app: XCUIApplication) {
        let continueAsGuestButton = app.buttons["Continue as Guest"]
        if continueAsGuestButton.waitForExistence(timeout: 3) {
            continueAsGuestButton.tap()
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
