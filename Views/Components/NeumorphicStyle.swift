//
//  NeumorphicStyle.swift
//  The Ideal Week
//
//  Central source of truth for the neumorphic ("soft UI") look, per the
//  2026-07 redesign handoff (HANDOFF/design_handoff_ideal_week_neumorphic).
//
//  RAISED  = anything you press          → dual drop shadow  5/5/12 #CBCCD4 + -5/-5/12 #FFF
//  SUNKEN  = anything you fill in / progress → inner shadow  inset 3/3/6 both sides
//  CSS blur ≈ 2 × SwiftUI shadow radius — helpers below take CSS px values.
//

import SwiftUI

// MARK: - Tokens (legacy names kept; values now come from LCTheme)

enum Neumorphic {
    /// Base surface colour — #F0F0F5. Cards ARE the surface.
    static let surface = LCColor.surface
    /// Light highlight (top-left → bottom-right pair).
    static let lightShadow = LCColor.shadowLight
    /// Dark shadow — #CBCCD4.
    static let darkShadow = LCColor.shadowDark
    /// Hairline edge for very low-contrast sunken shapes.
    static let edgeStroke = Color.black.opacity(0.06)

}

// MARK: - Core raised / sunken modifiers

extension View {
    /// RAISED (extruded) — for anything pressable. `cssOffset`/`cssBlur` are the
    /// CSS box-shadow values from the handoff (5/12 default, 4/9 for ~36px
    /// controls, 3/7 for 30–34px chips).
    func neuRaised<S: Shape>(_ shape: S,
                             fill: Color = LCColor.surface,
                             cssOffset: CGFloat = LCNeumorphism.raisedOffset,
                             cssBlur: CGFloat? = nil) -> some View {
        let radius = (cssBlur ?? cssOffset * 2.4) / 2
        return background(
            shape.fill(fill)
                .shadow(color: LCColor.shadowDark, radius: radius, x: cssOffset, y: cssOffset)
                .shadow(color: LCColor.shadowLight, radius: radius, x: -cssOffset, y: -cssOffset)
        )
    }

    /// SUNKEN (inset) — for anything you fill in or that shows progress.
    func neuSunken<S: Shape>(_ shape: S,
                             fill: Color = LCColor.surface,
                             cssOffset: CGFloat = LCNeumorphism.sunkenOffset,
                             cssBlur: CGFloat? = nil) -> some View {
        let radius = (cssBlur ?? cssOffset * 2) / 2
        return background(
            shape.fill(
                fill.shadow(.inner(color: LCColor.shadowDark, radius: radius, x: cssOffset, y: cssOffset))
                    .shadow(.inner(color: LCColor.shadowLight, radius: radius, x: -cssOffset, y: -cssOffset))
            )
        )
    }

    // Rounded-rect / capsule / circle conveniences.
    func neuRaised(cornerRadius: CGFloat = LCRadius.card,
                   fill: Color = LCColor.surface,
                   cssOffset: CGFloat = LCNeumorphism.raisedOffset,
                   cssBlur: CGFloat? = nil) -> some View {
        neuRaised(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                  fill: fill, cssOffset: cssOffset, cssBlur: cssBlur)
    }
    func neuRaisedCircle(fill: Color = LCColor.surface,
                         cssOffset: CGFloat = LCNeumorphism.raisedOffsetMedium,
                         cssBlur: CGFloat? = nil) -> some View {
        neuRaised(Circle(), fill: fill, cssOffset: cssOffset,
                  cssBlur: cssBlur ?? LCNeumorphism.raisedBlurMedium)
    }
    func neuSunken(cornerRadius: CGFloat = LCRadius.field,
                   fill: Color = LCColor.surface,
                   cssOffset: CGFloat = LCNeumorphism.sunkenOffset,
                   cssBlur: CGFloat? = nil) -> some View {
        neuSunken(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                  fill: fill, cssOffset: cssOffset, cssBlur: cssBlur)
    }
    func neuSunkenCapsule(fill: Color = LCColor.surface,
                          cssOffset: CGFloat = LCNeumorphism.sunkenOffset,
                          cssBlur: CGFloat? = nil) -> some View {
        neuSunken(Capsule(), fill: fill, cssOffset: cssOffset, cssBlur: cssBlur)
    }
}

/// Raised fill style you can drop straight into a custom `ButtonStyle` —
/// inverts to sunken while pressed (handoff "press feedback" rule).
struct NeuPressableBackground<S: Shape>: View {
    var shape: S
    var fill: Color = LCColor.surface
    var cssOffset: CGFloat = LCNeumorphism.raisedOffset
    var cssBlur: CGFloat? = nil
    var pressed: Bool

