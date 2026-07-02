//
//  DemoRegistry.swift
//  FittedSheets
//
//  Single source of truth for the modal demo list, shared by ModalDemosViewController and the
//  launch-argument auto-open hook in SceneDelegate. Launch with the environment variable
//  FS_AUTO_OPEN_DEMO set to a demo's `name` (e.g. via
//  `SIMCTL_CHILD_FS_AUTO_OPEN_DEMO="Adaptive content per sheet height" xcrun simctl launch ...`)
//  to jump straight into that demo — useful for manual and screenshot-based testing.
//

import UIKit
import FittedSheets

enum DemoRegistry {
    static let modalDemos: [(UIViewController & Demoable).Type] = [
        OnlyCloseWithButtonDemo.self,
        ResizingDemo.self,
        NavigationDemo.self,
        ScrollViewDemo.self,
        TableViewDemo.self,
        TableViewControllerDemo.self,
        ScrollInNavigationDemo.self,
        KeyboardDemo.self,
        IntrinsicDemo.self,
        IntrinsicInNavigationDemo.self,
        IntrinsicAndFullscreenDemo.self,
        IntrinsicAndTrueFullscreenDemo.self,
        ColorDemo.self,
        NoPullBarDemo.self,
        ClearPullBarDemo.self,
        MaxMinHeightDemo.self,
        HorizontalPaddingDemo.self,
        MaxWidthDemo.self,
        BlurDemo.self,
        NestedSheetsDemo.self,
        RubberBandDemo.self,
        CornerCurveDemo.self,
        PassThroughOverlayDemo.self,
        LiquidGlassDemo.self,
        StatusBarStyleDemo.self,
        PanGestureShouldBeginDemo.self,
        NavigationDelegatePreservationDemo.self,
        LargestUndimmedDemo.self,
        NavResizeInStepDemo.self,
        KeyboardToggleFreezeDemo.self,
        TranslucentNavBarSizingDemo.self,
        AdaptiveContentDemo.self
    ].sorted(by: { $0.name < $1.name })

    static func demo(named name: String) -> (UIViewController & Demoable).Type? {
        modalDemos.first { $0.name == name }
    }

    /// If `FS_AUTO_OPEN_DEMO` is set, present the matching demo from the window's top view
    /// controller once the UI is on screen. When `FS_AUTO_OPEN_DETENT` names a 0-based index into
    /// the presented sheet's `sizes`, also resize to that detent (a testing/deep-link aid). No-op
    /// otherwise.
    static func autoOpenIfRequested(in window: UIWindow?) {
        let env = ProcessInfo.processInfo.environment
        guard let name = env["FS_AUTO_OPEN_DEMO"],
              !name.isEmpty,
              let demo = demo(named: name),
              let window = window else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            var top = window.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            guard let parent = top else { return }
            demo.openDemo(from: parent, in: nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard let sheet = parent.presentedViewController as? SheetViewController else { return }
                // FS_AUTO_OPEN_PERCENT resizes to an arbitrary height fraction (to capture a
                // mid-drag state); FS_AUTO_OPEN_DETENT resizes to a 0-based index into `sizes`.
                if let pctString = env["FS_AUTO_OPEN_PERCENT"], let pct = Double(pctString) {
                    sheet.resize(to: .percent(CGFloat(pct)), animated: false)
                } else if let detent = env["FS_AUTO_OPEN_DETENT"], let index = Int(detent),
                          sheet.sizes.indices.contains(index) {
                    sheet.resize(to: sheet.sizes[index], animated: false)
                }
            }
        }
    }
}
