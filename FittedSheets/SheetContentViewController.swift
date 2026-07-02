//
//  SheetContentViewController.swift
//  FittedSheetsPod
//
//  Created by Gordon Tucker on 7/29/20.
//  Copyright © 2020 Gordon Tucker. All rights reserved.
//

#if os(iOS)
import UIKit

public class SheetContentViewController: UIViewController {
    
    public private(set) var childViewController: UIViewController
    
    private var options: SheetOptions
    private(set) var preferredHeight: CGFloat
    
    public var contentBackgroundColor: UIColor? {
        get { self.childContainerView.backgroundColor }
        set { self.childContainerView.backgroundColor = newValue }
    }

    public var cornerCurve: CALayerCornerCurve = .circular {
        didSet {
            self.updateCornerCurve()
        }
    }
    
    public var cornerRadius: CGFloat = 0 {
        didSet {
            self.updateCornerRadius()
        }
    }
    
    public var gripSize: CGSize = CGSize(width: 50, height: 6) {
        didSet {
            self.gripSizeConstraints.forEach({ $0.isActive = false })
            self.gripView.translatesAutoresizingMaskIntoConstraints = false
            self.gripSizeConstraints = [
                self.gripView.widthAnchor.constraint(equalToConstant: self.gripSize.width),
                self.gripView.heightAnchor.constraint(equalToConstant: self.gripSize.height)
            ]
            NSLayoutConstraint.activate(self.gripSizeConstraints)
            self.gripView.layer.cornerRadius = self.gripSize.height / 2
        }
    }
    
    public var gripColor: UIColor? {
        get { return self.gripView.backgroundColor }
        set { self.gripView.backgroundColor = newValue }
    }

    public var isGripHidden: Bool = false {
        didSet { self.gripView.isHidden = isGripHidden }
    }
    
    public var pullBarBackgroundColor: UIColor? {
        get { return self.pullBarView.backgroundColor }
        set { self.pullBarView.backgroundColor = newValue }
    }
    public var treatPullBarAsClear: Bool = SheetViewController.treatPullBarAsClear {
        didSet {
            if self.isViewLoaded {
                self.updateCornerRadius()
            }
        }
    }
    
    weak var delegate: SheetContentViewDelegate?
    
    public var contentWrapperView = UIView()
    public var contentView = UIView()
    private var contentTopConstraint: NSLayoutConstraint?
    private var contentBottomConstraint: NSLayoutConstraint?
    private var navigationHeightConstraint: NSLayoutConstraint?
    private var navigationDelegateProxy: SheetNavigationDelegateProxy?
    /// Whether the nav's content grows with the bottom safe area (pinned to safeAreaLayoutGuide.bottom).
    /// Probed on settled measurements and applied while an incoming VC is transiently off-screen.
    private var navContentUsesBottomInset = false
    /// The top VC last probed for bottom-inset usage, so we don't re-probe it every settled pass.
    private var lastProbedTopVC: ObjectIdentifier?
    /// Guards against re-entrant measurement (the probe / safe-area compensation briefly change
    /// safe-area insets, so app code observing that must not recurse into updatePreferredHeight).
    private var isMeasuringPreferredHeight = false
    private var gripSizeConstraints: [NSLayoutConstraint] = []
    public var childContainerView = UIView()
    public var pullBarView = UIView()
    public var gripView = UIView()
    private let overflowView = UIView()
    
