//
//  AdaptiveContentDemo.swift
//  FittedSheets
//
//  The flagship showcase for progressive, interactive sheet animation. A Maps-style place browser
//  whose ENTIRE interface is a continuous function of the sheet's live height — every frame, during
//  a drag AND during the animated snap that follows a release, the library's `progressChanged`
//  callback hands us a `SheetHeightProgress` and we redraw the world from it:
//
//   • A live "instrument cluster" renders the exact data the library emits — overall `fraction`, the
//     on-screen `height`, the `reachedIndex`, and each detent's `reveal` as its own moving meter — so
//     you can literally watch the numbers that drive everything else move under your finger.
//   • The header title collapses + recolors, a search bar tints, filter chips slide in.
//   • Place rows rise, scale, slide and un-blur in a staggered cascade toward the "List" detent.
//   • A rich detail card (photo strip, stat tiles, call-to-action) slides + scales up, its children
//     choreographed in sequence, over the "List → Detail" range.
//   • One accent color is interpolated across the whole progress and threaded through every element,
//     so the interface warms from teal → blue → indigo as the sheet grows.
//   • The sheet's own corner radius eases toward fullscreen — chrome driven by the same progress.
//   • The discrete "reached a new detent" event is layered on top as a spring pop + haptic.
//
//  Nothing here cross-fades on a timer and nothing computes detent heights: it all tracks the gesture
//  in lockstep, sourced entirely from the values the library computes.
//

import UIKit
import FittedSheets

class AdaptiveContentDemo: UIViewController, Demoable {
    class var name: String { "Adaptive content per sheet height" }

    // The compact detent is sized so the sheet, at its initial height, shows exactly the full
    // instrument card and nothing else — the title, search field and list all collapse away at this
    // height, so the height only needs to satisfy the card (plus the grip above it).
    fileprivate static let compact: SheetSize = .fixed(220)
    fileprivate static let list: SheetSize = .percent(0.64)
    fileprivate static let detail: SheetSize = .fullscreen

    class func openDemo(from parent: UIViewController, in view: UIView?) {
        let controller = AdaptiveContentViewController()
        var options = SheetOptions()
        options.useInlineMode = view != nil
        let sheet = SheetViewController(
            controller: controller,
            sizes: [compact, list, detail],
            options: options)
        sheet.cornerRadius = 22
        sheet.gripColor = UIColor.systemGray3

        // Everything — the interactive cascade AND the discrete "reached detent" — is driven from
        // the live height every frame, so content reacts the instant the sheet crosses a defined
        // detent height mid-drag, without waiting for the finger to be released.
        sheet.progressChanged = { [weak controller] _, progress in
            controller?.apply(progress)
        }
        addSheetEventLogging(to: sheet)

        if let view = view {
            sheet.animateIn(to: view, in: parent)
        } else {
            parent.present(sheet, animated: true, completion: nil)
        }
    }
}

/// Content whose every transform, opacity, color and label is a continuous function of the sheet's
/// live height, sourced entirely from the `SheetHeightProgress` the library delivers each frame.
class AdaptiveContentViewController: UIViewController {

    // MARK: Fixed header
    private var headerStack: UIStackView!
    private let titleLabel = UILabel()
    private let titleUnderline = UIView()
    private let searchBar = UIView()
    private let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
    private let filterIcon = UIImageView(image: UIImage(systemName: "slider.horizontal.3"))
    /// Title & search heights, driven 0 → full: at the compact height both collapse away so ONLY the
    /// instrument card shows; they grow in as the sheet is opened.
    private var titleHeight: NSLayoutConstraint!
    private var titleNaturalHeight: CGFloat = 40
    private var searchHeight: NSLayoutConstraint!

    // MARK: Live instrument cluster (renders the library's data structure)
    private let panel = UIView()
    private let liveDot = UIView()
    private let panelCaption = UILabel()
    private let reachedPill = PaddedLabel()
    private let fractionValueLabel = UILabel()
    private let heightLabel = UILabel()
    private let fractionBar = BarView(thickness: 8)
    private var stepMeters: [MeterBar] = []

    // MARK: Scrollable body
    private let scrollView = UIScrollView()
    private let chipsScroll = UIScrollView()
    private let chipsRow = UIStackView()
    private var chips: [ChipView] = []
    private let sectionHeader = UILabel()
    private let listSection = UIStackView()
    private var rowViews: [PlaceRowView] = []

    // MARK: Detail card
    private let detailSection = UIView()
    private let photoScroll = UIScrollView()
    private var photoTiles: [GradientTile] = []
    private var statTiles: [UIView] = []
    private let ctaRow = UIStackView()
    private let directionsButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let blurb = UILabel()

    private var didRegisterScrollView = false