    var body: some View {
        let radius = (cssBlur ?? cssOffset * 2.4) / 2
        if pressed {
            shape.fill(
                fill.shadow(.inner(color: LCColor.shadowDark, radius: radius * 0.6,
                                   x: cssOffset * 0.7, y: cssOffset * 0.7))
                    .shadow(.inner(color: LCColor.shadowLight, radius: radius * 0.6,
                                   x: -cssOffset * 0.7, y: -cssOffset * 0.7))
            )
        } else {
            shape.fill(fill)
                .shadow(color: LCColor.shadowDark, radius: radius, x: cssOffset, y: cssOffset)
                .shadow(color: LCColor.shadowLight, radius: radius, x: -cssOffset, y: -cssOffset)
        }
    }
}

// MARK: - Completion dot (tracking dots — SUNKEN per handoff)

/// A single tracking dot.
/// - `.empty`         — sunken surface well (not yet done)
/// - `.completed`     — sunken PINK fill (counts toward target)
/// - `.overCompleted` — sunken BLUE fill (beyond target)
struct NeumorphicCompletionDot: View {
    enum State { case empty, completed, overCompleted }

    let state: State
    var size: CGFloat = 18

    var body: some View {
        let fill: Color = {
            switch state {
            case .empty: return LCColor.surface
            case .completed: return LCColor.pink
            case .overCompleted: return LCColor.blue
            }
        }()
        let dark: Color = {
            switch state {
            case .empty: return LCColor.shadowDark
            case .completed: return LCColor.pink
            // Neutral, not a shade of the accent: the palette has three colours
            // and none of them is a darker blue.
            case .overCompleted: return Color.black.opacity(0.22)
            }
        }()
        let light: Color = {
            switch state {
            case .empty: return LCColor.shadowLight
            case .completed: return LCColor.pink
            case .overCompleted: return Color.white.opacity(0.45)
            }
        }()
        let off = max(1.2, size * 0.11)
        let blur = max(1.2, size * 0.17)
        Circle()
            .fill(
                fill.shadow(.inner(color: dark, radius: blur, x: off, y: off))
                    .shadow(.inner(color: light, radius: blur, x: -off, y: -off))
            )
            .overlay(Circle().stroke(Neumorphic.edgeStroke, lineWidth: 0.5))
            .frame(width: size, height: size)
    }
}

extension Color {
    func darker(_ amount: Double) -> Color {
        let c = getComponents()
        return Color(red: max(0, c.red - amount), green: max(0, c.green - amount), blue: max(0, c.blue - amount), opacity: c.opacity)
    }
    func lighter(_ amount: Double) -> Color {
        let c = getComponents()
        return Color(red: min(1, c.red + amount), green: min(1, c.green + amount), blue: min(1, c.blue + amount), opacity: c.opacity)
    }
}

// MARK: - Recessed track (the elongated dot / progress capsule)

/// Sunken capsule used as the "one long dot" that stretches to the width the
/// remaining dots would occupy (max 13 per row), and as generic progress wells.
struct NeumorphicTrack: View {
    var height: CGFloat
    var body: some View {
        let off = max(1.2, height * 0.11)
        let blur = max(1.2, height * 0.17)
        Capsule()
            .fill(
                LCColor.surface
                    .shadow(.inner(color: LCColor.shadowDark, radius: blur, x: off, y: off))
                    .shadow(.inner(color: LCColor.shadowLight, radius: blur, x: -off, y: -off))
            )
            .overlay(Capsule().stroke(Neumorphic.edgeStroke, lineWidth: 0.5))
            .frame(height: height)
    }
}

// MARK: - Feathered divider (handoff exact)
// linear-gradient(to right, rgba(160,162,178,0) 0%, rgba(160,162,178,0.4) 50%,
// rgba(160,162,178,0) 100%), ~66% width, centered, 1.5px. A break, not a track line.

struct NeuFeatheredDivider: View {
    /// Fraction of the available width the divider spans (handoff ≈ 66%).
    var widthFraction: CGFloat = 0.66
    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(LinearGradient(
                    stops: [
                        .init(color: LCColor.dividerGrey.opacity(0), location: 0),
                        .init(color: LCColor.dividerGrey.opacity(0.4), location: 0.5),
                        .init(color: LCColor.dividerGrey.opacity(0), location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing))
                .frame(width: geo.size.width * widthFraction, height: 1.5)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .frame(height: 1.5)
        .accessibilityHidden(true)
    }
}

// MARK: - Input field style (sunken)

/// Recessed neumorphic field for any `TextField` / `SecureField`.
/// Apply with `.textFieldStyle(NeumorphicTextFieldStyle())`.
struct NeumorphicTextFieldStyle: TextFieldStyle {
    var horizontalPadding: CGFloat = 18
    var verticalPadding: CGFloat = 14
    var cornerRadius: CGFloat = LCRadius.field

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.manrope(16, .medium))
            .foregroundColor(LCColor.ink)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .neuSunken(cornerRadius: cornerRadius)
    }
}

