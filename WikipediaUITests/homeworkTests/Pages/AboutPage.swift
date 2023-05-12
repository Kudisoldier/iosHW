import Foundation
import XCTest

class AboutPage: Page {

    override func verify() {
        app.staticTexts["О приложении"].waitForExistence(timeout: 5)
    }
    
    func assertTextExists(_ element: XCUIElement) {
        scrollTo(element)
        XCTAssert(element.isHittable)
    }
    
    func assertAtuhorsTranslatorsAndLicenseExists() -> AboutPage {        
        let authors = app.staticTexts["Авторы"]
        let translators = app.staticTexts["Переводчики"]
        let license = app.staticTexts["Лицензия содержимого"]
        
        assertTextExists(authors)
        assertTextExists(translators)
        assertTextExists(license)

        return self
    }
}