    /// Display names for the sheet's detents (smallest → largest), indexed by the reached step.
    private let stepNames = ["Peek", "List", "Detail"]
    /// Tracks the last reported detent so the discrete "reached a new detent" pop fires exactly once
    /// per crossing, layered on top of the continuous animation.
    private var lastReachedIndex = -1
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private let places: [(name: String, category: String, distance: String, color: UIColor)] = [
        ("Blue Bottle Coffee", "Coffee · ☕️", "120 m", Palette.terracotta),
        ("Riverside Park", "Park · 🌳", "300 m", Palette.sage),
        ("City Museum", "Culture · 🏛", "450 m", Palette.violet),
        ("Harbor Viewpoint", "Scenic · 🌊", "600 m", Palette.ocean),
        ("Night Market", "Food · 🍜", "800 m", Palette.amber),
        ("Central Library", "Study · 📚", "950 m", Palette.periwinkle),
        ("Botanical Garden", "Park · 🌺", "1.1 km", Palette.rose),
        ("Old Town Bakery", "Food · 🥐", "1.3 km", Palette.gold),
        ("Skyline Rooftop", "Bar · 🍸", "1.6 km", Palette.coral),
        ("Ferry Terminal", "Transit · ⛴", "2.0 km", Palette.sky)
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        self.haptic.prepare()

        buildHeader()
        buildInstrumentPanel()
        buildBody()
        layoutRoot()

        if let sheet = self.sheetViewController { apply(sheet.currentProgress) } // pre-appearance state
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        if !didRegisterScrollView, let sheet = self.sheetViewController {
            sheet.handleScrollView(scrollView)
            didRegisterScrollView = true
        }
        if let sheet = self.sheetViewController { apply(sheet.currentProgress) }
    }

    // MARK: - The interactive cascade

    /// The one place all content is redrawn. Every value it reads comes from the LIBRARY's
    /// `SheetHeightProgress` — `fraction`, `height`, `reachedIndex`, and each `steps[i].reveal`; it
    /// never computes a detent height itself.
    func apply(_ progress: SheetHeightProgress) {
        let fraction = progress.fraction
        let listReveal = progress.steps.count > 1 ? progress.steps[1].reveal : 1     // Peek → List
        let detailReveal = progress.steps.count > 2 ? progress.steps[2].reveal : 0   // List → Detail
        let accent = Accent.color(for: fraction)

        applyDisclosure(listReveal: listReveal)
        applyHeader(fraction: fraction, accent: accent)
        applyInstrumentPanel(progress: progress, accent: accent)
        applyChips(listReveal: listReveal, accent: accent)
        applyRows(listReveal: listReveal, accent: accent)
        applyDetail(detailReveal: detailReveal, accent: accent)

        // Sheet chrome is driven by the same progress too — even the parts the library owns:
        //  • the corners ease flat as it approaches fullscreen,
        //  • the grip widens and warms toward the accent as the sheet grows,
        //  • the dimmed backdrop deepens as the sheet climbs, so the whole world responds to the drag.
        if let sheet = self.sheetViewController {
            sheet.cornerRadius = lerp(22, 6, detailReveal)
            sheet.gripColor = mix(.systemGray3, accent, fraction * 0.85)
            sheet.gripSize = CGSize(width: lerp(36, 52, fraction), height: 6)
            sheet.overlayColor = UIColor(white: 0, alpha: lerp(0.16, 0.5, fraction))
        }
    }

    /// Progressive disclosure keyed to the Peek → List reveal. At the compact height the title and
    /// search field are fully collapsed (zero height) so ONLY the always-full instrument card shows;
    /// as the sheet is pulled up they grow back in — height, spacing and opacity together — pushing the
    /// card down into its normal place as the rest of the list cascades in below.
    private func applyDisclosure(listReveal: CGFloat) {
        // Title: collapsed at the compact height, first thing to grow back as the sheet opens.
        let titleReveal = clamp01(listReveal / 0.5)
        titleHeight.constant = titleNaturalHeight * titleReveal
        titleLabel.alpha = clamp01(titleReveal * 1.6)

        // Search field: collapsed at the compact height, grows in just after the title.
        let searchReveal = clamp01((listReveal - 0.1) / 0.5)
        searchHeight.constant = 44 * searchReveal
        searchBar.alpha = clamp01(searchReveal * 1.4)

        // Collapse the stack spacing around both so the card sits flush at the top when they're hidden.
        headerStack.setCustomSpacing(lerp(0, 10, titleReveal), after: titleLabel)
        headerStack.setCustomSpacing(lerp(0, 12, searchReveal), after: searchBar)
    }

    private func applyHeader(fraction: CGFloat, accent: UIColor) {
        // The large title collapses toward a compact size as it grows.
        let titleScale = lerp(1.0, 0.86, fraction)
        titleLabel.transform = CGAffineTransform(scaleX: titleScale, y: titleScale)
        // Deepen the accent toward the primary text color so the big title reads as a rich, refined
        // tone that still shifts with the sheet — rather than a loud, fully-saturated hue.
        titleLabel.textColor = mix(accent, .label, 0.3)

        // An accent underline unfurls from the title's left edge, its width tracking the fraction.
        let underlineWidth: CGFloat = 120
        titleUnderline.transform = CGAffineTransform(translationX: -underlineWidth * (1 - fraction) / 2, y: 0)
            .scaledBy(x: max(0.0001, fraction), y: 1)
        titleUnderline.backgroundColor = accent

        // The search field tints and morphs from a pill toward a rounded rect as the sheet grows.
        // (Its collapse/reveal — height + opacity — is handled in applyDisclosure.)
        searchBar.layer.borderColor = accent.withAlphaComponent(0.22).cgColor
        searchBar.layer.cornerRadius = lerp(22, 14, fraction)
        searchBar.backgroundColor = mix(.secondarySystemBackground, accent, 0.06 * fraction)
        searchIcon.tintColor = accent

        // A filter affordance slides in from the right as the field grows toward the list.
        let filterReveal = clamp01((fraction - 0.15) / 0.3)
        filterIcon.transform = CGAffineTransform(translationX: (1 - filterReveal) * 12, y: 0)
        filterIcon.tintColor = accent
    }

