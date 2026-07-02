//
//  HandleOptions.swift
//  FittedSheetsPod
//
//  Created by Gordon Tucker on 7/29/20.
//  Copyright © 2020 Gordon Tucker. All rights reserved.
//

#if os(iOS)
import UIKit

public struct SheetOptions {
    nonisolated(unsafe) public static var `default` = SheetOptions(bootstrap: ())
    
    public enum TransitionOverflowType {
        case color(color: UIColor)
        case view(view: UIView)
        case none
        case automatic
    }
    
    public var pullBarHeight: CGFloat = 24
    
    public var presentingViewCornerRadius: CGFloat = 12
    public var shouldExtendBackground = true
    public var setIntrinsicHeightOnNavigationControllers = true

    public var transitionAnimationOptions: UIView.AnimationOptions = [.curveEaseOut]
    public var transitionDampening: CGFloat = 0.7
    public var transitionDuration: TimeInterval = 0.4
    /// Transition velocity base value. Automatically adjusts based on the initial size of the sheet.
    public var transitionVelocity: CGFloat = 0.8
    public var transitionOverflowType: TransitionOverflowType = .automatic
    
    /// Default value 500, greater value will require more velocity to dismiss. Lesser values will do opposite.
    public var pullDismissThreshold: CGFloat = 500.0

    /// Deprecated misspelled alias. Use `pullDismissThreshold` instead.
    @available(*, deprecated, renamed: "pullDismissThreshold")
    public var pullDismissThreshod: CGFloat {
        get { pullDismissThreshold }
        set { pullDismissThreshold = newValue }
    }
    
    /// Allow the sheet to become full screen if pulled all the way to the top and not larger than the maximum size specified in sizes. Defaults to true.
    public var useFullScreenMode = true
    public var shrinkPresentingViewController = true
    /// Set true to be able to use the sheet view controller as a subview instead of a modal. Defaults to false.
    public var useInlineMode = false
    
    public var horizontalPadding: CGFloat = 0
    public var maxWidth: CGFloat?

    public var isRubberBandEnabled: Bool = false
    
    /// Experimental flag that attempts to shrink the nested presentations more each time a new sheet is presented. This must be set before any sheet is presented.
    nonisolated(unsafe) public static var shrinkingNestedPresentingViewControllers = false
    
    /// Bootstraps `.default` with the compiled-in stock values WITHOUT reading
    /// `.default` (doing so would recurse/deadlock during static initialization).
    private init(bootstrap: Void) { }

    /// Inherits the app-wide `SheetOptions.default`, matching the parameterized init.
    public init() { self = SheetOptions.default }
    public init(pullBarHeight: CGFloat? = nil,
                presentingViewCornerRadius: CGFloat? = nil,
                shouldExtendBackground: Bool? = nil,
                setIntrinsicHeightOnNavigationControllers: Bool? = nil,
                transitionAnimationOptions: UIView.AnimationOptions? = nil,
                transitionDampening: CGFloat? = nil,
                transitionDuration: TimeInterval? = nil,
                transitionVelocity: CGFloat? = nil,
                transitionOverflowType: TransitionOverflowType? = nil,
                pullDismissThreshold: CGFloat? = nil,
                useFullScreenMode: Bool? = nil,
                shrinkPresentingViewController: Bool? = nil,
                useInlineMode: Bool? = nil,
                horizontalPadding: CGFloat? = nil,
                maxWidth: CGFloat? = nil,
                isRubberBandEnabled: Bool? = nil) {
        let defaultOptions = SheetOptions.default
        self.pullBarHeight = pullBarHeight ?? defaultOptions.pullBarHeight
        self.presentingViewCornerRadius = presentingViewCornerRadius ?? defaultOptions.presentingViewCornerRadius
        self.shouldExtendBackground = shouldExtendBackground ?? defaultOptions.shouldExtendBackground
        self.setIntrinsicHeightOnNavigationControllers = setIntrinsicHeightOnNavigationControllers ?? defaultOptions.setIntrinsicHeightOnNavigationControllers
        self.transitionAnimationOptions = transitionAnimationOptions ?? defaultOptions.transitionAnimationOptions
        self.transitionDampening = transitionDampening ?? defaultOptions.transitionDampening
        self.transitionDuration = transitionDuration ?? defaultOptions.transitionDuration
        self.transitionVelocity = transitionVelocity ?? defaultOptions.transitionVelocity
        self.transitionOverflowType = transitionOverflowType ?? defaultOptions.transitionOverflowType
        self.pullDismissThreshold = pullDismissThreshold ?? defaultOptions.pullDismissThreshold
        self.useFullScreenMode = useFullScreenMode ?? defaultOptions.useFullScreenMode
        self.shrinkPresentingViewController = shrinkPresentingViewController ?? defaultOptions.shrinkPresentingViewController
        self.useInlineMode = useInlineMode ?? defaultOptions.useInlineMode
        self.horizontalPadding = horizontalPadding ?? defaultOptions.horizontalPadding
        let maxWidth = maxWidth ?? defaultOptions.maxWidth
        self.maxWidth = maxWidth == 0 ? nil : maxWidth
        self.isRubberBandEnabled = isRubberBandEnabled ?? defaultOptions.isRubberBandEnabled
    }
    
    @available(*, unavailable, message: "cornerRadius, minimumSpaceAbovePullBar, gripSize and gripColor are now properties on SheetViewController. Use them instead.")
    public init(pullBarHeight: CGFloat? = nil,
                gripSize: CGSize? = nil,
                gripColor: UIColor? = nil,
                cornerRadius: CGFloat? = nil,
                presentingViewCornerRadius: CGFloat? = nil,
                shouldExtendBackground: Bool? = nil,
                setIntrinsicHeightOnNavigationControllers: Bool? = nil,
                useFullScreenMode: Bool? = nil,
                shrinkPresentingViewController: Bool? = nil,
                useInlineMode: Bool? = nil,
                minimumSpaceAbovePullBar: CGFloat? = nil) {
        let defaultOptions = SheetOptions.default
        self.pullBarHeight = pullBarHeight ?? defaultOptions.pullBarHeight
        self.presentingViewCornerRadius = presentingViewCornerRadius ?? defaultOptions.presentingViewCornerRadius
        self.shouldExtendBackground = shouldExtendBackground ?? defaultOptions.shouldExtendBackground
        self.setIntrinsicHeightOnNavigationControllers = setIntrinsicHeightOnNavigationControllers ?? defaultOptions.setIntrinsicHeightOnNavigationControllers
        self.useFullScreenMode = useFullScreenMode ?? defaultOptions.useFullScreenMode
        self.shrinkPresentingViewController = shrinkPresentingViewController ?? defaultOptions.shrinkPresentingViewController
        self.useInlineMode = useInlineMode ?? defaultOptions.useInlineMode
    }
}

#endif // os(iOS)
