#if os(iOS)
import XCTest
import UIKit
@testable import FittedSheets

@MainActor
final class SheetViewControllerTests: XCTestCase {

    func testSizesAndInitialCurrentSize() {
        let sheet = SheetViewController(controller: UIViewController(), sizes: [.fixed(200), .fullscreen])
        XCTAssertEqual(sheet.sizes, [.fixed(200), .fullscreen])
        XCTAssertEqual(sheet.currentSize, .intrinsic) // not resized until presented
    }

    func testEmptySizesFallsBackToIntrinsic() {
        let sheet = SheetViewController(controller: UIViewController(), sizes: [])
        XCTAssertEqual(sheet.sizes, [.intrinsic])
    }

    func testCornerRadiusAndCurveForwardToContent() {
        let sheet = SheetViewController(controller: UIViewController())
        sheet.cornerRadius = 33
        XCTAssertEqual(sheet.contentViewController.cornerRadius, 33)
        sheet.cornerCurve = .continuous
        XCTAssertEqual(sheet.contentViewController.cornerCurve, .continuous)
    }

    // updateOrderedSizes must order the detents by ascending resolved height.
    func testOrderedSizesSortedByHeight() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sheet = SheetViewController(controller: UIViewController(), sizes: [.fullscreen, .fixed(120), .fixed(400)])
        window.rootViewController = sheet
        window.makeKeyAndVisible()
        sheet.view.layoutIfNeeded()
        sheet.updateOrderedSizes()
        XCTAssertEqual(sheet.orderedSizes, [.fixed(120), .fixed(400), .fullscreen])
    }

    // #21 — a size that resolves negative must be clamped so the sheet height is never negative.
    func testHeightNeverNegative() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        let sheet = SheetViewController(controller: UIViewController(), sizes: [.marginFromTop(1000)])
        window.rootViewController = sheet
        window.makeKeyAndVisible()
        sheet.view.layoutIfNeeded()
        sheet.resize(to: .marginFromTop(1000), animated: false)
        sheet.view.layoutIfNeeded()
        XCTAssertGreaterThanOrEqual(sheet.contentViewController.view.frame.height, 0)
    }

    // #41 — presentOverWindow reports success when a hosting window exists.
    func testPresentOverWindowSucceedsWithHost() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        let sheet = SheetViewController(controller: UIViewController(), sizes: [.percent(0.5)])
        sheet.allowGestureThroughOverlay = true
        XCTAssertTrue(sheet.presentOverWindow(window, duration: 0))
    }

    // Grabber visibility actually toggles the loaded gripView (not just the flag).
    func testPrefersGrabberVisibleHidesRealGrip() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sheet = SheetViewController(controller: UIViewController(), sizes: [.fixed(300)]) // default pullBarHeight > 0
        XCTAssertTrue(sheet.prefersGrabberVisible)
        sheet.prefersGrabberVisible = false
        window.rootViewController = sheet
        window.makeKeyAndVisible()
        sheet.view.layoutIfNeeded() // setupPullBarView runs -> gripView.isHidden = isGripHidden
        XCTAssertTrue(sheet.contentViewController.gripView.isHidden)
        sheet.prefersGrabberVisible = true
        XCTAssertFalse(sheet.contentViewController.gripView.isHidden)
    }

    func testScrollingExpandsDefault() {
        // Behavioral gating lives in gestureRecognizerShouldBegin (needs a live pan+scroll to fully
        // exercise); here we at least pin the default.
        XCTAssertTrue(SheetViewController(controller: UIViewController()).scrollingExpandsWhenScrolledToEdge)
    }

    // largestUndimmedSize: crossing the threshold via resize() updates BOTH the overlay dim alpha
    // AND overlay interactivity/pass-through (regression guard for the stale-interactivity bug).
    func testLargestUndimmedSizeControlsOverlayAndInteractivity() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sheet = SheetViewController(controller: UIViewController(), sizes: [.fixed(200), .fullscreen])
        window.rootViewController = sheet
        window.makeKeyAndVisible()
        sheet.view.layoutIfNeeded()
        sheet.largestUndimmedSize = .fixed(300)

        // Dimmed detent (fullscreen > 300): overlay opaque + interactive (tap dismisses).
        sheet.resize(to: .fullscreen, animated: false)
        XCTAssertEqual(sheet.overlayView.alpha, 1, accuracy: 0.01)
        XCTAssertTrue(sheet.overlayTapView.isUserInteractionEnabled)

        // Undimmed detent (200 <= 300): overlay transparent + passes touches through.
        sheet.resize(to: .fixed(200), animated: false)
        XCTAssertEqual(sheet.overlayView.alpha, 0, accuracy: 0.01)
        XCTAssertFalse(sheet.overlayTapView.isUserInteractionEnabled)

        // And back to dimmed re-enables the overlay (the bug left this stale).
        sheet.resize(to: .fullscreen, animated: false)
        XCTAssertTrue(sheet.overlayTapView.isUserInteractionEnabled)
    }

    // SheetHeightProgress: the library computes the overall fraction, per-step reveal, and reached
    // detent from its own detents.
    func testHeightProgressAcrossDetents() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sheet = SheetViewController(controller: UIViewController(), sizes: [.fixed(150), .fixed(350), .fixed(550)])
        window.rootViewController = sheet
        window.makeKeyAndVisible()
        sheet.view.layoutIfNeeded()

        // Smallest detent: fraction 0, only step 0 revealed, reached index 0.
        sheet.resize(to: .fixed(150), animated: false)
        var p = sheet.currentProgress
        XCTAssertEqual(p.steps.count, 3)
        XCTAssertEqual(p.fraction, 0, accuracy: 0.001)
        XCTAssertEqual(p.reachedIndex, 0)
        XCTAssertEqual(p.reachedSize, .fixed(150))
        XCTAssertEqual(p.steps[0].reveal, 1, accuracy: 0.001)
        XCTAssertEqual(p.steps[1].reveal, 0, accuracy: 0.001)
        XCTAssertEqual(p.steps[2].reveal, 0, accuracy: 0.001)

        // Middle detent: fraction (350-150)/(550-150) = 0.5, steps 0 & 1 revealed, reached index 1.
        sheet.resize(to: .fixed(350), animated: false)
        p = sheet.currentProgress
        XCTAssertEqual(p.fraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(p.reachedIndex, 1)
        XCTAssertEqual(p.reachedSize, .fixed(350))
        XCTAssertEqual(p.steps[1].reveal, 1, accuracy: 0.001)
        XCTAssertEqual(p.steps[2].reveal, 0, accuracy: 0.001)

        // Largest detent: fraction 1, all revealed, reached index 2.
        sheet.resize(to: .fixed(550), animated: false)
        p = sheet.currentProgress
        XCTAssertEqual(p.fraction, 1, accuracy: 0.001)
        XCTAssertEqual(p.reachedIndex, 2)
        XCTAssertEqual(p.steps[2].reveal, 1, accuracy: 0.001)
    }

    // Regression: reachedIndex must never report a detent as reached while its own step is < 1
    // revealed (the reachedIndex/-0.5 vs exact-reveal inconsistency the review found).
    func testHeightProgressReachedConsistentWithReveal() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sheet = SheetViewController(controller: UIViewController(), sizes: [.fixed(150), .fixed(350), .fixed(550)])
        window.rootViewController = sheet
        window.makeKeyAndVisible()
        sheet.view.layoutIfNeeded()

        // Park just below the middle detent, inside the old -0.5pt tolerance window.
        sheet.resize(to: .fixed(349.7), animated: false)
        let p = sheet.currentProgress
        XCTAssertLessThan(p.steps[1].reveal, 1)          // middle detent not fully revealed...
        XCTAssertEqual(p.reachedIndex, 0)                 // ...so it must NOT be reported as reached.
        XCTAssertEqual(p.reachedSize, .fixed(150))
        // Invariant: reachedIndex == (number of fully-revealed steps) - 1.
        let fullyRevealed = p.steps.filter { $0.reveal >= 1 }.count
        XCTAssertEqual(p.reachedIndex, fullyRevealed - 1)
    }
}
#endif