    public init(childViewController: UIViewController, options: SheetOptions) {
        self.options = options
        self.childViewController = childViewController
        self.preferredHeight = 0
        super.init(nibName: nil, bundle: nil)
        
        if options.setIntrinsicHeightOnNavigationControllers, let navigationController = self.childViewController as? UINavigationController {
            // Preserve any delegate the app already installed by forwarding through a proxy
            // instead of silently replacing it.
            let proxy = SheetNavigationDelegateProxy(forwardee: navigationController.delegate, owner: self)
            self.navigationDelegateProxy = proxy
            navigationController.delegate = proxy
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // Restore the app's original navigation delegate if our proxy is still installed.
        // A UIViewController is always deallocated on the main thread, so assuming main-actor
        // isolation here is safe and lets us touch the (main-actor) UINavigationController.
        MainActor.assumeIsolated {
            if let nav = childViewController as? UINavigationController, nav.delegate === navigationDelegateProxy {
                nav.delegate = navigationDelegateProxy?.forwardee
            }
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupContentView()
        self.setupChildContainerView()
        self.setupPullBarView()
        self.setupChildViewController()
        self.updatePreferredHeight()
        self.updateCornerCurve()
        self.updateCornerRadius()
        self.setupOverflowView()

        NotificationCenter.default.addObserver(self, selector: #selector(contentSizeDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIView.performWithoutAnimation {
            self.view.layoutIfNeeded()
        }
        self.updatePreferredHeight()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.updatePreferredHeight()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    func adjustForKeyboard(height: CGFloat) {
        self.updateChildViewControllerBottomConstraint(adjustment: -height)
    }

    private func updateCornerCurve() {
        self.contentWrapperView.layer.cornerCurve = self.cornerCurve
        self.childContainerView.layer.cornerCurve = self.cornerCurve
    }

    private func updateCornerRadius() {
        self.contentWrapperView.layer.cornerRadius = self.treatPullBarAsClear ? 0 : self.cornerRadius
        self.childContainerView.layer.cornerRadius = self.treatPullBarAsClear ? self.cornerRadius : 0
    }
    
    private func setupOverflowView() {
        switch (self.options.transitionOverflowType) {
            case .view(view: let view):
                overflowView.backgroundColor = .clear
                overflowView.addSubview(view)
                view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    view.leftAnchor.constraint(equalTo: overflowView.leftAnchor),
                    view.rightAnchor.constraint(equalTo: overflowView.rightAnchor),
                    view.topAnchor.constraint(equalTo: overflowView.topAnchor),
                    view.bottomAnchor.constraint(equalTo: overflowView.bottomAnchor)
                ])
            case .automatic:
                overflowView.backgroundColor = self.childViewController.view.backgroundColor
            case .color(color: let color):
                overflowView.backgroundColor = color
            case .none:
                overflowView.backgroundColor = .clear
        }
    }
    
    /// Width to measure intrinsic content at. Uses the live view width once laid out; before the
    /// first layout pass (`bounds.width == 0`, e.g. from `viewDidLoad` or an off-window
    /// `updateIntrinsicHeight()`) it falls back to the sheet's own window — not the deprecated,
    /// multi-scene-incorrect `UIScreen.main` — clamped to the same content-card geometry
    /// (`horizontalPadding` + `maxWidth`) that `SheetViewController.addContentView` enforces.
    /// Measuring at the full window/screen width would let text under-wrap and report a height
    /// that is far too small on iPad Split View / centered `maxWidth` cards.
    private var measurementWidth: CGFloat {
        if self.view.bounds.width > 0 { return self.view.bounds.width }
        let windowWidth = self.view.window?.bounds.width
            ?? UIApplication.shared.fs_keyWindow?.bounds.width
            ?? UIScreen.main.bounds.width
        let cardWidth = windowWidth - (2 * self.options.horizontalPadding)
        return min(cardWidth, self.options.maxWidth ?? .greatestFiniteMagnitude)
    }

    private func updateNavigationControllerHeight() {
        // UINavigationControllers don't set intrinsic size, this is a workaround to fix that
        guard self.options.setIntrinsicHeightOnNavigationControllers, let navigationController = self.childViewController as? UINavigationController else { return }
        self.navigationHeightConstraint?.isActive = false
        self.contentTopConstraint?.isActive = false
        
        if let viewController = navigationController.topViewController {
            // bounds.width can be 0 before the first layout pass (this runs from viewDidLoad);
            // with .required horizontal priority a 0 width would wrap content and yield a bogus
            // height. This line is load-bearing for nav sheets (it drives the 999-priority
            // navigationHeightConstraint), so it must use the same card-clamped fallback as
            // updatePreferredHeight() or the two measurements disagree.
            let width = self.measurementWidth
            var fittingSize = UIView.layoutFittingCompressedSize
            fittingSize.width = width
            let rawFitting = viewController.view.systemLayoutSizeFitting(
                fittingSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel).height
            var height = rawFitting

            // The fitting above measures only the part of the bar the top view controller does
            // NOT already underlap. Add back whatever the measurement missed, inferred from how
            // much of the bar height the top VC's own top safe-area inset already reserves.
            let navBar = navigationController.navigationBar
            if !navigationController.isNavigationBarHidden {
                let alreadyCounted = min(navBar.frame.height, viewController.view.safeAreaInsets.top)
                height += navBar.frame.height - alreadyCounted
            }

            // During a push/pop the incoming top VC is transiently OFF-SCREEN, so its safeAreaInsets
            // read 0 and the fitting omits the insets the settled nav content area reserves — measuring
            // short, so the sheet would resize AGAIN at didShow (a bounce). The nav controller's own
            // view stays on-screen with correct insets throughout, so add back what the incoming VC is
            // still missing. At rest (settled VC) both are 0, so it's a no-op outside the transition.
            let navInsets = navigationController.view.safeAreaInsets
            let vcInsets = viewController.view.safeAreaInsets

            // Top: the content always sits below the bar, so it always reserves the top inset.
            height += max(0, navInsets.top - vcInsets.top)

            // Bottom: an off-screen VC's window-derived bottom inset reads 0 and UIKit ignores
            // overrides during the transition, so we can't measure it directly. Instead, when the VC
            // IS settled (on-screen), probe once whether its content actually grows with the bottom
            // safe area (add a probe inset and see if the fitting grows) and cache it; while an
            // incoming VC is transiently off-screen, apply that cached bottom inset so the sheet
            // resizes in step. (Consecutive nav VCs share a bottom-pinning convention in practice.)
            if navInsets.bottom > 0 {
                if vcInsets.bottom >= navInsets.bottom {
                    // Settled. Probe once per top VC (the bottom-pinning convention is structural, so
                    // it doesn't change with content) rather than on every settled pass.
                    let topVCID = ObjectIdentifier(viewController)
                    if topVCID != self.lastProbedTopVC {
                        let savedInsets = viewController.additionalSafeAreaInsets
                        viewController.additionalSafeAreaInsets = UIEdgeInsets(
                            top: savedInsets.top, left: savedInsets.left,
                            bottom: savedInsets.bottom + navInsets.bottom, right: savedInsets.right)
                        UIView.performWithoutAnimation { self.view.layoutIfNeeded() }
                        let probedFitting = viewController.view.systemLayoutSizeFitting(
                            fittingSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
                        viewController.additionalSafeAreaInsets = savedInsets
                        UIView.performWithoutAnimation { self.view.layoutIfNeeded() }
                        self.navContentUsesBottomInset = (probedFitting - rawFitting) > navInsets.bottom * 0.5
                        self.lastProbedTopVC = topVCID
                    }
                } else if self.navContentUsesBottomInset {
                    height += navInsets.bottom - vcInsets.bottom
                }
            }

            if self.navigationHeightConstraint == nil {
                self.navigationHeightConstraint = navigationController.view.heightAnchor.constraint(equalToConstant: height)
                self.navigationHeightConstraint?.priority = UILayoutPriority(999)
            } else {
                self.navigationHeightConstraint?.constant = height
            }
        }
        self.navigationHeightConstraint?.isActive = true
        self.contentTopConstraint?.isActive = true
    }
    
    func updatePreferredHeight() {
        // The probe and the safe-area compensation below briefly mutate safe-area insets, which can
        // fire viewSafeAreaInsetsDidChange on app content; ignore any re-entrant call it makes so the
        // outer measurement (which already reflects the current state) completes cleanly.
        guard !self.isMeasuringPreferredHeight else { return }
        self.isMeasuringPreferredHeight = true
        defer { self.isMeasuringPreferredHeight = false }

        // A child that respects the bottom safe area only grows into it once the sheet is on-window,
        // which lands AFTER the present transition and would then animate (a visible "nudge" just
        // after the sheet appears). Force the destination window's bottom inset into the measurement
        // up-front — BEFORE both the nav-controller measurement and the content fitting — so the
        // intrinsic height is final from the first pass. Applied as an additionalSafeAreaInset (only
        // the part not already present), so it's correct for both safe-area-respecting children (they
        // grow) and raw-bottom-pinned ones (they don't).
        // Only for bottom-anchored presentations (modal / window-attached), which will sit at the
        // screen bottom and inherit the home-indicator inset once on-window. Inline sheets are laid
        // out in their container synchronously (so no late growth), and may not be bottom-anchored,
        // so compensating there could over-reserve — skip them.
        // Also skip while a keyboard inset is applied (contentBottomConstraint != 0): UIKit may drop
        // the home-indicator inset under a docked keyboard, and height(for: .intrinsic) re-adds the
        // keyboardHeight separately — the real bottom inset is measured again on the next
        // keyboard-down pass, so compensating here could transiently over-size the sheet.
        let keyboardInsetApplied = (self.contentBottomConstraint?.constant ?? 0) != 0
        let windowBottomInset = (self.options.useInlineMode || keyboardInsetApplied)
            ? 0
            : (self.view.window ?? UIApplication.shared.fs_keyWindow)?.safeAreaInsets.bottom ?? 0
        let extraBottomInset = max(0, windowBottomInset - self.view.safeAreaInsets.bottom)
        let savedAdditionalInsets = self.additionalSafeAreaInsets
        if extraBottomInset > 0 {
            self.additionalSafeAreaInsets.bottom = savedAdditionalInsets.bottom + extraBottomInset
            // Propagate the inset down to the child (and any nested nav controller) before measuring.
            UIView.performWithoutAnimation {
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
            }
        }

        self.updateNavigationControllerHeight()
        let width = self.measurementWidth
        let oldPreferredHeight = self.preferredHeight
        var fittingSize = UIView.layoutFittingCompressedSize;
        fittingSize.width = width;

        // Exclude any keyboard bottom-inset (set by adjustForKeyboard) from the
        // measurement; SheetViewController.height(for: .intrinsic) re-adds keyboardHeight.
        let bottomAdjustment = self.contentBottomConstraint?.constant ?? 0
        self.contentBottomConstraint?.constant = 0
        self.contentTopConstraint?.isActive = false
        UIView.performWithoutAnimation {
            self.contentView.setNeedsLayout()
            self.contentView.layoutIfNeeded()
        }

        self.preferredHeight = self.contentView.systemLayoutSizeFitting(fittingSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .defaultLow).height
        self.contentTopConstraint?.isActive = true
        self.contentBottomConstraint?.constant = bottomAdjustment
        if extraBottomInset > 0 {
            self.additionalSafeAreaInsets = savedAdditionalInsets
        }
        UIView.performWithoutAnimation {
            self.contentView.setNeedsLayout()
            self.contentView.layoutIfNeeded()
        }

        self.delegate?.preferredHeightChanged(oldHeight: oldPreferredHeight, newHeight: self.preferredHeight)
    }
    
    private func updateChildViewControllerBottomConstraint(adjustment: CGFloat) {
        self.contentBottomConstraint?.constant = adjustment
    }
    
    private func setupChildViewController() {
        self.addChild(self.childViewController)
        let childView = self.childViewController.view!
        self.childContainerView.addSubview(childView)
        childView.translatesAutoresizingMaskIntoConstraints = false
        self.contentBottomConstraint = childView.bottomAnchor.constraint(equalTo: self.childContainerView.bottomAnchor)
        NSLayoutConstraint.activate([
            childView.leftAnchor.constraint(equalTo: self.childContainerView.leftAnchor),
            childView.rightAnchor.constraint(equalTo: self.childContainerView.rightAnchor),
            self.contentBottomConstraint!,
            childView.topAnchor.constraint(equalTo: self.childContainerView.topAnchor)
        ])
        if self.options.shouldExtendBackground, self.options.pullBarHeight > 0 {
            self.childViewController.additionalSafeAreaInsets = UIEdgeInsets(top: self.options.pullBarHeight, left: 0, bottom: 0, right: 0)
        }
        
        self.childViewController.didMove(toParent: self)
        
        self.childContainerView.layer.masksToBounds = true
        self.childContainerView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
    }

    private func setupContentView() {
        self.view.addSubview(self.contentView)
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        self.contentTopConstraint = self.contentView.topAnchor.constraint(equalTo: self.view.topAnchor)
        NSLayoutConstraint.activate([
            self.contentView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            self.contentView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            self.contentView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.contentTopConstraint!
        ])

        self.contentView.addSubview(self.contentWrapperView)
        self.contentWrapperView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.contentWrapperView.leftAnchor.constraint(equalTo: self.contentView.leftAnchor),
            self.contentWrapperView.rightAnchor.constraint(equalTo: self.contentView.rightAnchor),
            self.contentWrapperView.topAnchor.constraint(equalTo: self.contentView.topAnchor),
            self.contentWrapperView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor)
        ])

