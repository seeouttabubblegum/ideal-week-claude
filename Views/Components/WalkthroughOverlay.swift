//
//  WalkthroughOverlay.swift
//  The Ideal Week
//
//  The guided tours are drawn ON the real screen: the page dims, the control
//  being explained stays lit, and a raised card sits beside it.
//
//  A view says "this is me" with `.walkthroughSpot(_:)`; the screen hosting the
//  tour adds `.walkthroughHost(coordinator)` once, at its root. Sheets need
//  their own host — an overlay on the list cannot reach over a sheet.
//

import SwiftUI

/// Collects the on-screen rectangle of every marked view.
struct WalkthroughAnchorKey: PreferenceKey {
    static var defaultValue: [WalkthroughSpot: Anchor<CGRect>] = [:]

    static func reduce(value: inout [WalkthroughSpot: Anchor<CGRect>],
                       nextValue: () -> [WalkthroughSpot: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, latest in latest }
    }
}

extension View {
    /// Marks this view as the thing a walkthrough step points at.
    ///
    /// `transformAnchorPreference`, not `anchorPreference`: the latter SETS the
    /// key for the whole subtree, so marking a category band would have wiped
    /// the mark on the plus button inside it.
    func walkthroughSpot(_ spot: WalkthroughSpot) -> some View {
        transformAnchorPreference(key: WalkthroughAnchorKey.self, value: .bounds) { spots, anchor in
            spots[spot] = anchor
        }
    }

    /// Draws the running walkthrough over this screen. `screen` is which one
    /// this is: a step belonging to the New Ideal form must not be drawn by the
    /// list underneath it.
    func walkthroughHost(_ coordinator: WalkthroughCoordinator,
                         screen: WalkthroughScreen = .idealsList) -> some View {
        modifier(WalkthroughHost(coordinator: coordinator, screen: screen))
    }
}

/// `.walkthroughSpot(_:)` for call sites that only mark one row out of many —
/// the first category band, say — and pass nil for the rest.
struct OptionalWalkthroughSpot: ViewModifier {
    let spot: WalkthroughSpot?

    func body(content: Content) -> some View {
        if let spot {
            content.walkthroughSpot(spot)
        } else {
            content
        }
    }
}

private struct WalkthroughHost: ViewModifier {
    @ObservedObject var coordinator: WalkthroughCoordinator
    let screen: WalkthroughScreen

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(WalkthroughAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if let run = coordinator.run, let step = run.step, step.screen == screen {
                    WalkthroughOverlay(
                        step: step,
                        target: step.spot.flatMap { anchors[$0] }.map { proxy[$0] },
                        isLastStep: run.isOnLastStep,
                        stepNumber: run.index + 1,
                        stepCount: run.walkthrough.steps.count,
                        onNext: { coordinator.advance() },
                        onSkip: { coordinator.skip() }
                    )
                    .transition(.opacity)
                }
            }
            .ignoresSafeArea()
        }
    }
}

/// The card's measured height, so it can be placed clear of what it points at.
private struct WalkthroughCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct WalkthroughOverlay: View {
    let step: WalkthroughStep
    /// Where the highlighted control is, in this screen's coordinates. Nil for
    /// steps that explain the page rather than a control.
    let target: CGRect?
    let isLastStep: Bool
    let stepNumber: Int
    let stepCount: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    private var isWaiting: Bool { step.waitsFor != nil }

