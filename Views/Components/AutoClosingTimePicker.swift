//
//  AutoClosingTimePicker.swift
//  The Ideal Week
//
//  Moved out of PlanningSheetView (2026-09-04) verbatim. Behaviour unchanged.
//

import SwiftUI

/// A DatePicker (.hourAndMinute) that auto-dismisses its inline popover when AM/PM changes.
/// Accomplished by reassigning `.id` on an AM/PM switch, which forces SwiftUI to recreate
/// the picker and collapse the open inline wheel.
struct AutoClosingTimePicker: View {
    let label: String
    @Binding var selection: Date

    @State private var pickerId = UUID()
    @State private var lastWasAM: Bool

    init(label: String, selection: Binding<Date>) {
        self.label = label
        self._selection = selection
        self._lastWasAM = State(
            initialValue: Calendar.current.component(.hour, from: selection.wrappedValue) < 12
        )
    }

    var body: some View {
        DatePicker(selection: $selection, displayedComponents: .hourAndMinute) {
            Text(label)
                .font(.manrope(16, .heavy))
                .foregroundColor(LCColor.ink)
        }
        .tint(LCColor.pink)
        .frame(minHeight: 44)
        .id(pickerId)
        .onChange(of: selection) { _, newValue in
            let isAM = Calendar.current.component(.hour, from: newValue) < 12
            if isAM != lastWasAM {
                lastWasAM = isAM
                pickerId = UUID()
            }
        }
    }
}