    private func applyInstrumentPanel(progress: SheetHeightProgress, accent: UIColor) {
        panel.layer.borderColor = accent.withAlphaComponent(0.18).cgColor
        liveDot.backgroundColor = accent
        // The panel itself lifts on a deepening shadow as the sheet grows.
        let f = clamp01(progress.fraction)
        panel.layer.shadowOpacity = Float(lerp(0.04, 0.13, f))
        panel.layer.shadowRadius = lerp(10, 20, f)
        panel.layer.shadowOffset = CGSize(width: 0, height: lerp(4, 10, f))
        fractionValueLabel.text = "\(Int((progress.fraction * 100).rounded()))%"
        fractionValueLabel.textColor = accent
        heightLabel.text = "· \(Int(progress.height.rounded())) pt"
        fractionBar.set(progress.fraction, accent: accent)

        for (index, meter) in stepMeters.enumerated() {
            let reveal = progress.steps.indices.contains(index) ? progress.steps[index].reveal : 0
            meter.set(progress: reveal, accent: accent, highlighted: index == progress.reachedIndex)
        }

        let reached = stepNames.indices.contains(progress.reachedIndex) ? stepNames[progress.reachedIndex] : "Custom"
        reachedPill.text = "reached · \(reached)"
        reachedPill.backgroundColor = accent

        // Discrete detent crossing, reported by the library, layered on the continuous motion: a
        // spring pop + haptic the instant `reachedIndex` changes (skipping the initial seed).
        if progress.reachedIndex != lastReachedIndex {
            if lastReachedIndex >= 0 {
                reachedPill.transform = CGAffineTransform(scaleX: 1.18, y: 1.18)
                UIView.animate(withDuration: 0.34, delay: 0, usingSpringWithDamping: 0.5,
                               initialSpringVelocity: 0.6, options: [.allowUserInteraction]) {
                    self.reachedPill.transform = .identity
                }
                haptic.impactOccurred()
                haptic.prepare()
            }
            lastReachedIndex = progress.reachedIndex
        }
    }

    private func applyChips(listReveal: CGFloat, accent: UIColor) {
        // The section header rises + scales up as it fades in, rather than a flat cross-fade.
        let headerReveal = clamp01(listReveal * 1.6)
        sectionHeader.alpha = headerReveal
        let headerScale = lerp(0.92, 1.0, headerReveal)
        sectionHeader.transform = CGAffineTransform(translationX: 0, y: (1 - headerReveal) * 10)
            .scaledBy(x: headerScale, y: headerScale)

        let count = max(1, chips.count)
        for (index, chip) in chips.enumerated() {
            let start = (CGFloat(index) / CGFloat(count)) * 0.5   // stagger left → right
            let p = clamp01((listReveal - start) / 0.5)
            chip.alpha = clamp01(p * 2)
            // Each chip now slides AND scales up from a slightly shrunken state as it settles.
            let scale = lerp(0.82, 1.0, p)
            chip.transform = CGAffineTransform(translationX: (1 - p) * 26, y: 0).scaledBy(x: scale, y: scale)
            chip.setSelected(index == 0, accent: accent)
        }
    }

    private func applyRows(listReveal: CGFloat, accent: UIColor) {
        // Rows rise + scale + slide into place, staggered so they cascade in as the sheet grows to
        // the List detent. Each row's own subtitle and chevron un-blur slightly later than its body.
        let count = max(1, rowViews.count)
        for (index, row) in rowViews.enumerated() {
            let start = (CGFloat(index) / CGFloat(count)) * 0.55    // stagger across the range
            let rowProgress = clamp01((listReveal - start) / 0.45)  // each reveals over 45%
            row.apply(progress: rowProgress, accent: accent)
        }
    }

