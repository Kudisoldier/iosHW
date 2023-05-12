import Foundation
import XCTest

class TopReadArticlesPage: Page {
    
    override func verify() {
        app.buttons["Назад к вкладке Обзор"].waitForExistence(timeout: 5)
    }
    
    func assertTopArticlesOpened() -> TopReadArticlesPage {
        XCTAssert(app.staticTexts["Самые читаемые"].exists)
        return self
    }
}

