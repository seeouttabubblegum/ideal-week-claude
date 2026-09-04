//
//  PrimaryMenuView.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 22/5/25.
//
//  Menu drawer content per the neumorphic handoff (2e): deep-pink header with
//  a raised avatar + close button, then a cascade of nav tabs — each tab its
//  own accent shade (fading toward white), each 30pt narrower than the one
//  above, with a dark wedge shadow along its top edge.
//

import SwiftUI
import SwiftData

struct PrimaryMenuView: View {
    @StateObject var viewModel = PrimaryMenuViewViewModel()
    @Binding var showDrawer: Bool
    let activeView: String
    let accentColor: Color
    let week_start_day: String
    let skip_reviews: Bool
    /// iPad sidebar mode: always visible, so no close button, and widths come
    /// from `menuWidth` instead of the screen. Defaults preserve iPhone exactly.
    var persistent: Bool = false
    var menuWidth: CGFloat = UIScreen.main.bounds.width

    @Environment(\.modelContext) private var modelContext
    @State private var profileImage: UIImage? = nil
    @State private var shouldLoadImage: Bool = false

    // MARK: - Colours (handoff 2e)

    /// Deep "book-title" variant of the accent (≈ LCColor.deepPink for the
    /// brand pink): same hue, saturation boosted, slightly brighter.
    private var headerColor: Color {
        adjustedAccent(saturation: 1.28, brightness: 1.04)
    }
    /// Pink-tuned neumorphic shadow pair for raised controls ON the header
    /// (the grey surface shadows would look wrong on the deep pink).
    private var headerShadowDark: Color {
        adjustedAccent(saturation: 1.28 * 0.81, brightness: 1.04 * 0.78)
    }
    private var headerShadowLight: Color {
        adjustedAccent(saturation: 1.28 * 0.71, brightness: min(1.04 * 1.08, 1.15))
    }