    private func applyDetail(detailReveal: CGFloat, accent: UIColor) {
        // The whole detail card slides up + fades over the List → Detail range, rounding its corners
        // a touch more as it lifts into place.
        detailSection.alpha = clamp01(detailReveal * 2.2)
        detailSection.transform = CGAffineTransform(translationX: 0, y: (1 - detailReveal) * 44)
        detailSection.layer.cornerRadius = lerp(26, 20, detailReveal)

        // The photo strip parallaxes: its contents drift into place from the right as the card reveals,
        // so the strip feels like it's catching up with the sheet. (Left alone once fully settled so it
        // stays under the user's own scrolling.)
        if detailReveal < 0.999 {
            photoScroll.contentOffset.x = (1 - detailReveal) * 44
        }

        // …while its children are choreographed in sequence within that range: photos first, then the
        // stat tiles, then the call-to-action, then the blurb — so the card assembles itself as the
        // sheet approaches fullscreen rather than appearing all at once.
        let photoCount = max(1, photoTiles.count)
        for (index, tile) in photoTiles.enumerated() {
            let start = (CGFloat(index) / CGFloat(photoCount)) * 0.5
            let p = clamp01((detailReveal - start) / 0.5)
            let scale = lerp(0.8, 1.0, p)
            tile.alpha = clamp01(p * 2)
            tile.transform = CGAffineTransform(translationX: 0, y: (1 - p) * 24).scaledBy(x: scale, y: scale)
        }
        for (index, tile) in statTiles.enumerated() {
            let start = 0.3 + CGFloat(index) * 0.12
            let p = clamp01((detailReveal - start) / 0.35)
            let scale = lerp(0.8, 1.0, p)
            tile.alpha = clamp01(p * 2)
            // Stat tiles now rise as they scale, matching the language of the rows above.
            tile.transform = CGAffineTransform(translationX: 0, y: (1 - p) * 16).scaledBy(x: scale, y: scale)
        }
        let ctaP = clamp01((detailReveal - 0.5) / 0.5)
        ctaRow.alpha = clamp01(ctaP * 2)
        ctaRow.transform = CGAffineTransform(translationX: 0, y: (1 - ctaP) * 26)
        directionsButton.backgroundColor = accent
        saveButton.setTitleColor(accent, for: .normal)
        saveButton.backgroundColor = accent.withAlphaComponent(0.14)

        // The blurb is the last thing to arrive — it fades + rises in only over the final stretch.
        let blurbP = clamp01((detailReveal - 0.65) / 0.35)
        blurb.alpha = blurbP
        blurb.transform = CGAffineTransform(translationX: 0, y: (1 - blurbP) * 14)
    }

    // MARK: - Construction

