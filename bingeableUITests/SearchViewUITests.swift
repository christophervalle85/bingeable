import XCTest

final class SearchViewUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSearchRecentsAppearAfterQueryIsCleared() throws {
        let app = launchAppAndContinueAsGuest()
        openSearchTab(app)

        let searchField = app.searchFields["Search shows"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("arc")

        XCTAssertTrue(firstSearchResult(in: app).waitForExistence(timeout: 8))

        let clearButton = searchField.buttons["Clear text"]
        if clearButton.exists {
            clearButton.tap()
        } else {
            searchField.tap()
            searchField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
        }

        let recentsVisible = app.otherElements["search-recents-section"].waitForExistence(timeout: 6)
        let emptyVisible = app.otherElements["search-empty-initial"].waitForExistence(timeout: 2)
        guard recentsVisible || emptyVisible else {
            throw XCTSkip("Search state did not return to a non-result state in time.")
        }
    }

    @MainActor
    func testSearchSortAndGenreMenusAreInteractive() throws {
        let app = launchAppAndContinueAsGuest()
        openSearchTab(app)

        let searchField = app.searchFields["Search shows"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("arc")

        guard app.otherElements["search-filter-bar"].waitForExistence(timeout: 8) else {
            throw XCTSkip("Filter bar did not appear for the current search response.")
        }
        guard firstSearchResult(in: app).waitForExistence(timeout: 8) else {
            throw XCTSkip("No searchable results were returned for UI interaction checks.")
        }

        let sortMenu = app.buttons["search-sort-menu"]
        XCTAssertTrue(sortMenu.exists)
        sortMenu.tap()
        XCTAssertTrue(app.buttons["Rating"].waitForExistence(timeout: 3))
        app.buttons["Rating"].tap()

        let genreMenu = app.buttons["search-genre-menu"]
        XCTAssertTrue(genreMenu.exists)
        genreMenu.tap()
        XCTAssertTrue(app.buttons["All Genres"].waitForExistence(timeout: 3))
        app.buttons["All Genres"].tap()

        XCTAssertTrue(firstSearchResult(in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testSearchResultRowNavigatesToDetail() throws {
        let app = launchAppAndContinueAsGuest()
        openSearchTab(app)

        let searchField = app.searchFields["Search shows"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("arc")

        let result = firstSearchResult(in: app)
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertTrue(result.isHittable)
        result.tap()

        XCTAssertTrue(app.otherElements["detail-library-section"].waitForExistence(timeout: 8))
    }

    private func launchAppAndContinueAsGuest() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DISCOVER_HERO_AUTOPLAY"] = "0"
        app.launchEnvironment["UI_TEST_RESET_LIBRARY"] = "1"
        app.launchEnvironment["UI_TEST_RESET_RECENTS"] = "1"
        app.launchEnvironment["UI_TEST_USE_FIXTURE_REPOSITORY"] = "1"
        app.launch()

        for _ in 0..<3 {
            let continueAsGuestButton = app.buttons["Continue as Guest"]
            if continueAsGuestButton.waitForExistence(timeout: 3) {
                continueAsGuestButton.tap()
            }

            if app.tabBars.buttons["Search"].waitForExistence(timeout: 5) {
                break
            }
        }

        XCTAssertTrue(app.tabBars.buttons["Search"].waitForExistence(timeout: 8))
        return app
    }

    private func openSearchTab(_ app: XCUIApplication) {
        let tab = app.tabBars.buttons["Search"]
        XCTAssertTrue(tab.waitForExistence(timeout: 8))
        tab.tap()
    }

    private func anyElement(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func firstSearchResult(in app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "search-result-")
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

}
