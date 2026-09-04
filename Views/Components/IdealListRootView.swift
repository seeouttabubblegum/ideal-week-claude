//
//  IdealListRootView.swift
//  The Ideal Week
//
//  Moved out of IdealListView (2026-09-04) verbatim. Behaviour unchanged.
//

import SwiftUI

/// Separate view so IdealListView.body is a single expression the compiler can type-check.
struct IdealListRootView: View {
    let contentView: AnyView
    
    var body: some View {
        contentView
    }
}