    private func buildHeader() {
        titleLabel.text = "Explore"
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.clipsToBounds = true   // clip cleanly while the title collapses at the compact height
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleNaturalHeight = ceil(titleLabel.intrinsicContentSize.height)
        // Driven 0 → natural: the title is fully collapsed at the compact height and grows in.
        titleHeight = titleLabel.heightAnchor.constraint(equalToConstant: 0)
        titleHeight.isActive = true

        searchBar.backgroundColor = .secondarySystemBackground
        searchBar.layer.cornerRadius = 14
        searchBar.layer.cornerCurve = .continuous
        searchBar.layer.borderWidth = 1
        searchBar.clipsToBounds = true   // so the field's contents clip cleanly while it collapses
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        // Height is driven 0 → 44: the field is fully collapsed at the minimum height and grows in.
        searchHeight = searchBar.heightAnchor.constraint(equalToConstant: 0)
        searchHeight.isActive = true

        searchIcon.contentMode = .scaleAspectFit
        searchIcon.setContentHuggingPriority(.required, for: .horizontal)
        let searchText = UILabel()
        searchText.text = "Search places nearby"
        searchText.font = .preferredFont(forTextStyle: .subheadline)
        searchText.textColor = .secondaryLabel
        let searchStack = UIStackView(arrangedSubviews: [searchIcon, searchText])
        searchStack.axis = .horizontal
        searchStack.spacing = 8
        searchStack.alignment = .center
        searchStack.isUserInteractionEnabled = false
        searchStack.translatesAutoresizingMaskIntoConstraints = false
        searchBar.addSubview(searchStack)

        // A "filter" affordance that reveals itself as the sheet expands toward the list.
        filterIcon.contentMode = .scaleAspectFit
        filterIcon.translatesAutoresizingMaskIntoConstraints = false
        filterIcon.setContentHuggingPriority(.required, for: .horizontal)
        filterIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        searchBar.addSubview(filterIcon)

        NSLayoutConstraint.activate([
            searchStack.leadingAnchor.constraint(equalTo: searchBar.leadingAnchor, constant: 12),
            searchStack.trailingAnchor.constraint(lessThanOrEqualTo: filterIcon.leadingAnchor, constant: -8),
            searchStack.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 18),
            filterIcon.trailingAnchor.constraint(equalTo: searchBar.trailingAnchor, constant: -14),
            filterIcon.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            filterIcon.widthAnchor.constraint(equalToConstant: 19)
        ])
    }

    /// The live instrument cluster: a bordered card that renders the exact `SheetHeightProgress` the
    /// library emits — the overall fraction, the on-screen height, the reached detent, and one moving
    /// meter per detent showing its `reveal`. It is the "watch the data drive the UI" centerpiece.
    private func buildInstrumentPanel() {
        panel.backgroundColor = .secondarySystemBackground
        panel.layer.cornerRadius = 18
        panel.layer.cornerCurve = .continuous
        panel.layer.borderWidth = 1
        panel.translatesAutoresizingMaskIntoConstraints = false
        // A soft, low elevation lifts the card off the sheet without the old heavy frame.
        panel.layer.shadowColor = UIColor.black.cgColor
        panel.layer.shadowOpacity = 0.05
        panel.layer.shadowRadius = 14
        panel.layer.shadowOffset = CGSize(width: 0, height: 6)

        // A small pulsing dot signals the readout is live under your finger.
        liveDot.layer.cornerRadius = 3.5
        liveDot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            liveDot.widthAnchor.constraint(equalToConstant: 7),
            liveDot.heightAnchor.constraint(equalToConstant: 7)
        ])

        panelCaption.text = "SheetHeightProgress · live"
        panelCaption.font = .systemFont(ofSize: 11, weight: .semibold)
        panelCaption.textColor = .secondaryLabel
        panelCaption.adjustsFontSizeToFitWidth = true
        panelCaption.setContentHuggingPriority(.defaultLow, for: .horizontal)

        reachedPill.font = .systemFont(ofSize: 11, weight: .bold)
        reachedPill.textColor = .white
        reachedPill.textInsets = UIEdgeInsets(top: 3, left: 9, bottom: 3, right: 9)
        reachedPill.layer.cornerRadius = 9
        reachedPill.layer.cornerCurve = .continuous
        reachedPill.layer.masksToBounds = true
        reachedPill.setContentHuggingPriority(.required, for: .horizontal)

        // Head row — the big live percentage on the left, the reached-detent pill pushed to the right.
        fractionValueLabel.font = .monospacedDigitSystemFont(ofSize: 30, weight: .heavy)
        fractionValueLabel.setContentHuggingPriority(.required, for: .horizontal)
        let headSpacer = UIView()
        headSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let headRow = UIStackView(arrangedSubviews: [fractionValueLabel, headSpacer, reachedPill])
        headRow.axis = .horizontal
        headRow.spacing = 8
        headRow.alignment = .center

        // Caption line: live dot + label + on-screen height.
        heightLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        heightLabel.textColor = .secondaryLabel
        heightLabel.setContentHuggingPriority(.required, for: .horizontal)
        let captionRow = UIStackView(arrangedSubviews: [liveDot, panelCaption, heightLabel])
        captionRow.axis = .horizontal
        captionRow.spacing = 6
        captionRow.alignment = .center

        // One meter per detent, showing that step's live `reveal`. The reached step lights up.
        let metersRow = UIStackView()
        metersRow.axis = .horizontal
        metersRow.spacing = 12
        metersRow.distribution = .fillEqually
        for name in stepNames {
            let meter = MeterBar(caption: name)
            stepMeters.append(meter)
            metersRow.addArrangedSubview(meter)
        }

        // The card is always shown in full — it is the whole point of the compact state — so it is a
        // single flat stack: percentage + pill, the fraction bar, the caption line, then the meters.
        let panelStack = UIStackView(arrangedSubviews: [headRow, fractionBar, captionRow, metersRow])
        panelStack.axis = .vertical
        panelStack.spacing = 10
        panelStack.setCustomSpacing(12, after: fractionBar)
        panelStack.setCustomSpacing(8, after: captionRow)
        panelStack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(panelStack)
        NSLayoutConstraint.activate([
            panelStack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12),
            panelStack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12),
            panelStack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            panelStack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14)
        ])
    }

    private func buildBody() {
        // Filter chips (horizontally scrollable) cascade in toward the List detent.
        for title in ["All", "Coffee ☕️", "Parks 🌳", "Food 🍜", "Views 🌊", "Culture 🏛"] {
            let chip = ChipView(title: title)
            chips.append(chip)
            chipsRow.addArrangedSubview(chip)
        }
        chipsRow.axis = .horizontal
        chipsRow.spacing = 8
        chipsRow.translatesAutoresizingMaskIntoConstraints = false
        chipsScroll.showsHorizontalScrollIndicator = false
        chipsScroll.translatesAutoresizingMaskIntoConstraints = false
        chipsScroll.addSubview(chipsRow)
        NSLayoutConstraint.activate([
            chipsRow.topAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.topAnchor),
            chipsRow.bottomAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.bottomAnchor),
            chipsRow.leadingAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.leadingAnchor),
            chipsRow.trailingAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.trailingAnchor),
            chipsRow.heightAnchor.constraint(equalTo: chipsScroll.frameLayoutGuide.heightAnchor)
        ])
        let chipsHeight = chipsScroll.heightAnchor.constraint(equalToConstant: 34)
        chipsHeight.priority = .required
        chipsHeight.isActive = true

        sectionHeader.text = "\(places.count) places nearby"
        sectionHeader.font = .preferredFont(forTextStyle: .headline)
        sectionHeader.adjustsFontForContentSizeCategory = true

        listSection.axis = .vertical
        listSection.spacing = 10
        for (index, place) in places.enumerated() {
            let row = PlaceRowView(rank: index + 1, name: place.name, category: place.category,
                                   distance: place.distance, color: place.color)
            rowViews.append(row)
            listSection.addArrangedSubview(row)
        }

        buildDetailSection()

        let body = UIStackView(arrangedSubviews: [chipsScroll, sectionHeader, listSection, detailSection])
        body.axis = .vertical
        body.spacing = 16
        body.setCustomSpacing(10, after: chipsScroll)
        body.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = true
        scrollView.addSubview(body)

        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            body.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            body.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            body.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20)
        ])
    }

    private func layoutRoot() {
        let header = UIStackView(arrangedSubviews: [titleLabel, searchBar, panel])
        header.axis = .vertical
        header.spacing = 12
        header.setCustomSpacing(10, after: titleLabel)
        header.translatesAutoresizingMaskIntoConstraints = false
        headerStack = header

        self.view.addSubview(header)
        self.view.addSubview(scrollView)

        // An accent underline that grows out from under the title in lockstep with the sheet height.
        titleUnderline.layer.cornerRadius = 1.5
        titleUnderline.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(titleUnderline)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20),

            titleUnderline.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor, constant: 1),
            titleUnderline.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            titleUnderline.widthAnchor.constraint(equalToConstant: 120),
            titleUnderline.heightAnchor.constraint(equalToConstant: 3),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
    }

    private func buildDetailSection() {
        detailSection.backgroundColor = .secondarySystemBackground
        detailSection.layer.cornerRadius = 20
        detailSection.layer.cornerCurve = .continuous
        detailSection.layer.shadowColor = UIColor.black.cgColor
        detailSection.layer.shadowOpacity = 0.06
        detailSection.layer.shadowRadius = 16
        detailSection.layer.shadowOffset = CGSize(width: 0, height: 8)

        let title = UILabel()
        title.text = "Harbor Viewpoint"
        title.font = .preferredFont(forTextStyle: .title2)
        title.adjustsFontForContentSizeCategory = true
        let subtitle = UILabel()
        subtitle.text = "Scenic overlook · Open until 9 PM"
        subtitle.font = .preferredFont(forTextStyle: .subheadline)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0

        // Photo strip — colored gradient tiles that scale/fade in first.
        let photoStack = UIStackView()
        photoStack.axis = .horizontal
        photoStack.spacing = 10
        let photoColors: [(UIColor, String)] = [
            (Accent.peek, "Bay"), (Palette.ocean, "Pier"), (Accent.list, "Dusk"),
            (Palette.violet, "City"), (Accent.detail, "Sunset")
        ]
        for (color, caption) in photoColors {
            let tile = GradientTile(top: color, bottom: mix(color, .black, 0.35), caption: caption)
            photoTiles.append(tile)
            photoStack.addArrangedSubview(tile)
        }
        photoScroll.showsHorizontalScrollIndicator = false
        photoScroll.translatesAutoresizingMaskIntoConstraints = false
        photoStack.translatesAutoresizingMaskIntoConstraints = false
        photoScroll.addSubview(photoStack)
        NSLayoutConstraint.activate([
            photoStack.topAnchor.constraint(equalTo: photoScroll.contentLayoutGuide.topAnchor),
            photoStack.bottomAnchor.constraint(equalTo: photoScroll.contentLayoutGuide.bottomAnchor),
            photoStack.leadingAnchor.constraint(equalTo: photoScroll.contentLayoutGuide.leadingAnchor),
            photoStack.trailingAnchor.constraint(equalTo: photoScroll.contentLayoutGuide.trailingAnchor),
            photoStack.heightAnchor.constraint(equalTo: photoScroll.frameLayoutGuide.heightAnchor),
            photoScroll.heightAnchor.constraint(equalToConstant: 96)
        ])

        // Stat tiles — pop in next.
        let statRow = UIStackView()
        statRow.axis = .horizontal
        statRow.spacing = 10
        statRow.distribution = .fillEqually
        for (value, caption) in [("4.8 ★", "Rating"), ("600 m", "Away"), ("Open", "Now")] {
            let tile = statTile(value: value, caption: caption)
            statTiles.append(tile)
            statRow.addArrangedSubview(tile)
        }

        // Call-to-action — slides up last.
        configureCTAButton(directionsButton, title: "Get Directions", filled: true)
        configureCTAButton(saveButton, title: "Save", filled: false)
        directionsButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        saveButton.widthAnchor.constraint(equalToConstant: 96).isActive = true
        ctaRow.addArrangedSubview(directionsButton)
        ctaRow.addArrangedSubview(saveButton)
        ctaRow.axis = .horizontal
        ctaRow.spacing = 10
        ctaRow.distribution = .fill

        blurb.numberOfLines = 0
        blurb.font = .preferredFont(forTextStyle: .callout)
        blurb.textColor = .secondaryLabel
        blurb.adjustsFontForContentSizeCategory = true
        blurb.text = "This whole card is choreographed from a single number — the sheet's height. "
            + "As you pull toward fullscreen, the library reports the List→Detail reveal every frame "
            + "and each element above sequences in from it. Release anywhere: the same callback fires "
            + "through the snap, so the content settles in lockstep with the sheet."

        let stack = UIStackView(arrangedSubviews: [title, subtitle, photoScroll, statRow, ctaRow, blurb])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(6, after: title)
        stack.translatesAutoresizingMaskIntoConstraints = false
        detailSection.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: detailSection.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: detailSection.bottomAnchor, constant: -18),
            stack.leadingAnchor.constraint(equalTo: detailSection.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: detailSection.trailingAnchor, constant: -16)
        ])
    }

    private func statTile(value: String, caption: String) -> UIView {
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 17, weight: .bold)
        valueLabel.textAlignment = .center
        let captionLabel = UILabel()
        captionLabel.text = caption
        captionLabel.font = .systemFont(ofSize: 12, weight: .medium)
        captionLabel.textColor = .secondaryLabel
        captionLabel.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let card = UIView()
        card.backgroundColor = .tertiarySystemBackground
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor)
        ])
        return card
    }

    private func configureCTAButton(_ button: UIButton, title: String, filled: Bool) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 14
        button.layer.cornerCurve = .continuous
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.translatesAutoresizingMaskIntoConstraints = false
        if filled { button.setTitleColor(.white, for: .normal) }
        button.addAction(UIAction { _ in print("CTA tapped: \(title)") }, for: .touchUpInside)
    }
}

