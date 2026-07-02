#if os(iOS)
import XCTest
@testable import FittedSheets

final class SheetOptionsTests: XCTestCase {

    private var savedDefault: SheetOptions!

    override func setUp() {
        super.setUp()
        savedDefault = SheetOptions.default
    }

    override func tearDown() {
        SheetOptions.default = savedDefault
        super.tearDown()
    }

    // #22 — SheetOptions() and the parameterized init both inherit the mutable global default.
    func testEmptyInitInheritsMutatedDefault() {
        SheetOptions.default.pullBarHeight = 99
        XCTAssertEqual(SheetOptions().pullBarHeight, 99)
        XCTAssertEqual(SheetOptions(useInlineMode: true).pullBarHeight, 99)
    }

    // #22 — building `.default` (a static) must not recurse/deadlock; the bootstrap init returns stock values.
    func testDefaultUsesCompiledStockValues() {
        // Fresh default (restored in tearDown) exposes the compiled-in defaults.
        XCTAssertEqual(SheetOptions().pullBarHeight, 24)
        XCTAssertEqual(SheetOptions().transitionDuration, 0.4)
        XCTAssertFalse(SheetOptions().useInlineMode)
    }

    // #20 — isRubberBandEnabled falls back to the default, not a hardcoded false.
    func testIsRubberBandEnabledInheritsDefault() {
        SheetOptions.default.isRubberBandEnabled = true
        XCTAssertTrue(SheetOptions(pullBarHeight: 30).isRubberBandEnabled)
    }

    // #45 — the parameterized init exposes the transition-related options.
    func testInitAcceptsTransitionParams() {
        let o = SheetOptions(transitionDampening: 0.5, transitionDuration: 1.25, transitionVelocity: 2, pullDismissThreshold: 42)
        XCTAssertEqual(o.transitionDampening, 0.5)
        XCTAssertEqual(o.transitionDuration, 1.25)
        XCTAssertEqual(o.transitionVelocity, 2)
        XCTAssertEqual(o.pullDismissThreshold, 42)
    }

    // #44 — the deprecated misspelled alias forwards to the correctly-spelled property.
    func testPullDismissThresholdAliasForwards() {
        var o = SheetOptions()
        o.pullDismissThreshold = 321
        XCTAssertEqual(o.pullDismissThreshod, 321)
    }

    // maxWidth of 0 is treated as "no limit" (nil); positive values pass through.
    func testMaxWidthZeroBecomesNil() {
        XCTAssertNil(SheetOptions(maxWidth: 0).maxWidth)
        XCTAssertEqual(SheetOptions(maxWidth: 320).maxWidth, 320)
    }
}
#endif
