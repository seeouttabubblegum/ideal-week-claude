//
//  IdealReviewView.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 20/8/25.
//
//  Redesigned (Phase 3): full-screen mood picker on a smoothly morphing
//  gradient. Score is on the 1-7 user scale; persisted on the legacy 0-100
//  scale by `ReviewViewViewModel`.
//

import SwiftUI
import SwiftData

struct IdealReviewView: View {
    var item: Ideal
    @StateObject private var viewModel: ReviewViewViewModel
    @Environment(\.dismiss) private var dismiss

    /// 1.0 ... 7.0 — bound to the slider.
    @State private var reviewScore: Double

    init(item: Ideal) {
        self.item = item
        _viewModel = StateObject(wrappedValue: ReviewViewViewModel())
        _reviewScore = State(initialValue: ReviewScoreScale.displayMax) // 7 = best mood (default)
    }

    /// Snap the continuous slider value to its closest integer "mood bucket"
    /// (1...7). Faces / mouth / tear all step on this — only the background
    /// gradient and slider position move continuously.
    private var bucketedScore: Double {
        let rounded = reviewScore.rounded()
        return max(ReviewScoreScale.displayMin, min(ReviewScoreScale.displayMax, rounded))
    }

    // 7 → happiest (yellow), 1 → saddest (blue). Internal "happiness" 0...1 (1 = happy).
    /// Stepped happiness derived from `bucketedScore` so expressions change at
    /// integer thresholds rather than morphing continuously with the drag.
    private var happiness: Double {
        let span = ReviewScoreScale.displayMax - ReviewScoreScale.displayMin
        return (bucketedScore - ReviewScoreScale.displayMin) / span
    }

    /// 1...7 face index for the official LC face art.
    private var faceNumber: Int {
        max(1, min(7, Int(bucketedScore.rounded())))
    }

    var body: some View {
        ZStack {
            MoodGradientBackground(value: reviewScore)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 12)
                // Official LC face art, MORPHING: the 7 "Face Rating N out of 7"
                // artworks' contours are interpolated point-wise with the
                // continuous slider value — integer scores show the exact art,
                // in-between values bend one face into the next (client request
                // 2026-07-15: "create a morph from these icons").
                FaceMorphShape(score: reviewScore)
                    .fill(LCColor.ink)
                    .frame(height: 240)
                    .padding(.horizontal, 40)
                Spacer()
                slider
                    .padding(.horizontal, 28)
                    .padding(.bottom, 92)   // slider sits higher; submit goes below-right
            }
            .padding(.top, 12)