// MARK: - Progress math helpers

private func clamp01(_ x: CGFloat) -> CGFloat { min(1, max(0, x)) }
private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * clamp01(t) }

/// Convenience for authoring the curated palette in familiar 0–255 sRGB.
private func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
    UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}

/// Linearly interpolate between two colors, resolving each into its RGBA components first.
private func mix(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
    var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
    var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
    a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
    b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
    let k = clamp01(t)
    return UIColor(red: ar + (br - ar) * k, green: ag + (bg - ag) * k,
                   blue: ab + (bb - ab) * k, alpha: aa + (ba - aa) * k)
}

/// The single accent color threaded through the whole interface, interpolated across the overall
/// progress: teal at the smallest detent, warming through blue to indigo at fullscreen.
private enum Accent {
    // A curated cool ramp — refined teal → cobalt → violet — threaded through every element.
    // Deliberately a touch desaturated from the raw system colors so it reads elegant, not neon.
    static let peek   = rgb(20, 184, 174)   // teal
    static let list   = rgb(64, 110, 230)   // cobalt
    static let detail = rgb(114, 88, 232)   // violet

    static func color(for fraction: CGFloat) -> UIColor {
        let f = clamp01(fraction)
        return f < 0.5
            ? mix(peek, list, f / 0.5)
            : mix(list, detail, (f - 0.5) / 0.5)
    }
}

