import Foundation
import XCTest

open class Page {
    public let app = XCUIApplication()
    private let maxSwipes = 20
    
    open func verify() {
        fatalError("Not implemented")
    }
    
    func on<T>(_ pageObject: T) -> T where T : Page {
        pageObject.verify()
        return pageObject
    }
    
    static func on<T>(_ pageObject: T) -> T where T : Page {
        pageObject.verify()
        return pageObject
    }
    
    func scrollTo(_ element: XCUIElement) {
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
    }
}
