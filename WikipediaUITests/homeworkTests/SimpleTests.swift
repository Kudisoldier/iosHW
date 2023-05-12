import XCTest


class SimpleTests: XCTestCase {
    var app: XCUIApplication!
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launchArguments = ["testing"]
        app.launch()

    }

    override func tearDown() {
        super.tearDown()
        XCUIApplication().terminate()

        let icon = springboard.icons["Википедия"]
        if icon.exists {
            let iconFrame = icon.frame
            let springboardFrame = springboard.frame
            icon.press(forDuration: 5)

            // Tap the little "X" button at approximately where it is. The X is not exposed directly
            springboard.coordinate(withNormalizedOffset: CGVector(dx: (iconFrame.minX + 3) / springboardFrame.maxX, dy: (iconFrame.minY + 3) / springboardFrame.maxY)).tap()

            springboard.alerts.buttons["Удалить приложение"].tap()
            springboard.alerts.buttons["Удалить"].tap()
        }
    }
    
    func testTopRead() {
        Page.on(OnboardingPage())
            .skipOnboarding()
            .on(MainPage())
            .clickTopRead()
            .on(TopReadArticlesPage())
            .assertTopArticlesOpened()
    }
    
    func testAboutApp() {
        Page.on(OnboardingPage())
            .skipOnboarding()
            .on(MainPage())
            .clickSettings()
            .on(SettingsPage())
            .clickAbout()
            .on(AboutPage())
            .assertAtuhorsTranslatorsAndLicenseExists()
    }
    
    func testSupport() {
        Page.on(OnboardingPage())
            .skipOnboarding()
            .on(MainPage())
            .clickSettings()
            .on(SettingsPage())
            .clickSupport()
            .assertBrowserOpened()
    }
    
}