/// A harmonious, muted set of category accents for the place list — curated so the rows read as one
/// cohesive palette rather than a raw system-color rainbow. Rendered as soft *tonal* badges.
private enum Palette {
    static let terracotta = rgb(214, 132, 92)
    static let sage       = rgb(74, 166, 133)
    static let violet     = rgb(139, 122, 214)
    static let ocean      = rgb(58, 164, 196)
    static let amber      = rgb(224, 154, 82)
    static let periwinkle = rgb(104, 122, 220)
    static let rose       = rgb(216, 110, 158)
    static let gold       = rgb(210, 162, 74)
    static let coral      = rgb(226, 106, 106)
    static let sky        = rgb(80, 141, 232)
}

// MARK: - Reusable views

/// A UILabel with content insets, used for the pill badges.
private final class PaddedLabel: UILabel {
    var textInsets: UIEdgeInsets = .zero { didSet { invalidateIntrinsicContentSize() } }
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: textInsets)) }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                      height: size.height + textInsets.top + textInsets.bottom)
    }
}

/// A thin rounded progress track with a colored fill whose width is set every frame from a 0…1 value.
private final class BarView: UIView {
    private let fill = UIView()
    private var fillWidth: NSLayoutConstraint!

    init(thickness: CGFloat) {
        super.init(frame: .zero)
        backgroundColor = .tertiarySystemFill
        layer.cornerRadius = thickness / 2
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: thickness).isActive = true
        fill.layer.cornerRadius = thickness / 2
        fill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fill)
        fillWidth = fill.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: leadingAnchor),
            fill.topAnchor.constraint(equalTo: topAnchor),
            fill.bottomAnchor.constraint(equalTo: bottomAnchor),
            fillWidth
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func set(_ progress: CGFloat, accent: UIColor) {
        fillWidth.constant = bounds.width * clamp01(progress)
        fill.backgroundColor = accent
    }
}

/// A captioned meter — a label + live percentage over a `BarView` — used to render each detent's
/// `reveal` in the instrument cluster. Lights up (accent fill, bold caption) when it is the reached
/// detent.
private final class MeterBar: UIView {
    private let captionLabel = UILabel()
    private let valueLabel = UILabel()
    private let bar = BarView(thickness: 5)

