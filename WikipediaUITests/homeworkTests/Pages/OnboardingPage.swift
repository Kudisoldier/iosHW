import Foundation
import XCTest

class OnboardingPage: Page {
    
    override func verify() {
        app.buttons["Пропустить"].waitForExistence(timeout: 5)
    }
    
    func skipOnboarding() -> OnboardingPage {
        let skipButton = app.buttons["Пропустить"]
        skipButton.tap()
        return self
    }
}
