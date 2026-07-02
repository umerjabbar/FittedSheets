//
//  BlurDemo.swift
//  FittedSheets
//
//  Created by farhad jebelli on 8/13/20.
//  Copyright © 2020 Gordon Tucker. All rights reserved.
//

import UIKit
import FittedSheets

class BlurDemo: SimpleDemo {
    override class var name: String { "Blur Effect" }
    
    override class func openDemo(from parent: UIViewController, in view: UIView?) {
        let useInlineMode = view != nil
        
        let controller = ColorDemo()
        
        var options = SheetOptions()
        options.pullBarHeight = 30
        options.useInlineMode = useInlineMode
        
        let sheet = SheetViewController(controller: controller, sizes: [.percent(0.25), .fullscreen], options: options)
        sheet.hasBlurBackground = true
        
        sheet.cornerRadius = 30
        sheet.gripSize = CGSize(width: 100, height: 12)
        
        addSheetEventLogging(to: sheet)
        
        if let view = view {
            sheet.animateIn(to: view, in: parent)
        } else {
            parent.present(sheet, animated: true, completion: nil)
        }
    }
}

/// Demonstrates `allowGestureThroughOverlay` under modal-style usage via `presentOverWindow()`.
/// The buttons visible through the dimmed overlay above the sheet remain tappable, because the
/// sheet is attached over the window (a sibling of the app content) rather than presented as a
/// blocking UIKit modal.
class PassThroughOverlayDemo: UIViewController, Demoable {
    class var name: String { "Pass-through overlay (window)" }

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "allowGestureThroughOverlay + presentOverWindow()\n\nThe demo buttons showing through the dimmed area above are still tappable — the sheet is attached over the window, not presented as a blocking modal.\n\nPull down to dismiss."
        label.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor, constant: -24)
        ])
    }

    class func openDemo(from parent: UIViewController, in view: UIView?) {
        let controller = PassThroughOverlayDemo()

        let sheet = SheetViewController(controller: controller, sizes: [.percent(0.4)])
        sheet.allowGestureThroughOverlay = true
        sheet.cornerRadius = 20

        addSheetEventLogging(to: sheet)

        if let view = view {
            // Inline mode already supports pass-through.
            sheet.animateIn(to: view, in: parent)
        } else {
            // Window-attach so overlay-region touches reach the app behind (a standard modal cannot).
            sheet.presentOverWindow()
        }
    }
}