            // Submit button — bottom-right.
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    submitButton
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .preferredColorScheme(.light)
    }

    private var submitButton: some View {
        Button {
            guard !viewModel.isSaving else { return }
            HapticFeedback.impact(style: .light)
            let position = item.doneCount + 1
            viewModel.saveReviewScore(score: reviewScore, item: item, position: position)
            dismiss()
        } label: {
            // Forward arrow, bottom-right (handoff 7j).
            Image(systemName: "arrow.right")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(Color(hex: 0x111111))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Submit and close")
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 6) {
                Text("How You Doin'?")
                    .font(.lcTitle(34))
                    .foregroundColor(Color(hex: 0x111111))
                Text("How did completing that\ntask make you feel?")
                    .font(.lcBody(15))
                    .foregroundColor(.black.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                HapticFeedback.impact(style: .light)
                dismiss()
            } label: {
                Text("SKIP")
                    .font(.manrope(15, .heavy))
                    .kerning(0.5)
                    .foregroundColor(Color(hex: 0x111111))
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - Slider

    private var slider: some View {
        MoodSlider(
            value: $reviewScore,
            range: ReviewScoreScale.displayMin...ReviewScoreScale.displayMax,
            // Handoff 7j: black track slider with a YELLOW knob.
            thumbInnerColor: LCColor.yellow,
            onCommit: { /* haptics handled internally */ }
        )
        .frame(height: 36)
    }
}

// MARK: - Background gradient

/// Diagonal directional gradient. Official direction: **7 = yellow (best)** sweeps
/// through pink to **1 = blue (worst)**. As the score drops 7 → 1 the new color
/// enters from the bottom-leading corner and pushes the previous one out.
enum MoodGradientPalette {
    // Exact brand anchors (handoff palette): 7 = CTA yellow, mid = deep pink,
    // 1 = brand blue.
    static let yellow = LCColor.yellow
    static let pink   = LCColor.deepPink
    static let blue   = LCColor.blue

    /// Normalised 0...1 progress for a 1...7 slider value, where 7 → 0 (yellow)
    /// and 1 → 1 (blue). Higher score = happier = yellow end.
    static func progress(for value: Double) -> Double {
        max(0, min(1, (7.0 - value) / 6.0))
    }

    /// The "old" color being pushed out, and the "new" color entering.
    /// `subProgress` is 0 at the start of the sub-phase and 1 at its end.
    static func phaseColors(for t: Double) -> (oldColor: Color, newColor: Color, subProgress: Double) {
        if t <= 0.5 {
            return (yellow, pink, t * 2)
        } else {
            return (pink, blue, (t - 0.5) * 2)
        }
    }

    /// The "leading" color the slider thumb fills with — same color that is
    /// sweeping in from the bottom-left corner of the background.
    static func leadingColor(for value: Double) -> Color {
        let t = progress(for: value)
        let (oldColor, newColor, p) = phaseColors(for: t)
        // Crossfade the thumb infill too so it tracks the dominant background
        // tone rather than snapping at the sub-phase boundary.
        return Color.lerp(oldColor, newColor, t: p)
    }
}

private struct MoodGradientBackground: View {
    let value: Double

    var body: some View {
        let t = MoodGradientPalette.progress(for: value)
        let (oldColor, newColor, p) = MoodGradientPalette.phaseColors(for: t)
        // Place the two stops outside [0,1] so as `p` grows from 0 → 1 the
        // newColor sweeps from bottom-leading across to top-trailing. At
        // p=0 the visible area is uniform oldColor; at p=1 it's uniform newColor.
        let stops: [Gradient.Stop] = [
            .init(color: newColor, location: p * 2.0 - 1.0),
            .init(color: oldColor, location: p * 2.0),
        ]
        LinearGradient(
            stops: stops,
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
        // No explicit animation here — the slider gesture mutates `value`
        // every drag tick, so an animation modifier would fight the drag.
        // (Tap / external setter changes are rare enough to look fine without it.)
    }
}

// MARK: - Face




// MARK: - Slider

/// Slim black track with a circular thumb whose inner fill tracks the
/// current gradient color; the thumb snaps to integer steps.
private struct MoodSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var thumbInnerColor: Color
    var onCommit: () -> Void = {}

    @State private var lastSnappedInt: Int? = nil

    private let trackHeight: CGFloat = 6
    private let thumbSize: CGFloat = 28
    private let thumbRingWidth: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            // Clamp the binding-side value too, so an external setter can't
            // push the thumb off-screen.
            let clamped = max(range.lowerBound, min(range.upperBound, value))
            let progress = (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
            // REVERSED: the high end (7 = yellow) sits on the LEFT, the low end
            // (1 = blue) on the right. So the thumb starts left at score 7.
            let thumbX = CGFloat(1 - progress) * (width - thumbSize) + thumbSize / 2

            ZStack(alignment: .leading) {
                // Slim black bar with rounded ends.
                Capsule()
                    .fill(LCColor.ink)
                    .frame(height: trackHeight)
                    .frame(maxWidth: .infinity)

                // Thumb: white outer ring + inner fill = current mood color.
                ZStack {
                    Circle().fill(Color.white)
                    Circle()
                        .fill(thumbInnerColor)
                        .padding(thumbRingWidth)
                }
                .overlay(Circle().stroke(LCColor.ink.opacity(0.22), lineWidth: 1))
                .shadow(color: LCColor.shadowDark, radius: 4, x: 0, y: 2)
                .frame(width: thumbSize, height: thumbSize)
                .position(x: thumbX, y: geo.size.height / 2)
                .animation(.easeInOut(duration: 0.18), value: thumbInnerColor)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let raw = drag.location.x / max(1, width)
                        let normalised = max(0.0, min(1.0, Double(raw)))
                        let span = range.upperBound - range.lowerBound
                        // REVERSED: left = upperBound (7), right = lowerBound (1).
                        let newValue = range.upperBound - normalised * span

                        // Continuous fraction — the thumb glides like water.
                        // Haptic only fires on integer-bucket crossings so the
                        // user still feels the mood "ticks" without snapping.
                        let bucketedInt = Int(newValue.rounded())
                        if let last = lastSnappedInt, last != bucketedInt {
                            HapticFeedback.impact(style: .light)
                        }
                        lastSnappedInt = bucketedInt
                        value = newValue
                    }
                    .onEnded { _ in onCommit() }
            )
            .onAppear {
                // Seed the haptic bucket from the initial value so the first
                // drag doesn't fire a spurious tap.
                lastSnappedInt = Int(value.rounded())
            }
        }
    }
}

// MARK: - Color helpers

private extension Color {
    /// Linear-interpolate between two colors in RGB.
    static func lerp(_ a: Color, _ b: Color, t: Double) -> Color {
        let ac = a.getComponents()
        let bc = b.getComponents()
        return Color(
            red: ac.red + (bc.red - ac.red) * t,
            green: ac.green + (bc.green - ac.green) * t,
            blue: ac.blue + (bc.blue - ac.blue) * t,
            opacity: ac.opacity + (bc.opacity - ac.opacity) * t
        )
    }
}

#Preview {
    IdealReviewView(item: Ideal(
        id: "preview-id",
        category: "Fitness",
        title: "Sample",
        notes: "",
        scheduleDateTime: Date().timeIntervalSince1970,
        createdDate: Date().timeIntervalSince1970,
        targetCount: "5",
        doneCount: 2,
        active: true
    ))
}
