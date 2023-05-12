import Foundation
import XCTest
import SafariServices

class SettingsPage: Page {
    override func verify() {
        app.staticTexts["Войти"].waitForExistence(timeout: 5)
    }
    
    func clickAbout() -> SettingsPage {
        let about = app.staticTexts["О приложении"]
        scrollTo(about)
        about.tap()
        return self
    }
    
    func clickSupport() -> SettingsPage {
        let supportButton = app.staticTexts["Поддержать Википедию"]
        supportButton.tap()
        return self
    }
    
    func assertBrowserOpened() -> SettingsPage {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.wait(for: .runningForeground, timeout: 5)

        XCTAssert((safari.textFields["Адрес"].value  as! String).contains("donate.wikimedia"))

        app.activate()
        
        return self
    }

}

