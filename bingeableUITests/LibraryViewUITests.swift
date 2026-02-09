import XCTest

final class LibraryViewUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLibraryHeaderStatsAndFiltersRender() throws {
        let app = launchAppAndContinueAsGuest(seedLibraryCount: 4)

        openLibraryTab(app)

        XCTAssertTrue(waitForLibraryHeader(app))
        XCTAssertTrue(anyElement(in: app, identifier: "library-total-count").exists)
        XCTAssertTrue(anyElement(in: app, identifier: "library-stat-ready").exists)
        XCTAssertTrue(anyElement(in: app, identifier: "library-stat-watching").exists)
        XCTAssertTrue(anyElement(in: app, identifier: "library-stat-waiting").exists)

        XCTAssertTrue(app.buttons["library-filter-all"].exists)
        XCTAssertTrue(app.buttons["library-filter-waiting"].exists)
        XCTAssertTrue(app.buttons["library-filter-watching"].exists)
        XCTAssertTrue(app.buttons["library-filter-finished"].exists)
    }

    @MainActor
    func testLibrarySearchNoMatchesState() throws {
        let app = launchAppAndContinueAsGuest(seedLibraryCount: 4)

        openLibraryTab(app)
        let searchField = app.searchFields["Search saved shows"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForCondition(timeout: 8) {
            !app.otherElements["library-empty-all"].exists
        })

        searchField.tap()
        searchField.typeText("zzzzzz_no_match")

        XCTAssertTrue(app.otherElements["library-empty-filtered"].waitForExistence(timeout: 5))

        let clearButton = searchField.buttons["Clear text"]
        if clearButton.exists {
            clearButton.tap()
        }

        XCTAssertTrue(waitForCondition(timeout: 5) {
            !app.otherElements["library-empty-filtered"].exists
        })
    }

    @MainActor
    func testLibrarySwipeMoveAndRemove() throws {
        let app = launchAppAndContinueAsGuest(seedLibraryCount: 4)

        openLibraryTab(app)
        XCTAssertTrue(waitForCondition(timeout: 10) {
            self.firstLibraryRow(in: app).exists || self.firstOverflowButton(in: app).exists
        })

        let showID: Int
        let chosenMove: (buttonTitle: String, filterIdentifier: String)

        if firstLibraryRow(in: app).exists {
            let row = firstLibraryRow(in: app)
            showID = extractShowID(fromRowIdentifier: row.identifier)

            row.swipeLeft()
            chosenMove = try XCTUnwrap(firstAvailableMoveCandidate(in: app))
            app.buttons[chosenMove.buttonTitle].tap()
        } else {
            let overflow = firstOverflowButton(in: app)
            showID = extractShowID(fromOverflowIdentifier: overflow.identifier)

            overflow.tap()
            chosenMove = try XCTUnwrap(firstAvailableMoveCandidate(in: app))
            app.buttons[chosenMove.buttonTitle].tap()
        }

        app.buttons[chosenMove.filterIdentifier].tap()

        XCTAssertTrue(waitForCondition(timeout: 6) {
            self.itemExists(showID: showID, in: app)
        })

        app.buttons["library-filter-all"].tap()

        if let rowForRemoval = rowForShow(showID: showID, in: app), rowForRemoval.exists {
            rowForRemoval.swipeLeft()
            let removeButton = app.buttons["Remove"]
            XCTAssertTrue(removeButton.waitForExistence(timeout: 4))
            removeButton.tap()
        } else {
            let overflowButton = anyElement(in: app, identifier: "library-overflow-\(showID)")
            XCTAssertTrue(overflowButton.waitForExistence(timeout: 6))
            overflowButton.tap()

            let removeFromLibrary = app.buttons["Remove from Library"]
            XCTAssertTrue(removeFromLibrary.waitForExistence(timeout: 4))
            removeFromLibrary.tap()
        }

        XCTAssertTrue(waitForCondition(timeout: 6) {
            !self.itemExists(showID: showID, in: app)
        })
    }

    @MainActor
    func testLibraryEmptyStateWhenNoSavedShows() throws {
        let app = launchAppAndContinueAsGuest()

        openLibraryTab(app)

        XCTAssertTrue(app.otherElements["library-empty-all"].waitForExistence(timeout: 8))
    }

    private func launchAppAndContinueAsGuest(seedLibraryCount: Int = 0) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DISCOVER_HERO_AUTOPLAY"] = "0"
        app.launchEnvironment["UI_TEST_RESET_LIBRARY"] = "1"
        app.launchEnvironment["UI_TEST_LIBRARY_SEED_COUNT"] = "\(seedLibraryCount)"
        app.launch()

        for _ in 0..<3 {
            let continueAsGuestButton = app.buttons["Continue as Guest"]
            if continueAsGuestButton.waitForExistence(timeout: 3) {
                continueAsGuestButton.tap()
            }

            if app.tabBars.buttons["Discover"].waitForExistence(timeout: 5) {
                break
            }
        }

        XCTAssertTrue(app.tabBars.buttons["Discover"].waitForExistence(timeout: 8))
        return app
    }

    private func openLibraryTab(_ app: XCUIApplication) {
        let libraryTab = app.tabBars.buttons["Library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 10))
        libraryTab.tap()
    }

    private func waitForLibraryHeader(_ app: XCUIApplication) -> Bool {
        if app.buttons["library-filter-all"].waitForExistence(timeout: 8) {
            return true
        }

        if anyElement(in: app, identifier: "library-header").exists {
            return true
        }

        if anyElement(in: app, identifier: "library-total-count").exists {
            return true
        }

        return app.staticTexts["Your Queue"].waitForExistence(timeout: 4)
    }

    private func anyElement(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func firstLibraryRow(in app: XCUIApplication) -> XCUIElement {
        let rowPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "library-row-")
        return app.descendants(matching: .any).matching(rowPredicate).firstMatch
    }

    private func firstOverflowButton(in app: XCUIApplication) -> XCUIElement {
        let overflowPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "library-overflow-")
        return app.descendants(matching: .any).matching(overflowPredicate).firstMatch
    }

    private func rowForShow(showID: Int, in app: XCUIApplication) -> XCUIElement? {
        let row = anyElement(in: app, identifier: "library-row-\(showID)")
        return row.exists ? row : nil
    }

    private func firstAvailableMoveCandidate(in app: XCUIApplication) -> (buttonTitle: String, filterIdentifier: String)? {
        let moveCandidates: [(buttonTitle: String, filterIdentifier: String)] = [
            ("Move to Watching", "library-filter-watching"),
            ("Move to Waiting", "library-filter-waiting"),
            ("Move to Finished", "library-filter-finished")
        ]

        return moveCandidates.first(where: { candidate in
            app.buttons[candidate.buttonTitle].waitForExistence(timeout: 1)
        })
    }

    private func itemExists(showID: Int, in app: XCUIApplication) -> Bool {
        anyElement(in: app, identifier: "library-feature-\(showID)").exists ||
        anyElement(in: app, identifier: "library-row-\(showID)").exists ||
        anyElement(in: app, identifier: "library-overflow-\(showID)").exists
    }

    private func extractShowID(fromRowIdentifier identifier: String) -> Int {
        let raw = identifier.replacingOccurrences(of: "library-row-", with: "")
        if let parsed = Int(raw) {
            return parsed
        }

        XCTFail("Unable to parse show ID from identifier: \(identifier)")
        return -1
    }

    private func extractShowID(fromOverflowIdentifier identifier: String) -> Int {
        let raw = identifier.replacingOccurrences(of: "library-overflow-", with: "")
        if let parsed = Int(raw) {
            return parsed
        }

        XCTFail("Unable to parse show ID from identifier: \(identifier)")
        return -1
    }

    private func waitForCondition(timeout: TimeInterval, pollInterval: TimeInterval = 0.2, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }

        return condition()
    }
}
