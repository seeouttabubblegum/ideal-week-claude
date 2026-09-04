//
//  MenuDrawer.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 18/8/25.
//

import SwiftUI
import SwiftData


struct MenuDrawer: View {
    // MARK: - iPad persistent sidebar
    //
    // On iPad the menu is not a slide-in drawer: it is pinned to the left edge,
    // always visible (client, 2026-08-26). Every page hosts its own MenuDrawer
    // INSIDE its NavigationStack (the menu's NavigationLinks depend on that), and
    // every page insets its content by `contentInset` — a pushed page fills the
    // whole window, so its own sidebar copy lands exactly where the previous
    // page's was and the user sees one continuous sidebar. On iPhone both knobs
    // collapse to today's behavior: inset 0, slide-in drawer untouched.
    static let sidebarWidth: CGFloat = 375   // iPhone-like width: menu renders per design
    static var isPersistentSidebar: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    /// Leading inset each host applies to its content (0 on iPhone).
    static var contentInset: CGFloat { isPersistentSidebar ? sidebarWidth : 0 }

    @Binding var showDrawer: Bool
    let activeView:String
    @Query var storedSettings: [MainSettings]
    var accentColor: Color {
        if let firstColor = storedSettings.first{
            return Color(red: firstColor.red, green: firstColor.green, blue: firstColor.blue, opacity: firstColor.opacity)
        }else{
            return LCColor.pink
        }
    }
    var week_start_day: String {
        if let firstSettings = storedSettings.first{
            return firstSettings.week_start_day
        }else{
            return "Monday"
        }
    }
    var skip_reviews: Bool {
        if let firstSettings = storedSettings.first{
            return firstSettings.skip_reviews
        }else{
            return false
        }
    }
    var body: some View {
        ZStack {
            if Self.isPersistentSidebar {
                persistentSidebar
            } else {
                phoneDrawer
            }
        }
        .zIndex(10000)
    }

    /// iPad: pinned, always-on menu column. No scrim, no offset animation; the
    /// binding is ignored for visibility (setting it stays harmless).
    private var persistentSidebar: some View {
        PrimaryMenuView(showDrawer: $showDrawer, activeView: activeView, accentColor: accentColor,
                        week_start_day: week_start_day, skip_reviews: skip_reviews,
                        persistent: true, menuWidth: Self.sidebarWidth)
            // The tab stack tops out below tall iPad screens; surface fills the rest.
            .frame(maxHeight: .infinity, alignment: .top)
            .background(LCColor.surface)
            .overlay(alignment: .trailing) {
                // Feathered edge (fades at top and bottom) rather than a hard rule.
                Rectangle()
                    .fill(LinearGradient(
                        stops: [
                            .init(color: LCColor.dividerGrey.opacity(0), location: 0),
                            .init(color: LCColor.dividerGrey.opacity(0.4), location: 0.5),
                            .init(color: LCColor.dividerGrey.opacity(0), location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 1.5)
            }
            .frame(width: Self.sidebarWidth)
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var phoneDrawer: some View {
            // Drawer overlay
            Group {
                if showDrawer {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            HapticFeedback.impact()
                            withAnimation {
                                showDrawer = false
                            }
                        }
                }
                PrimaryMenuView(showDrawer: $showDrawer,activeView: activeView, accentColor: accentColor, week_start_day: week_start_day, skip_reviews: skip_reviews)
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(x: showDrawer ? 0 : (UIScreen.main.bounds.size.width * -1))
                    .animation(.easeInOut, value: showDrawer)
                    .padding(0)
                    .edgesIgnoringSafeArea(.all)
                    .allowsHitTesting(showDrawer)
            }
    }
}

#if DEBUG
#Preview {
    PreviewData.configureFirebaseIfNeeded()
    return MenuDrawer(showDrawer: .constant(true), activeView: "ideals")
        .modelContainer(for: MainSettings.self, inMemory: true)
}
#endif
