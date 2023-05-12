import Foundation

class MainPage: Page {
    
    override func verify() {
        app.buttons["Все самые читаемые статьи"].waitForExistence(timeout: 5)
    }
    
    func clickTopRead() -> MainPage {
        let topReadArticles = app.buttons["Все самые читаемые статьи"]
        topReadArticles.tap()
        return self
    }
    
    func clickSettings() -> MainPage {
        let topReadArticles = app.buttons["Настройки"]
        topReadArticles.tap()
        return self
    }
}