/// Same recessed look applied to any container (use around `TextEditor`,
/// `SecureField`, custom inputs, etc.).
struct NeumorphicInputContainer<Content: View>: View {
    var horizontalPadding: CGFloat = 18
    var verticalPadding: CGFloat = 14
    var cornerRadius: CGFloat = LCRadius.field
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .neuSunken(cornerRadius: cornerRadius)
    }
}

// MARK: - Button styles

/// Raised neumorphic capsule button; depresses to sunken while pressed.
/// Apply with `.buttonStyle(NeumorphicButtonStyle())`.
/// `fill` = capsule colour (e.g. `LCColor.yellow` for key CTAs).
struct NeumorphicButtonStyle: ButtonStyle {
    var tint: Color? = nil
    var fill: Color = LCColor.surface
    var horizontalPadding: CGFloat = 24
    var verticalPadding: CGFloat = 14
    var font: Font = .manrope(16, .heavy)
    var fullWidth: Bool = true

    /// The label colour, guarded against its own fill. `tint` is an accent chosen
    /// for the Present palette (deep pink on the yellow CTA, say); once the
    /// palette rotates, that same pairing can collapse to no contrast at all. If
    /// the requested tint cannot clear WCAG's 3:1 large-text minimum on this
    /// button's fill, fall back to whichever of white / ink can. Every Present
    /// pairing already clears it, so the default look is untouched.
    private var readableTint: Color {
        let requested = tint ?? LCColor.ink
        return LCColor.contrast(requested, fill) >= 3
            ? requested
            : LCColor.contrastingInk(on: fill)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundColor(readableTint)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(NeuPressableBackground(shape: Capsule(), fill: fill,
                                               pressed: configuration.isPressed))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Raised icon button (circle) — profile, back chevrons, small controls.
/// Raised grouped row that presses IN when tapped — for rows that look like
/// cards but had no press feedback (recap category rows, list-style buttons).
struct NeuRowButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = LCRadius.chip
    var fill: Color = LCColor.surface
    var cssOffset: CGFloat = LCNeumorphism.raisedOffsetSmall
    var cssBlur: CGFloat? = LCNeumorphism.raisedBlurSmall

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(NeuPressableBackground(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                fill: fill,
                cssOffset: cssOffset,
                cssBlur: cssBlur,
                pressed: configuration.isPressed))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct NeuCircleButtonStyle: ButtonStyle {
    var fill: Color = LCColor.surface
    var diameter: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: diameter, height: diameter)
            .background(NeuPressableBackground(
                shape: Circle(), fill: fill,
                cssOffset: diameter >= 40 ? LCNeumorphism.raisedOffsetMedium : LCNeumorphism.raisedOffsetSmall,
                cssBlur: diameter >= 40 ? LCNeumorphism.raisedBlurMedium : LCNeumorphism.raisedBlurSmall,
                pressed: configuration.isPressed))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Standard controls

/// Standard close (dismiss) button — raised round surface button with the
/// line-close glyph, as on the NEXT? page.
struct NeuCloseButton: View {
    var action: () -> Void
    var diameter: CGFloat = 40

    var body: some View {
        Button(action: action) {
            Image("Line Close_Blk")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: diameter * 0.38, height: diameter * 0.38)
        }
        .buttonStyle(NeuCircleButtonStyle(diameter: diameter))
        .accessibilityLabel("Close")
    }
}

/// Save = raised YELLOW circle with a PINK check, with an optional count badge
/// (blue circle, pink number) of items being saved.
struct NeuCheckSaveButton: View {
    var count: Int? = nil
    var diameter: CGFloat = 48
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.system(size: diameter * 0.38, weight: .heavy))
                .foregroundColor(LCColor.glyph(.pink, onFill: .yellow))
        }
        .buttonStyle(NeuCircleButtonStyle(fill: LCColor.yellow, diameter: diameter))
        .overlay(alignment: .topTrailing) {
            if let count, count > 0 {
                Text("\(count)")
                    .font(.manrope(12, .heavy))
                    // The handoff's own pairing is only 1.49:1, so `glyph` takes
                    // that as the bar here and leaves Present exactly as it is.
                    .foregroundColor(LCColor.glyph(.pink, onFill: .blue))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(LCColor.blue))
                    .offset(x: 7, y: -7)
            }
        }
        .accessibilityLabel("Save")
    }
}