    init(caption: String) {
        super.init(frame: .zero)
        captionLabel.text = caption
        captionLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        captionLabel.textColor = .secondaryLabel
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        valueLabel.textColor = .tertiaryLabel
        valueLabel.textAlignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let head = UIStackView(arrangedSubviews: [captionLabel, valueLabel])
        head.axis = .horizontal
        head.alignment = .firstBaseline

        let stack = UIStackView(arrangedSubviews: [head, bar])
        stack.axis = .vertical
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func set(progress: CGFloat, accent: UIColor, highlighted: Bool) {
        let p = clamp01(progress)
        bar.set(p, accent: highlighted ? accent : .systemGray3)
        valueLabel.text = "\(Int((p * 100).rounded()))%"
        captionLabel.textColor = highlighted ? accent : .secondaryLabel
        captionLabel.font = .systemFont(ofSize: 12, weight: highlighted ? .bold : .semibold)
        valueLabel.textColor = highlighted ? .label : .tertiaryLabel
    }
}

/// A rounded filter chip whose selected fill tracks the live accent color.
private final class ChipView: UIView {
    private let label = UILabel()

    init(title: String) {
        super.init(frame: .zero)
        label.text = title
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 15
        layer.cornerCurve = .continuous
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSelected(_ selected: Bool, accent: UIColor) {
        // Selected: solid accent. Unselected: a soft tonal wash of the same accent so the whole row
        // reads as one family rather than gray-on-gray.
        backgroundColor = selected ? accent : accent.withAlphaComponent(0.10)
        label.textColor = selected ? .white : accent
    }
}

/// One place row: a colored rank badge, a title with a subtitle that un-blurs slightly later, and a
/// chevron that slides in from the right. Its whole `apply(progress:accent:)` is a function of the
/// staggered reveal the parent hands it.
private final class PlaceRowView: UIView {
    private let index: Int
    private let color: UIColor
    private let rankBadge = PaddedLabel()
    private let subtitle = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

    init(rank: Int, name: String, category: String, distance: String, color: UIColor) {
        self.index = rank - 1
        self.color = color
        super.init(frame: .zero)

        rankBadge.text = "\(rank)"
        rankBadge.font = .systemFont(ofSize: 15, weight: .bold)
        // Tonal treatment: a soft wash of the category color with the numeral in the full color,
        // deepened slightly for contrast. Reads far more elegant than a saturated filled disc.
        rankBadge.textColor = mix(color, .black, 0.18)
        rankBadge.textAlignment = .center
        rankBadge.backgroundColor = color.withAlphaComponent(0.16)
        rankBadge.layer.cornerRadius = 10
        rankBadge.layer.cornerCurve = .continuous
        rankBadge.layer.masksToBounds = true
        rankBadge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rankBadge.widthAnchor.constraint(equalToConstant: 34),
            rankBadge.heightAnchor.constraint(equalToConstant: 34)
        ])

        let titleLabel = UILabel()
        titleLabel.text = name
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitle.text = "\(category)  ·  \(distance)"
        subtitle.font = .preferredFont(forTextStyle: .caption1)
        subtitle.textColor = .secondaryLabel
        subtitle.adjustsFontForContentSizeCategory = true

        let titles = UIStackView(arrangedSubviews: [titleLabel, subtitle])
        titles.axis = .vertical
        titles.spacing = 1
        titles.setContentHuggingPriority(.defaultLow, for: .horizontal)

        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)

        let row = UIStackView(arrangedSubviews: [rankBadge, titles, chevron])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(progress p: CGFloat, accent: UIColor) {
        let scale = lerp(0.7, 1.0, p)
        let translateY = (1 - p) * 28
        let translateX = CGFloat(index.isMultiple(of: 2) ? -1 : 1) * (1 - p) * 10
        alpha = clamp01(p * 2.2)                         // opaque well before it settles
        transform = CGAffineTransform(translationX: translateX, y: translateY).scaledBy(x: scale, y: scale)
        // The subtitle and chevron trail the row body, un-blurring slightly later.
        subtitle.alpha = clamp01((p - 0.45) / 0.45)
        let chevronP = clamp01((p - 0.6) / 0.4)
        chevron.alpha = chevronP
        chevron.transform = CGAffineTransform(translationX: (1 - chevronP) * 8, y: 0)
        chevron.tintColor = accent

        // The rank badge gets its own secondary life: it overshoots then settles, and its tonal wash
        // deepens as the row locks into place — a small motion layered on the row's overall cascade.
        let badgeP = clamp01((p - 0.35) / 0.65)
        let badgeScale = lerp(1.15, 1.0, badgeP)
        rankBadge.transform = CGAffineTransform(scaleX: badgeScale, y: badgeScale)
        rankBadge.backgroundColor = color.withAlphaComponent(lerp(0.10, 0.18, badgeP))
    }
}

/// A gradient thumbnail tile with a caption, for the detail card's photo strip. Redraws its gradient
/// to fill its bounds on every layout pass.
private final class GradientTile: UIView {
    private let gradient = CAGradientLayer()

    init(top: UIColor, bottom: UIColor, caption: String) {
        super.init(frame: .zero)
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        gradient.colors = [top.cgColor, bottom.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradient, at: 0)

        let label = UILabel()
        label.text = caption
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 132),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}
