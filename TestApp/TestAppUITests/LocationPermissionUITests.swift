import CoreLocation
import XCTest

/// Runs LocationProvider against real Core Location in the simulator, from the permission prompt onward.
final class LocationPermissionUITests: XCTestCase {
    private let statueOfLiberty = CLLocation(latitude: 40.689247, longitude: -74.044502)
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.location = XCUILocation(location: statueOfLiberty)
        app = XCUIApplication()
        // Forces the system permission prompt on the next request
        app.resetAuthorizationStatus(for: .location)
        app.launch()
    }

    @MainActor
    func testAllowingPermissionShowsSimulatedLocation() throws {
        try requestLocation(answeringPromptWith: .allowWhileUsingApp)

        let latitude = app.staticTexts["locationLatitude"]
        XCTAssertTrue(latitude.waitForExistence(timeout: 20), "No location shown after allowing permission")
        XCTAssertEqual(latitude.label, "40.689247")
        XCTAssertEqual(app.staticTexts["locationLongitude"].label, "-74.044502")
    }

    @MainActor
    func testDenyingPermissionShowsAuthorizationError() throws {
        try requestLocation(answeringPromptWith: .dontAllow)

        let errorMessage = app.staticTexts["locationErrorMessage"]
        XCTAssertTrue(errorMessage.waitForExistence(timeout: 20), "No error shown after denying permission")
        XCTAssertTrue(
            errorMessage.label.hasPrefix("Location access is not available"),
            "Expected the authorizationDenied message, got: \(errorMessage.label)")
        // Denial is fixed in Settings, so retrying is not offered
        XCTAssertTrue(app.buttons["openLocationSettingsButton"].exists, "No Open Location Settings button")
        XCTAssertFalse(app.buttons["tryAgainButton"].exists, "Try Again offered for a Settings error")
    }

    /// The location prompt's buttons, by position. SpringBoard gives them no identifiers and labels them in the
    /// simulator's language, so position is the only language-independent handle.
    private enum PromptAnswer: Int {
        case allowOnce = 0
        case allowWhileUsingApp = 1
        case dontAllow = 2
    }

    /// Taps Get Location, then answers the system prompt.
    @MainActor
    private func requestLocation(answeringPromptWith answer: PromptAnswer) throws {
        let getLocationButton = app.buttons["getLocationButton"]
        XCTAssertTrue(getLocationButton.waitForExistence(timeout: 5), "No Get Location button")
        getLocationButton.tap()

        let prompt = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: 10), "No location permission prompt")
        let promptButtons = prompt.buttons.allElementsBoundByIndex
        XCTAssertEqual(
            promptButtons.count,
            3,
            "Expected Allow Once, Allow While Using App, Don't Allow; got \(promptButtons.map(\.label))")
        promptButtons[answer.rawValue].tap()
    }
}
