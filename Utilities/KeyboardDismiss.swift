//
//  KeyboardDismiss.swift
//  The Ideal Week
//
//  Drops focus from whatever text field currently holds it.
//
//  The ideal forms put the title field above the category row and the how-often
//  slider. Once the user reaches past the title for one of those, they are done
//  typing — and on a 402×874 screen the keyboard covers the very control they
//  just touched. So those controls dismiss it as they act.
//
//  Deliberately a first-responder resign rather than `@FocusState`: the controls
//  are shared components with no knowledge of which screen's field is focused,
//  and threading a focus binding through every caller would buy nothing.
//

import SwiftUI

@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil)
}