/// Heart select button — heart-SHAPED raised control (not in a circle),
/// filled pink when selected. Used in planning (1e) and continue (7m).
struct NeuHeartSelectButton: View {
    var isSelected: Bool
    var size: CGFloat = 34
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: size))
                    .foregroundColor(isSelected ? LCColor.pink : LCColor.surface)
                    .shadow(color: LCColor.shadowDark, radius: 3.5, x: 3, y: 3)
                    .shadow(color: LCColor.shadowLight, radius: 3.5, x: -3, y: -3)
                Image(systemName: "heart")
                    .font(.system(size: size, weight: .thin))
                    .foregroundColor(isSelected ? LCColor.pink : LCColor.shadowDark.opacity(0.55))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// "How Often?" stepper — small SUNKEN number pill between ‹ › chevrons,
/// inline with row text (NOT a raised button, NOT oversized).
struct NeuStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...99
    /// Shown instead of the number when `value` sits at the range's top —
    /// the "6+" convention every how-often selector in the app uses.
    var maxLabel: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if value > range.lowerBound { value -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(LCColor.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(value <= range.lowerBound)
            .opacity(value <= range.lowerBound ? 0.35 : 1)
            .accessibilityLabel("Decrease")

            Text(value == range.upperBound ? (maxLabel ?? "\(value)") : "\(value)")
                .font(.manrope(16, .heavy))
                .accentText(.pink)
                .frame(minWidth: 46)   // room for "6+" inside the pill
                .padding(.vertical, 5)
                .neuSunkenCapsule()
                .accessibilityLabel(value == range.upperBound && maxLabel != nil
                    ? "\(value) or more times" : "\(value) times")

            Button {
                if value < range.upperBound { value += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(LCColor.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(value >= range.upperBound)
            .opacity(value >= range.upperBound ? 0.35 : 1)
            .accessibilityLabel("Increase")
        }
    }
}

/// Neumorphic toggle — ON = pink fill with raised white knob;
/// OFF = sunken gray well. Apply with `.toggleStyle(NeuToggleStyle())`.
struct NeuToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 8)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                if configuration.isOn {
                    Capsule().fill(LCColor.pink)
                        .shadow(color: LCColor.shadowDark, radius: 2, x: 2, y: 2)
                        .shadow(color: LCColor.shadowLight, radius: 2, x: -2, y: -2)
                } else {
                    Capsule().fill(
                        LCColor.surface
                            .shadow(.inner(color: LCColor.shadowDark, radius: 3, x: 3, y: 3))
                            .shadow(.inner(color: LCColor.shadowLight, radius: 3, x: -3, y: -3))
                    )
                }
                Circle()
                    .fill(.white)
                    .shadow(color: LCColor.shadowDark, radius: 2, x: 1.5, y: 1.5)
                    .padding(3)
            }
            .frame(width: 52, height: 31)
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.15)) { configuration.isOn.toggle() }
            }
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.15)) { configuration.isOn.toggle() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Grouped list row (56px finger-friendly rule)

extension View {
    /// Uniform grouped-row treatment: 56pt min height for tappable rows.
    func neuGroupedRow(minHeight: CGFloat = LCMetrics.rowHeight) -> some View {
        self.frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
    }

    /// Card / grouped-list container: raised 18pt rounded rect on the surface.
    func neuCard(cornerRadius: CGFloat = LCRadius.card,
                 padding: CGFloat = LCMetrics.cardPadding) -> some View {
        self.padding(padding)
            .neuRaised(cornerRadius: cornerRadius)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 28) {
            HStack(spacing: 10) {
                NeumorphicCompletionDot(state: .completed)
                NeumorphicCompletionDot(state: .empty)
                NeumorphicCompletionDot(state: .overCompleted)
                NeumorphicTrack(height: 18).frame(width: 90)
            }
            NeuFeatheredDivider()
            TextField("Ideal name", text: .constant(""))
                .textFieldStyle(NeumorphicTextFieldStyle())
                .padding(.horizontal)
            Button("Save & Continue") {}
                .buttonStyle(NeumorphicButtonStyle(tint: LCColor.ink, fill: LCColor.yellow))
                .padding(.horizontal)
            HStack(spacing: 18) {
                NeuCloseButton {}
                NeuCheckSaveButton(count: 3) {}
                NeuHeartSelectButton(isSelected: true) {}
                NeuHeartSelectButton(isSelected: false) {}
                NeuStepper(value: .constant(3))
            }
            Toggle("Skip Reviews", isOn: .constant(true))
                .font(.manrope(16, .heavy))
                .toggleStyle(NeuToggleStyle())
                .padding(.horizontal)
            Text("Try New Glasses")
                .font(.idealTitle(26))
                .foregroundColor(LCColor.ink)
                .imprinted()
            Text("MY IDEAL WEEK")
                .font(.hhSamuel(30))
                .accentText(.blue)
        }
        .padding(.vertical, 40)
    }
    .background(LCColor.surface)
}
