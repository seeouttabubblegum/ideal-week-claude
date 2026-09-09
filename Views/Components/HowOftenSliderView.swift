//
//  HowOftenSliderView.swift
//  The Ideal Week
//
//  The 1–6+ "How often?" slider. One implementation shared by the New Ideal
//  screen and the wishlist quick-add sheet, so the two can't drift apart.
//  Geometry lives in `HowOftenSlider`: the knob travels between the margins, so
//  at 1 its left edge meets the content's left edge and at 6+ its right edge
//  meets the right — and the stop labels sit on those same centres.
//

import SwiftUI

struct HowOftenSliderView: View {
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let thumbX = HowOftenSlider.thumbX(for: Double(value), width: width)

                ZStack(alignment: .leading) {
                    // Track runs the full content width so it lines up with the
                    // labels above it. The knob is exactly as wide as the inset it
                    // travels within, so it caps both ends and no bare track pokes
                    // out past 1 or 6+ (handoff: progress is SUNKEN).
                    Color.clear
                        .frame(height: HowOftenSlider.trackHeight)
                        .frame(maxWidth: .infinity)
                        .neuSunkenCapsule()

                    Capsule()
                        .fill(LCColor.pink)
                        .frame(width: thumbX, height: HowOftenSlider.trackHeight)

                    Circle()
                        .fill(LCColor.surface)
                        .frame(width: HowOftenSlider.knobDiameter,
                               height: HowOftenSlider.knobDiameter)
                        .shadow(color: LCColor.shadowDark, radius: 3.5, x: 3, y: 3)
                        .shadow(color: LCColor.shadowLight, radius: 3.5, x: -3, y: -3)
                        .overlay(Circle().fill(LCColor.pink).frame(width: 14, height: 14))
                        .offset(x: thumbX - HowOftenSlider.knobDiameter / 2)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let stop = HowOftenSlider.value(atX: drag.location.x, width: width)
                            guard stop != value else { return }
                            hideKeyboard()
                            HapticFeedback.impact(style: .light)
                            withAnimation(.interactiveSpring()) { value = stop }
                        }
                        // Catches a tap that lands on the stop the knob is already
                        // on: no movement, but the user still reached past the
                        // title field.
                        .onEnded { _ in hideKeyboard() }
                )
            }
            .frame(height: 44)

            // Stop labels sit on the knob positions, not in equal columns, so the
            // knob lands exactly on its number.
            GeometryReader { geometry in
                ForEach(1...HowOftenSlider.stopCount, id: \.self) { stop in
                    Button {
                        hideKeyboard()
                        HapticFeedback.impact(style: .medium)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            value = stop
                        }
                    } label: {
                        Text(HowOftenSlider.label(for: stop))
                            .font(.manrope(14, value == stop ? .heavy : .medium))
                            .foregroundColor(value == stop ? LCColor.pink : LCColor.textSecondary)
                            .frame(width: HowOftenSlider.knobDiameter, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: HowOftenSlider.thumbX(for: Double(stop), width: geometry.size.width),
                              y: 14)
                }
            }
            .frame(height: 28)
        }
    }
}
