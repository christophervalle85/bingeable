import XCTest

final class SettingsViewUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testProfileHeaderRenders() throws {
        let app = launchAppAndContinueAsGuest(resetProfile: true)
        openProfileTab(app)

        XCTAssertTrue(app.otherElements["profile-header-card"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["profile-edit-button"].exists)
        XCTAssertTrue(app.buttons["profile-open-settings"].exists)
    }

    @MainActor
    func testDisplayNamePersistsAcrossRelaunch() throws {
        let app = launchAppAndContinueAsGuest(resetProfile: true)
        openProfileTab(app)
        app.buttons["profile-edit-button"].tap()

        let nameField = app.textFields["profile-display-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 8))
        replaceText(in: nameField, with: "Movie Buff")

        let saveButton = app.buttons["profile-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 4))
        saveButton.tap()

        app.terminate()

        let relaunched = launchAppAndContinueAsGuest(resetProfile: false)
        openProfileTab(relaunched)
        relaunched.buttons["profile-edit-button"].tap()

        let reloadedNameField = relaunched.textFields["profile-display-name-field"]
        XCTAssertTrue(reloadedNameField.waitForExistence(timeout: 8))
        XCTAssertEqual(reloadedNameField.value as? String, "Movie Buff")
    }

    @MainActor
    func testProviderSelectionPersistsAcrossRelaunch() throws {
        let app = launchAppAndContinueAsGuest(resetProfile: true)
        openProfileTab(app)
        app.buttons["profile-edit-button"].tap()

        let netflixButton = app.buttons["profile-provider-8"]
        XCTAssertTrue(netflixButton.waitForExistence(timeout: 8))
        netflixButton.tap()

        app.buttons["profile-save-button"].tap()

        app.terminate()

        let relaunched = launchAppAndContinueAsGuest(resetProfile: false)
        openProfileTab(relaunched)
        relaunched.buttons["profile-edit-button"].tap()

        let reloadedNetflix = relaunched.buttons["profile-provider-8"]
        XCTAssertTrue(reloadedNetflix.waitForExistence(timeout: 8))
        XCTAssertEqual(reloadedNetflix.value as? String, "selected")
    }

    @MainActor
    func testClearCacheAndSignOutFlow() throws {
        let app = launchAppAndContinueAsGuest(resetProfile: true)
        openProfileTab(app)
        app.buttons["profile-open-settings"].tap()

        let clearButton = app.buttons["profile-cache-clear"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 8))
        clearButton.tap()

        XCTAssertTrue(app.staticTexts["Cache cleared"].waitForExistence(timeout: 8))

        let signOutButton = app.buttons["profile-sign-out"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 8))
        signOutButton.tap()

        XCTAssertTrue(app.buttons["Continue as Guest"].waitForExistence(timeout: 8))
    }

    private func launchAppAndContinueAsGuest(resetProfile: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DISCOVER_HERO_AUTOPLAY"] = "0"
        app.launchEnvironment["UI_TEST_RESET_LIBRARY"] = "1"
        app.launchEnvironment["UI_TEST_RESET_PROFILE"] = resetProfile ? "1" : "0"
        app.launch()

        for _ in 0..<3 {
            let continueAsGuestButton = app.buttons["Continue as Guest"]
            if continueAsGuestButton.waitForExistence(timeout: 2) {
                continueAsGuestButton.tap()
            }

            if app.tabBars.buttons["Discover"].waitForExistence(timeout: 4) {
                break
            }
        }

        XCTAssertTrue(app.tabBars.buttons["Discover"].waitForExistence(timeout: 8))
        return app
    }

    private func openProfileTab(_ app: XCUIApplication) {
        let tab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 8))
        tab.tap()
    }

    private func replaceText(in element: XCUIElement, with text: String) {
        element.tap()

        if let existing = element.value as? String, !existing.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count)
            element.typeText(deleteString)
        }

        element.typeText(text)
    }
}
