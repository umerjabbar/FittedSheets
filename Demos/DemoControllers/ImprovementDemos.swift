//
//  ImprovementDemos.swift
//  FittedSheets
//
//  Demos that exercise the behaviors added/changed during the hardening + iOS-15 modernization
//  pass, so each can be tested from the running app. Existing demos already cover keyboard,
//  scrolling, navigation intrinsic sizing, resizing/detents, rubber-band, colors/dark-mode,
//  corner curve, blur, max-width side gutters, and shouldDismiss/didDismiss/sizeChanged logging
//  (see addSheetEventLogging, which prints to the console for every demo).
//

import UIKit
import FittedSheets

// MARK: - Liquid Glass background (iOS 26+) — opt-in useLiquidGlassBackground

class LiquidGlassDemo: UIViewController, Demoable {
    class var name: String { "Liquid Glass background (iOS 26+)" }

    override func viewDidLoad() {
        super.viewDidLoad()
        addCenteredLabel("Background uses UIGlassEffect on iOS 26+ (falls back to UIBlurEffect below).\n\nLook at the material behind/around this sheet.")
    }

    class func openDemo(from parent: UIViewController, in view: UIView?) {
        let controller = LiquidGlassDemo()
        var options = SheetOptions()
        options.useInlineMode = view != nil
        let sheet = SheetViewController(controller: controller, sizes: [.percent(0.5), .fullscreen], options: options)
        sheet.hasBlurBackground = true
        sheet.useLiquidGlassBackground = true
        sheet.cornerRadius = 24
        addSheetEventLogging(to: sheet)
        present(sheet, from: parent, in: view)
    }
}

// MARK: - Status bar style forwarding (#25) — modalPresentationCapturesStatusBarAppearance

class StatusBarStyleDemo: UIViewController, Demoable {
    class var name: String { "Status bar style forwarding (#25)" }

    // The sheet forwards status-bar control to its child; this child requests light content.
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .darkGray
        addCenteredLabel("This child returns .lightContent.\n\nThe status bar text should be WHITE while this sheet is up (modal presentation), proving childForStatusBarStyle is consulted.", color: .white)
    }

    class func openDemo(from parent: UIViewController, in view: UIView?) {
        let controller = StatusBarStyleDemo()
        var options = SheetOptions()
        options.useInlineMode = view != nil
        let sheet = SheetViewController(controller: controller, sizes: [.percent(0.6)], options: options)
        addSheetEventLogging(to: sheet)
        present(sheet, from: parent, in: view)
    }
}

// MARK: - panGestureShouldBegin (#6) — consulted even without a child scroll view

class PanGestureShouldBeginDemo: UIViewController, Demoable {
    class var name: String { "panGestureShouldBegin blocks drag (#6)" }

    override func viewDidLoad() {
        super.viewDidLoad()
        addCenteredLabel("Dragging is DISABLED via panGestureShouldBegin = { _ in false } (no child scroll view registered).\n\nTry to drag the sheet — it won't move. Tap outside to dismiss.")
    }

    class func openDemo(from parent: UIViewController, in view: UIView?) {
        let controller = PanGestureShouldBeginDemo()
        var options = SheetOptions()
        options.useInlineMode = view != nil
        let sheet = SheetViewController(controller: controller, sizes: [.percent(0.4), .percent(0.8)], options: options)
        // Before #6 this closure was ignored unless handleScrollView() had registered a scroll view.
        sheet.panGestureShouldBegin = { _ in
            print("panGestureShouldBegin consulted -> returning false (drag blocked)")
            return false
        }
        addSheetEventLogging(to: sheet)
        present(sheet, from: parent, in: view)
    }
}

// MARK: - Navigation delegate preservation (#14)

/// The app's own navigation delegate. It must keep receiving callbacks even though the sheet
/// installs its intrinsic-height proxy.
private class LoggingNavDelegate: NSObject, UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        print("APP nav delegate: didShow \(type(of: viewController)) — the app's delegate is still being forwarded to (#14).")
    }
}

class NavigationDelegatePreservationDemo: UIViewController, Demoable {
    class var name: String { "Nav delegate preserved (#14)" }
    // Retained for the lifetime of the demo so the (weakly-held) forwardee stays alive.
    private static var appNavDelegate: LoggingNavDelegate?

    class func openDemo(from parent: UIViewController, in view: UIView?) {
        let root = NavStepViewController(index: 0)
        let nav = UINavigationController(rootViewController: root)

        // The app installs ITS OWN delegate before presenting. The sheet must forward to it.
        let appDelegate = LoggingNavDelegate()
        appNavDelegate = appDelegate
        nav.delegate = appDelegate

        var options = SheetOptions()
        options.useInlineMode = view != nil
        let sheet = SheetViewController(controller: nav, sizes: [.intrinsic, .fullscreen], options: options)
        addSheetEventLogging(to: sheet)
        present(sheet, from: parent, in: view)
    }
}

/// A simple pushable step; pushing changes intrinsic height (sheet should resize) and each push
/// logs the app delegate's didShow, proving both the sheet's own recalculation and forwarding work.
private class NavStepViewController: UIViewController {
    let index: Int
    init(index: Int) { self.index = index; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        self.title = "Step \(index)"

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "Step \(index).\n\nPush the next step — the sheet resizes to fit AND the console logs the app's nav delegate didShow (proving #14 preserves your delegate).\n\n" + String(repeating: "More content.\n", count: index + 1)
        label.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.setTitle("Push Step \(index + 1)", for: .normal)
        button.addTarget(self, action: #selector(pushNext), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [label, button])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: self.view.bottomAnchor, constant: -20)
        ])
    }

    @objc private func pushNext() {
        self.navigationController?.pushViewController(NavStepViewController(index: index + 1), animated: true)
    }
}

// MARK: - largestUndimmedSize + prefersGrabberVisible (native-sheet parity)

class LargestUndimmedDemo: UIViewController, Demoable {
    class var name: String { "Undimmed detent + hidden grabber" }

    override func viewDidLoad() {
        super.viewDidLoad()
        addCenteredLabel("largestUndimmedSize = .percent(0.3), prefersGrabberVisible = false.\n\nAt the small detent the overlay is undimmed and the app behind stays tappable; drag up to the large detent and it dims + blocks. The grabber is hidden.")
    }

    class func openDemo(from parent: UIViewController, in view: UIView?) {
        let controller = LargestUndimmedDemo()
        var options = SheetOptions()
        options.useInlineMode = view != nil
        let sheet = SheetViewController(controller: controller, sizes: [.percent(0.3), .percent(0.9)], options: options)
        sheet.largestUndimmedSize = .percent(0.3) // undimmed at/below 30%, dimmed above
        sheet.prefersGrabberVisible = false
        sheet.cornerRadius = 20
        addSheetEventLogging(to: sheet)
        if let view = view {
            sheet.animateIn(to: view, in: parent)
        } else {
            // Window-attach so overlay touches actually pass through at the undimmed detent.
            sheet.presentOverWindow()
        }
    }
}

// MARK: - Shared helpers

private extension Demoable {
    static func present(_ sheet: SheetViewController, from parent: UIViewController, in view: UIView?) {
        if let view = view {
            sheet.animateIn(to: view, in: parent)
        } else {
            parent.present(sheet, animated: true, completion: nil)
        }
    }
}

private extension UIViewController {
    @discardableResult
    func addCenteredLabel(_ text: String, color: UIColor? = nil) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = text
        if let color = color { label.textColor = color }
        label.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor, constant: -24)
        ])
        return label
    }
}