    /// How far the lit area extends past the control.
    private let halo: CGFloat = 8
    private let cardWidth: CGFloat = 300
    /// The card's real height, measured once it has drawn, so it can be placed
    /// clear of the highlighted control instead of guessing at a size.
    /// Generous until the card has drawn once: overestimating places the first
    /// frame too high, which is harmless, while underestimating puts it over
    /// the control it is pointing at.
    @State private var cardHeight: CGFloat = 260
    /// Drives the flash around a control the user is being asked to touch.
    @State private var pulsing = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                dimmed(in: proxy.size)
                card(in: proxy.size)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tip \(stepNumber) of \(stepCount): \(step.title)")
    }

    /// The page, dimmed, with the highlighted control punched out of the dim.
    ///
    /// The paint never takes touches. What happens to them depends on the step:
    /// a plain step swallows taps anywhere and moves on, while a step waiting
    /// for the user blocks everything EXCEPT the lit control, which it leaves
    /// live so it can be typed in or tapped.
    @ViewBuilder
    private func dimmed(in size: CGSize) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.55))
            .overlay(alignment: .topLeading) {
                if let target {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .frame(width: target.width + halo * 2,
                               height: target.height + halo * 2)
                        .offset(x: target.minX - halo, y: target.minY - halo)
                        .blendMode(.destinationOut)
                }
            }
            .compositingGroup()
            .allowsHitTesting(false)
            .accessibilityHidden(true)

        // A step that is waiting flashes its control, so "drag the knob" points
        // somewhere the eye has already gone.
        if isWaiting, let target {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LCColor.chromatic(.pink), lineWidth: 3)
                .frame(width: target.width + halo * 2, height: target.height + halo * 2)
                .offset(x: target.minX - halo, y: target.minY - halo)
                .opacity(pulsing ? 0.15 : 0.95)
                .animation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true), value: pulsing)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .onAppear { pulsing = true }
        }

        if isWaiting && step.blocksScreen {
            ForEach(Array(blockingRects(in: size).enumerated()), id: \.offset) { _, rect in
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .accessibilityHidden(true)
            }
        } else if !isWaiting {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onNext() }
                .accessibilityHidden(true)
        }
    }

    /// The screen minus the lit control: four bands that swallow touches, so a
    /// waiting step cannot be tapped past but its control still works.
    private func blockingRects(in size: CGSize) -> [CGRect] {
        guard let target else { return [CGRect(origin: .zero, size: size)] }
        let hole = target.insetBy(dx: -halo, dy: -halo)
        return [
            CGRect(x: 0, y: 0, width: size.width, height: max(0, hole.minY)),
            CGRect(x: 0, y: min(size.height, hole.maxY),
                   width: size.width, height: max(0, size.height - hole.maxY)),
            CGRect(x: 0, y: max(0, hole.minY),
                   width: max(0, hole.minX), height: max(0, hole.height)),
            CGRect(x: min(size.width, hole.maxX), y: max(0, hole.minY),
                   width: max(0, size.width - hole.maxX), height: max(0, hole.height)),
        ].filter { $0.width > 0 && $0.height > 0 }
    }

    @ViewBuilder
    private func card(in size: CGSize) -> some View {
        let origin = cardOrigin(in: size)
        VStack(alignment: .leading, spacing: 10) {
            if !step.title.isEmpty {
                Text(step.title)
                    .font(.hhSamuel(24))
                    .textCase(.uppercase)
                    .accentText(.blue)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(step.message)
                .font(.manrope(14, .medium))
                .foregroundColor(LCColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let illustration = step.illustration {
                WalkthroughIllustrationView(illustration)
                    .padding(.top, 2)
            }

            HStack(spacing: 12) {
                Text("\(stepNumber) of \(stepCount)")
                    .font(.manrope(12, .heavy))
                    .foregroundColor(LCColor.textMuted)

                Spacer(minLength: 8)

                if WalkthroughCardControls.showsSkip(isLastStep: isLastStep, isWaiting: isWaiting) {
                    Button("Skip", action: onSkip)
                        .font(.manrope(14, .heavy))
                        .foregroundColor(LCColor.accentInk(.pink))
                        .buttonStyle(.plain)
                }

                // A waiting step has no Next: the user's own action moves it.
                if !isWaiting {
                    Button(isLastStep ? "Got it" : "Next", action: onNext)
                        .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink,
                                                           fill: LCColor.surface,
                                                           verticalPadding: 10,
                                                           font: .manrope(15, .heavy)))
                        .fixedSize()
                }
            }
            .padding(.top, 2)
        }
        .padding(18)
        .frame(width: cardWidth, alignment: .leading)
        // No shadow at all: on a dimmed page the neumorphic pair read as a white
        // glow around the card.
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LCColor.surface)
        )
        .background(
            GeometryReader { card in
                Color.clear.preference(key: WalkthroughCardHeightKey.self, value: card.size.height)
            }
        )
        .onPreferenceChange(WalkthroughCardHeightKey.self) { height in
            if height > 0 { cardHeight = height }
        }
        .offset(x: origin.x, y: origin.y)
    }

    /// Never on top of the highlighted control: above it when that fits,
    /// otherwise below, and centred when the step points at nothing.
    private func cardOrigin(in size: CGSize) -> CGPoint {
        let margin: CGFloat = 16
        let gap: CGFloat = 20
        guard let target else {
            return CGPoint(x: (size.width - cardWidth) / 2,
                           y: max(margin, (size.height - cardHeight) / 2))
        }
        let x = min(max(margin, target.midX - cardWidth / 2), size.width - cardWidth - margin)
        let above = target.minY - halo - gap - cardHeight
        let below = target.maxY + halo + gap
        let fitsAbove = above >= margin
        let fitsBelow = below + cardHeight <= size.height - margin

        let y: CGFloat
        switch step.placement {
        case .above:
            // The step opens the keyboard, so below is not an option even when
            // it looks like there is room.
            y = fitsAbove ? above : margin
        case .auto:
            if fitsBelow {
                y = below
            } else if fitsAbove {
                y = above
            } else {
                // Neither side fits the card: take the roomier one and stay off
                // the control rather than centring on top of it.
                y = target.minY > size.height - target.maxY
                    ? max(margin, above)
                    : min(below, size.height - cardHeight - margin)
            }
        }
        return CGPoint(x: x, y: y)
    }
}

/// The little pictures some steps carry — see `WalkthroughIllustration`.
struct WalkthroughIllustrationView: View {
    let illustration: WalkthroughIllustration

    init(_ illustration: WalkthroughIllustration) {
        self.illustration = illustration
    }

    var body: some View {
        switch illustration {
        case .selectionExample:
            VStack(spacing: 8) {
                exampleRow(title: "Walk 20 minutes", isPicked: true, note: "coming with you")
                exampleRow(title: "Sort the garage", isPicked: false, note: "stays on the list")
            }
        }
    }

    private func exampleRow(title: String, isPicked: Bool, note: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.idealTitle(15))
                    .foregroundColor(LCColor.ink)
                    .lineLimit(1)
                Text(note)
                    .font(.manrope(11, .medium))
                    .foregroundColor(LCColor.textMuted)
            }
            Spacer(minLength: 6)
            NeuHeartSelectButton(isSelected: isPicked, size: 20) {}
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .neuSunken(cornerRadius: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(note)")
    }
}