        self.contentWrapperView.layer.masksToBounds = true
        self.contentWrapperView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]

        self.contentView.addSubview(overflowView)
        overflowView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overflowView.leftAnchor.constraint(equalTo: self.contentView.leftAnchor),
            overflowView.rightAnchor.constraint(equalTo: self.contentView.rightAnchor),
            overflowView.heightAnchor.constraint(equalToConstant: 200),
            overflowView.topAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -1)
        ])
    }
    
    private func setupChildContainerView() {
        self.contentWrapperView.addSubview(self.childContainerView)
        self.childContainerView.translatesAutoresizingMaskIntoConstraints = false
        let containerTop = self.options.shouldExtendBackground
            ? self.childContainerView.topAnchor.constraint(equalTo: self.contentWrapperView.topAnchor)
            : self.childContainerView.topAnchor.constraint(equalTo: self.contentWrapperView.topAnchor, constant: self.options.pullBarHeight)
        NSLayoutConstraint.activate([
            containerTop,
            self.childContainerView.leftAnchor.constraint(equalTo: self.contentWrapperView.leftAnchor),
            self.childContainerView.rightAnchor.constraint(equalTo: self.contentWrapperView.rightAnchor),
            self.childContainerView.bottomAnchor.constraint(equalTo: self.contentWrapperView.bottomAnchor)
        ])
    }
    
    private func setupPullBarView() {
        // If they didn't specify pull bar options, they don't want a pull bar
        guard self.options.pullBarHeight > 0 else { return }
        let pullBarView = self.pullBarView
        pullBarView.isUserInteractionEnabled = true
        pullBarView.backgroundColor = self.pullBarBackgroundColor
        self.contentWrapperView.addSubview(pullBarView)
        pullBarView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pullBarView.topAnchor.constraint(equalTo: self.contentWrapperView.topAnchor),
            pullBarView.leftAnchor.constraint(equalTo: self.contentWrapperView.leftAnchor),
            pullBarView.rightAnchor.constraint(equalTo: self.contentWrapperView.rightAnchor),
            pullBarView.heightAnchor.constraint(equalToConstant: options.pullBarHeight)
        ])
        self.pullBarView = pullBarView
        
        let gripView = self.gripView
        gripView.backgroundColor = self.gripColor
        gripView.layer.cornerRadius = self.gripSize.height / 2
        gripView.layer.masksToBounds = true
        gripView.isHidden = self.isGripHidden
        pullBarView.addSubview(gripView)
        gripView.translatesAutoresizingMaskIntoConstraints = false
        self.gripSizeConstraints.forEach({ $0.isActive = false })
        self.gripSizeConstraints = [
            gripView.widthAnchor.constraint(equalToConstant: self.gripSize.width),
            gripView.heightAnchor.constraint(equalToConstant: self.gripSize.height)
        ]
        NSLayoutConstraint.activate([
            gripView.centerYAnchor.constraint(equalTo: pullBarView.centerYAnchor),
            gripView.centerXAnchor.constraint(equalTo: pullBarView.centerXAnchor)
        ] + self.gripSizeConstraints)
        
        pullBarView.isAccessibilityElement = true
        pullBarView.accessibilityIdentifier = "pull-bar"
        // This will be overriden whenever the sizes property is changed on SheetViewController
        pullBarView.accessibilityLabel = Localize.dismissPresentation.localized
        pullBarView.accessibilityTraits = [.button]
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(pullBarTapped))
        pullBarView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func pullBarTapped(_ gesture: UITapGestureRecognizer) {
        self.delegate?.pullBarTapped()
    }

    @objc func contentSizeDidChange() {
        self.updatePreferredHeight()
    }
}

