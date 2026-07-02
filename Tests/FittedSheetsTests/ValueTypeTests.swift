#if os(iOS)
import XCTest
import UIKit
@testable import FittedSheets

final class SheetSizeTests: XCTestCase {

    func testEquatable() {
        XCTAssertEqual(SheetSize.intrinsic, SheetSize.intrinsic)
        XCTAssertEqual(SheetSize.fullscreen, SheetSize.fullscreen)
        XCTAssertEqual(SheetSize.percent(0.5), SheetSize.percent(0.5))
        XCTAssertEqual(SheetSize.fixed(100), SheetSize.fixed(100))
        XCTAssertNotEqual(SheetSize.fixed(100), SheetSize.fixed(200))
        XCTAssertNotEqual(SheetSize.percent(0.5), SheetSize.fullscreen)
    }

    // #43 — percent takes CGFloat (compiles with a CGFloat value, not just a literal).
    func testPercentIsCGFloat() {
        let value: CGFloat = 0.42
        XCTAssertEqual(SheetSize.percent(value), SheetSize.percent(0.42))
    }

    // Sendable conformance (compile-time check).
    func testSendable() {
        func requireSendable<T: Sendable>(_ v: T) {}
        requireSendable(SheetSize.fixed(1))
    }
}

@MainActor
final class UIColorExtensionTests: XCTestCase {

    private func resolve(_ color: UIColor, _ style: UIUserInterfaceStyle) -> UIColor {
        color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }

    // #49 — init(light:dark:) must map dark trait -> dark color, light -> light (previously swapped).
    func testLightDarkNotSwapped() {
        let color = UIColor(light: .white, dark: .black)
        XCTAssertEqual(resolve(color, .dark), UIColor.black.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)))
        XCTAssertEqual(resolve(color, .light), UIColor.white.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)))
    }

    // init(white:alpha:black:darkAlpha:) resolves white in light and `black` in dark.
    func testWhiteBlackInit() {
        let color = UIColor(white: 0.9, black: 0.1)
        var lightWhite: CGFloat = 0, darkWhite: CGFloat = 0, a: CGFloat = 0
        resolve(color, .light).getWhite(&lightWhite, alpha: &a)
        resolve(color, .dark).getWhite(&darkWhite, alpha: &a)
        XCTAssertEqual(lightWhite, 0.9, accuracy: 0.001)
        XCTAssertEqual(darkWhite, 0.1, accuracy: 0.001)
    }
}
#endif
