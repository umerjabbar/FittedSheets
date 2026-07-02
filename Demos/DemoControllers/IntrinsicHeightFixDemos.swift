//
//  IntrinsicHeightFixDemos.swift
//  FittedSheets
//
//  Demos for the intrinsic-height calculation/update fixes:
//   • Nav push/pop resizes the sheet IN STEP with the transition (recompute moved to willShow).
//   • A stale keyboard inset is cleared even when autoAdjustToKeyboard is toggled off mid-keyboard.
//   • A translucent + non-extending navigation bar no longer under-measures the sheet by a bar height.
//
//  Each is registered in ModalDemosViewController and prints to the console via addSheetEventLogging.
//

import UIKit
import FittedSheets

// MARK: - Fix #2 — nav push/pop resizes in step with the transition

class NavResizeInStepDemo: UIViewController, Demoable {
    class var name: String { "Nav push/pop resizes in step" }

    class func openDemo(from parent: UIViewController, in view: UIView?) {
        let nav = UINavigationController(rootViewController: SizedStepViewController(index: 0))
        var options = SheetOptions()
        options.useInlineMode = view != nil
        let sheet = SheetViewController(controller: nav, sizes: [.intrinsic, .fullscreen], options: options)
        sheet.cornerRadius = 20
        addSheetEventLogging(to: sheet)
        if let view = view {
            sheet.animateIn(to: view, in: parent)
        } else {
            parent.present(sheet, animated: true, completion: nil)
        }
    }
}

/// A pushable step whose content height alternates short/tall, so each push AND each pop visibly
/// changes the intrinsic height. The fix recomputes at `willShow`, so the sheet grows/shrinks
/// together with the push/pop animation instead of snapping after it completes. Use the nav bar's
/// back button to pop and watch the sheet shrink in step too.
private class SizedStepViewController: UIViewController {
    private let index: Int
    init(index: Int) { self.index = index; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        self.title = "Step \(index)"

        // Alternate the body height so the resize direction flips on every push/pop.
        let lineCount = index.isMultiple(of: 2) ? 2 : 8
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "Step \(index) — \(index.isMultiple(of: 2) ? "SHORT" : "TALL")\n\n"
            + "Push the next step: the sheet resizes IN STEP with the navigation transition (the "
            + "recompute now runs at willShow). Tap the back button to pop and watch it shrink in step.\n\n"
            + String(repeating: "Line of content.\n", count: lineCount)
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
            stack.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    @objc private func pushNext() {
        self.navigationController?.pushViewController(SizedStepViewController(index: index + 1), animated: true)
    }
}

// MARK: - Fix #1 — stale keyboard inset cleared when avoidance is toggled off

class KeyboardToggleFreezeDemo: UIViewController, Demoable {
    class var name: String { "Keyboard: toggle avoidance off (no freeze)" }

    private let field = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground

        let info = UILabel()
        info.numberOfLines = 0
        info.textAlignment = .center
        info.text = "Repro for the keyboard-inset freeze:\n\n"
            + "1. Tap the field → keyboard shows, sheet grows.\n"
            + "2. Flip the switch OFF (autoAdjustToKeyboard = false).\n"
            + "3. Tap “Dismiss keyboard”.\n\n"
            + "Fixed: the sheet shrinks back to intrinsic. Before the fix it stayed stuck tall."
        info.translatesAutoresizingMaskIntoConstraints = false

        field.borderStyle = .roundedRect
        field.placeholder = "Tap here to show the keyboard"
        field.translatesAutoresizingMaskIntoConstraints = false

        let toggleLabel = UILabel()
        toggleLabel.text = "autoAdjustToKeyboard"
        let toggle = UISwitch()
        toggle.isOn = true
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
        let toggleRow = UIStackView(arrangedSubviews: [toggleLabel, toggle])
        toggleRow.axis = .horizontal
        toggleRow.spacing = 12

        let dismissButton = UIButton(type: .system)
        dismissButton.setTitle("Dismiss keyboard", for: .normal)
        dismissButton.addTarget(self, action: #selector(dismissKeyboard), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [info, field, toggleRow, dismissButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            field.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        self.sheetViewController?.autoAdjustToKeyboard = sender.isOn
        print("autoAdjustToKeyboard = \(sender.isOn)")
    }

    @objc private func dismissKeyboard() {
        self.view.endEditing(true)
    }

    class func openDemo(from parent: UIViewController, in view: UIView?) {
        let controller = KeyboardToggleFreezeDemo()
        var options = SheetOptions()
        options.useInlineMode = view != nil
        let sheet = SheetViewController(controller: controller, sizes: [.intrinsic], options: options)
        sheet.cornerRadius = 20
        addSheetEventLogging(to: sheet)
        if let view = view {
            sheet.animateIn(to: view, in: parent)
        } else {
            parent.present(sheet, animated: true, completion: nil)
        }
    }
}

// MARK: - Fix #3 — translucent + non-extending nav bar measured at full height

class TranslucentNavBarSizingDemo: UIViewController, Demoable {
    class var name: String { "Translucent non-extending nav bar sizing" }

    class func openDemo(from parent: UIViewController, in view: UIView?) {
        let root = NonExtendingContentViewController()
        let nav = UINavigationController(rootViewController: root)
        nav.navigationBar.isTranslucent = true // translucent bar + a non-extending top VC was the missed case

        var options = SheetOptions()
        options.useInlineMode = view != nil
        let sheet = SheetViewController(controller: nav, sizes: [.intrinsic, .fullscreen], options: options)
        sheet.cornerRadius = 20
        addSheetEventLogging(to: sheet)
        if let view = view {
            sheet.animateIn(to: view, in: parent)
        } else {
            parent.present(sheet, animated: true, completion: nil)
        }
    }
}

/// Top VC with a translucent bar and `edgesForExtendedLayout = []`, so its view is inset below the
/// bar and the raw content measurement omits the bar height. The fix adds the bar height back based
/// on real underlap, so the "BOTTOM EDGE" marker below stays fully visible instead of being clipped.
private class NonExtendingContentViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        self.title = "Translucent Bar"
        self.edgesForExtendedLayout = [] // content does NOT extend under the (translucent) bar

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "Translucent bar + edgesForExtendedLayout = [].\n\n"
            + "The sheet should size to show the whole box, including the marker at its bottom edge. "
            + "Before the fix it was one nav-bar-height too short and the marker was clipped."
        label.translatesAutoresizingMaskIntoConstraints = false

        let bottomMarker = UILabel()
        bottomMarker.text = "▼ BOTTOM EDGE — must be fully visible ▼"
        bottomMarker.textAlignment = .center
        bottomMarker.textColor = .white
        bottomMarker.backgroundColor = .systemRed
        bottomMarker.translatesAutoresizingMaskIntoConstraints = false

        let box = UIStackView(arrangedSubviews: [label, bottomMarker])
        box.axis = .vertical
        box.spacing = 16
        box.layer.borderColor = UIColor.systemBlue.cgColor
        box.layer.borderWidth = 2
        box.isLayoutMarginsRelativeArrangement = true
        box.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        box.translatesAutoresizingMaskIntoConstraints = false

        self.view.addSubview(box)
        NSLayoutConstraint.activate([
            box.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 16),
            box.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            box.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            box.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            bottomMarker.widthAnchor.constraint(equalTo: box.widthAnchor, constant: -32)
        ])
    }
}
