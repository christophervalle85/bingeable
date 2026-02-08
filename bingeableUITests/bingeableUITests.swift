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
        let app = XCUIApplication()
        app.launch()
        continueAsGuestIfNeeded(app)

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