extension SheetContentViewController {
    func navigationControllerDidShow() {
        self.navigationHeightConstraint?.isActive = true
        self.updatePreferredHeight()
    }
}

/// Forwards `UINavigationControllerDelegate` to the app's original delegate while letting the
/// sheet observe willShow/didShow for keyboard dismissal and intrinsic-height recalculation.
/// Everything else is transparently forwarded via ObjC message forwarding.
final class SheetNavigationDelegateProxy: NSObject, UINavigationControllerDelegate {
    // Accessed from the ObjC-runtime forwarding hooks (nonisolated); UINavigationController only
    // ever calls its delegate on the main thread, so unchecked isolation is safe here.
    nonisolated(unsafe) weak var forwardee: UINavigationControllerDelegate?
    private weak var owner: SheetContentViewController?

    init(forwardee: UINavigationControllerDelegate?, owner: SheetContentViewController) {
        self.forwardee = forwardee
        self.owner = owner
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        navigationController.view.endEditing(true)
        // Recompute intrinsic height at the START of the transition (topViewController is already the
        // incoming VC here) so the sheet resizes IN STEP with the push/pop instead of jumping after it
        // completes. The incoming VC is transiently off-screen with safeAreaInsets == 0, so
        // updateNavigationControllerHeight compensates with the nav content area's top inset to
        // measure the settled height here; didShow re-measures to correct an interactively-cancelled
        // back-swipe (and is a no-op when the height already matches).
        owner?.navigationControllerDidShow()
        forwardee?.navigationController?(navigationController, willShow: viewController, animated: animated)
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        owner?.navigationControllerDidShow()
        forwardee?.navigationController?(navigationController, didShow: viewController, animated: animated)
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        return forwardee?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if forwardee?.responds(to: aSelector) == true { return forwardee }
        return super.forwardingTarget(for: aSelector)
    }
}

#endif // os(iOS)
