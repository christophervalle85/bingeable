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
        openEditSection(app)

        let nameField = app.textFields["profile-display-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 8))
        replaceText(in: nameField, with: "Movie Buff")

        let saveButton = app.buttons["profile-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 4))
        saveButton.tap()

        app.terminate()

        let relaunched = launchAppAndContinueAsGuest(resetProfile: false)
        openProfileTab(relaunched)
        openEditSection(relaunched)

        let reloadedNameField = relaunched.textFields["profile-display-name-field"]
        XCTAssertTrue(reloadedNameField.waitForExistence(timeout: 8))
        XCTAssertEqual(reloadedNameField.value as? String, "Movie Buff")
    }

    @MainActor
    func testProviderSelectionPersistsAcrossRelaunch() throws {
        let app = launchAppAndContinueAsGuest(resetProfile: true)
        openProfileTab(app)
        openSubscriptionsSection(app)

        let netflixButton = app.buttons["profile-provider-8"]
        XCTAssertTrue(netflixButton.waitForExistence(timeout: 8))
        netflixButton.tap()

        let saveButton = app.buttons["profile-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 4))
        saveButton.tap()

        app.terminate()

        let relaunched = launchAppAndContinueAsGuest(resetProfile: false)
        openProfileTab(relaunched)
        openSubscriptionsSection(relaunched)

        let reloadedNetflix = relaunched.buttons["profile-provider-8"]
        XCTAssertTrue(reloadedNetflix.waitForExistence(timeout: 8))
        XCTAssertEqual(reloadedNetflix.value as? String, "selected")
    }

    @MainActor
    func testClearCacheAndSignOutFlow() throws {
        let app = launchAppAndContinueAsGuest(resetProfile: true)
        openProfileTab(app)
        openAppSettingsSection(app)

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

    private func tapElement(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 8))

        if element.isHittable {
            element.tap()
            return
        }

        for _ in 0..<5 {
            app.swipeUp()
            if element.isHittable {
                element.tap()
                return
            }
        }

        for _ in 0..<5 {
            app.swipeDown()
            if element.isHittable {
                element.tap()
                return
            }
        }

        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func goToProfileHome(_ app: XCUIApplication) {
        if app.buttons["profile-back-button"].exists {
            tapElement(app.buttons["profile-back-button"], in: app)
        }

        XCTAssertTrue(app.otherElements["profile-header-card"].waitForExistence(timeout: 8))
    }

    private func openSection(
        using buttonID: String,
        destination: XCUIElement,
        in app: XCUIApplication
    ) {
        let button = app.buttons[buttonID]

        for _ in 0..<2 {
            tapElement(button, in: app)
            if destination.waitForExistence(timeout: 3) {
                return
            }
        }

        XCTAssertTrue(destination.waitForExistence(timeout: 8))
    }

    private func openEditSection(_ app: XCUIApplication) {
        goToProfileHome(app)
        openSection(
            using: "profile-edit-button",
            destination: app.otherElements["profile-edit-section"],
            in: app
        )
    }

    private func openSubscriptionsSection(_ app: XCUIApplication) {
        goToProfileHome(app)
        openSection(
            using: "profile-manage-services",
            destination: app.otherElements["profile-subscriptions-section"],
            in: app
        )
    }

    private func openAppSettingsSection(_ app: XCUIApplication) {
        goToProfileHome(app)
        openSection(
            using: "profile-open-settings",
            destination: app.otherElements["profile-app-settings-section"],
            in: app
        )
    }
}