    /// HSB-space tweak of the BRAND pink. The handoff 2e drawer is always the
    /// brand-pink family (#DD4298 → lighter shades); it must not follow the
    /// user's custom accent colour.
    private func adjustedAccent(saturation sMul: CGFloat, brightness bMul: CGFloat) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(LCColor.pink).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return LCColor.deepPink
        }
        return Color(hue: h, saturation: min(1, s * sMul), brightness: min(1, b * bMul), opacity: a)
    }

    /// Per-tab shade: brand pink mixed toward white in 16% steps
    /// (#DD4298 → #E260A9 → #E87FB9 → #EE9DC9 → #F3BBDA → #F8D9EA).
    private func tabShade(_ index: Int) -> Color {
        let c = LCColor.pink.getComponents()
        let p = Double(index) * 0.16
        return Color(red: c.red + (1.0 - c.red) * p,
                     green: c.green + (1.0 - c.green) * p,
                     blue: c.blue + (1.0 - c.blue) * p,
                     opacity: c.opacity)
    }

    // MARK: - Layout metrics (handoff 2e: header 210, tabs 100 @ 402×874)

    private var headerHeight: CGFloat { 210 }
    private var tabHeight: CGFloat {
        // 100pt per the mock, compressed on shorter devices so all 6 tabs fit.
        min(100, (UIScreen.main.bounds.height - headerHeight) / 6)
    }
    private func tabWidth(_ index: Int) -> CGFloat {
        menuWidth - CGFloat(index) * 30
    }

    // MARK: - Header (deep pink, close top-left, raised avatar centered)

    private var topSection: some View {
        ZStack(alignment: .topLeading) {
            headerColor
            // Close button — standard raised round close, pink-tuned shadows.
            // Hidden in the iPad sidebar: there is nothing to close.
            if !persistent {
            Button {
                HapticFeedback.impact()
                withAnimation {
                    showDrawer = false
                }
            } label: {
                Image("Line Close_Pink")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().fill(LCColor.surface)
                            .shadow(color: headerShadowDark, radius: 4.5, x: 4, y: 4)
                            .shadow(color: headerShadowLight, radius: 4.5, x: -4, y: -4)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 20)
            .padding(.top, 62)
            .accessibilityLabel("Close menu")
            }

            // Profile image — raised circle, centered in the header space.
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(LCColor.surface)
                        .shadow(color: headerShadowDark, radius: 7, x: 6, y: 6)
                        .shadow(color: headerShadowLight, radius: 7, x: -6, y: -6)
                    if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 104, height: 104)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person")
                            .font(.system(size: 54))
                            .foregroundColor(LCColor.pink)
                    }
                }
                .frame(width: 104, height: 104)
                Spacer()
            }
            .padding(.top, 50)
            .frame(maxHeight: .infinity, alignment: .center)
            .opacity(shouldLoadImage ? 1 : 0)
            .onAppear {
                // If drawer is already open when view appears, delay image loading
                if showDrawer {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        shouldLoadImage = true
                        loadProfileImage()
                    }
                }
            }
            .onChange(of: showDrawer) { oldValue, newValue in
                if newValue {
                    // Delay image loading until after slide animation completes
                    // The animation duration is approximately 0.35 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        shouldLoadImage = true
                        loadProfileImage()
                    }
                } else {
                    // Reset when drawer closes
                    shouldLoadImage = false
                    profileImage = nil
                }
            }
        }
        .frame(height: headerHeight)
    }

    // MARK: - Cascade tabs

    /// One cascading tab: its own shade, 30pt narrower per step, dark wedge
    /// shadow along the top edge.
    private func menuTab<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            ZStack(alignment: .top) {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                MenuTabWedge()
                    .fill(Color.black.opacity(0.22))
                    .frame(height: 11)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(width: tabWidth(index), height: tabHeight, alignment: .leading)
            .background(tabShade(index))
            Spacer(minLength: 0)
        }
        .frame(height: tabHeight)
    }

    private var myIdealsTab: some View {
        menuTab(index: 0) {
            Group {
                if activeView == "ideal-list" {
                    Button {
                        HapticFeedback.impact()
                        withAnimation {
                            showDrawer = false
                        }
                    } label: {
                        MenuItem(imageName: "", text: "My Ideals", showsChecklist: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        IdealListView(userId: viewModel.currentUserId)
                    } label: {
                        MenuItem(imageName: "", text: "My Ideals", showsChecklist: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticFeedback.impact()
                        IdealListView.requestResetToAllTabOnNextAppear()
                        withAnimation {
                            showDrawer = false
                        }
                    })
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
    }

    private var progressTab: some View {
        menuTab(index: 1) {
            Group {
                if activeView == "history" {
                    Button {
                        HapticFeedback.impact()
                        withAnimation {
                            showDrawer = false
                        }
                    } label: {
                        MenuItem(imageName: "clock", text: "PROGRESS", showsProgressRings: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        HistoryProgressView(userId: viewModel.currentUserId)
                    } label: {
                        MenuItem(imageName: "clock", text: "PROGRESS", showsProgressRings: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticFeedback.impact()
                        withAnimation {
                            showDrawer = false
                        }
                    })
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
    }

    private var profileTab: some View {
        menuTab(index: 2) {
            Group {
                if activeView == "profile" {
                    Button {
                        HapticFeedback.impact()
                        withAnimation {
                            showDrawer = false
                        }
                    } label: {
                        MenuItem(imageName: "Line Profile_Blk", text: "PROFILE")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        MenuItem(imageName: "Line Profile_Blk", text: "PROFILE")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticFeedback.impact()
                        withAnimation {
                            showDrawer = false
                        }
                    })
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
    }

    private var helpTab: some View {
        menuTab(index: 4) {
            Group {
                if activeView == "help" {
                    Button {
                        HapticFeedback.impact()
                        withAnimation {
                            showDrawer = false
                        }
                    } label: {
                        MenuItem(imageName: "Line Help_Blk", text: "HELP")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        HelpView()
                    } label: {
                        MenuItem(imageName: "Line Help_Blk", text: "HELP")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticFeedback.impact()
                        withAnimation {
                            showDrawer = false
                        }
                    })
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
    }

    private var settingsTab: some View {
        menuTab(index: 3) {
            Group {
                if activeView == "settings" {
                    Button {
                        HapticFeedback.impact()
                        withAnimation {
                            showDrawer = false
                        }
                    } label: {
                        MenuItem(imageName: "Line Settings_Blk", text: "SETTINGS")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        SettingsView(accentDefault: accentColor, start_day: week_start_day, skip_reviews: skip_reviews)
                    } label: {
                        MenuItem(imageName: "Line Settings_Blk", text: "SETTINGS")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticFeedback.impact()
                        withAnimation {
                            showDrawer = false
                        }
                    })
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
    }

    private var logoutTab: some View {
        menuTab(index: 5) {
            Button {
                HapticFeedback.impact(style: .heavy)
                viewModel.logOut()
            } label: {
                MenuItem(imageName: "key.horizontal", text: "LOGOUT")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Drawer base — the shared surface; tapping outside the tabs closes.
            LCColor.surface
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticFeedback.impact()
                    withAnimation {
                        showDrawer = false
                    }
                }

            VStack(alignment: .leading, spacing: 0) {
                topSection
                myIdealsTab
                progressTab
                profileTab
                // Settings above Help (client, 2026-09-02). The index passed to
                // menuTab drives the cascading tab width, so it moves with the
                // row — swapping only the order would break the cascade.
                settingsTab
                helpTab
                logoutTab
                Spacer(minLength: 0)
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height)
        .zIndex(1000)
    }

    private func loadProfileImage() {
        guard let userId = viewModel.currentUserId.isEmpty ? nil : viewModel.currentUserId as String? else { return }

        let descriptor = FetchDescriptor<UserProfileSettings>(
            predicate: #Predicate<UserProfileSettings> { $0.userId == userId }
        )

        if let profileSettings = try? modelContext.fetch(descriptor).first,
           let imageData = profileSettings.profilePictureData,
           let image = UIImage(data: imageData) {
            // Downscale for drawer thumbnail (displayed at 104×104) to reduce memory.
            let maxSide: CGFloat = 200
            let size = image.size
            guard size.width > maxSide || size.height > maxSide else {
                profileImage = image
                return
            }
            let scale = min(maxSide / size.width, maxSide / size.height)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            profileImage = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            profileImage = nil
        }
    }
}

/// Dark wedge along a tab's top edge — full top run, tapering from nothing at
/// the left to full height at the right (handoff clip-path
/// `polygon(0 0, 100% 0, 100% 100%)`).
private struct MenuTabWedge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// ... existing preview code ...


#if DEBUG
#Preview {
    PreviewData.configureFirebaseIfNeeded()
    return PrimaryMenuView(
        showDrawer: .constant(true),
        activeView: "ideals",
        accentColor: LCColor.pink,
        week_start_day: PreviewData.weekStartDay,
        skip_reviews: false
    )
    .modelContainer(for: MainSettings.self, inMemory: true)
}
#endif
