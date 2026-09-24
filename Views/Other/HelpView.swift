//
//  HelpView.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 28/8/25.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showDrawer = false
    @State private var selectedImage = 0
    @State private var autoPlayTimer: Timer?
    @State private var isAutoPlaying = false
    @State private var tipsReset = false
    
    var isFirstLaunch: Bool = false
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        if isFirstLaunch {
            firstLaunchCarousel
        } else {
            guide
        }
    }

    // MARK: - The guide (Help tab)

    /// The in-app tours, as a read-through: real screenshots grouped into
    /// sections, each section a horizontal pager.
    private var guide: some View {
        VStack(spacing: 0) {
            TopNav(pageTitle: "Help", isIdealList: false, showDrawer: $showDrawer, showingNewItemView: .constant(false))

            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    Text("How The Ideal Week works, screen by screen.")
                        .font(.manrope(15, .medium))
                        .accentBodyText(.pink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, LCMetrics.screenMargin)
                        .padding(.top, 4)

                    ForEach(HelpGuide.sections) { section in
                        HelpGuideSectionView(section: section)
                    }

                    // Anyone can replay the in-app tips from here — the tours are
                    // once-per-user otherwise, and existing users never saw them.
                    Button {
                        HapticFeedback.impact()
                        WalkthroughCoordinator.shared.replayAll()
                        tipsReset = true
                    } label: {
                        Text(tipsReset ? "Tips are back \u{2014} open a screen to see them" : "Show tips again")
                    }
                    .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink,
                                                       fill: LCColor.surface,
                                                       verticalPadding: 15,
                                                       font: .manrope(16, .heavy)))
                    .disabled(tipsReset)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 30)
                }
                .padding(.top, 8)
            }
        }
        .background(LCColor.surface.ignoresSafeArea())
        .padding(.leading, MenuDrawer.contentInset)   // iPad sidebar inset (0 on iPhone)
        .overlay(alignment: .top) {
            MenuDrawer(showDrawer: $showDrawer, activeView: "help")
        }
    }

    // MARK: - First launch (kept, currently switched off — see OnboardingGate)

    private var firstLaunchCarousel: some View {
        VStack(spacing: 0) {
            // First-launch tutorial keeps the HELP wordmark, without the drawer control.
            Text("HELP")
                .font(.hhSamuel(34))
                .accentText(.pink)
                .padding(.top, 16)
                .padding(.bottom, 4)

            Spacer(minLength: 0)

            // Tutorial carousel — the real help screenshots inside one large
            // sunken well (handoff 7c: 28pt radius, big-well inset shadow).
            TabView(selection: $selectedImage) {
                ForEach(0..<3) { index in
                    Image("help\(index + 1)")
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                        .tag(index)
                        .accessibilityLabel("Tutorial screenshot \(index + 1) of 3")
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 520)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .neuSunken(cornerRadius: 28,
                       cssOffset: LCNeumorphism.sunkenOffsetLarge,
                       cssBlur: LCNeumorphism.sunkenBlurLarge)
            .padding(.horizontal, 28)
            .onAppear { startAutoPlay() }
            .onDisappear { stopAutoPlay() }
            .onChange(of: selectedImage) { oldValue, newValue in
                // If user manually swipes to the last slide, dismiss and show settings
                if newValue == 2 {
                    stopAutoPlay()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        onDismiss?()
                    }
                }
            }

            // Neumorphic dot pager — sunken dots, active = pink (handoff 7c).
            HStack(spacing: 10) {
                ForEach(0..<3) { index in
                    NeumorphicCompletionDot(state: index == selectedImage ? .completed : .empty, size: 11)
                }
            }
            .padding(.top, 26)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(selectedImage + 1) of 3")

            Spacer(minLength: 0)

            Button(action: {
                stopAutoPlay()
                onDismiss?()
            }) {
                Text("Skip")
            }
            .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink,
                                               fill: LCColor.surface,
                                               verticalPadding: 17,
                                               font: .manrope(18, .heavy)))
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .background(LCColor.surface.ignoresSafeArea())
    }

    private func startAutoPlay() {
        // Prevent overlapping timers if onAppear triggers more than once.
        stopAutoPlay()
        isAutoPlaying = true
        autoPlayTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation {
                if selectedImage < 2 {
                    selectedImage += 1
                } else {
                    // Finished auto-play, stop and dismiss to show settings
                    stopAutoPlay()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onDismiss?()
                    }
                }
            }
        }
    }
    
    private func stopAutoPlay() {
        isAutoPlaying = false
        autoPlayTimer?.invalidate()
        autoPlayTimer = nil
    }
}

#Preview {
    HelpView()
}

/// One section of the Help guide: a title, a line of summary, and its
/// screenshots as a swipeable row — Apple's intro pages, in a page of their own.
private struct HelpGuideSectionView: View {
    let section: HelpGuide.Section
    @State private var page = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.hhSamuel(28))
                    .textCase(.uppercase)
                    .accentText(.blue)
                Text(section.summary)
                    .font(.manrope(14, .medium))
                    .foregroundColor(LCColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, LCMetrics.screenMargin)

            TabView(selection: $page) {
                ForEach(Array(section.pages.enumerated()), id: \.element.id) { index, item in
                    HelpGuidePageView(page: item)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            // Fixed: a TabView cannot size to its pages. Tall enough for the
            // longest caption so nothing is clipped.
            .frame(height: 620)

            if section.pages.count > 1 {
                HStack(spacing: 10) {
                    ForEach(Array(section.pages.enumerated()), id: \.element.id) { index, _ in
                        NeumorphicCompletionDot(state: index == page ? .completed : .empty, size: 10)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page \(page + 1) of \(section.pages.count)")
            }
        }
    }
}

/// One screenshot with its lesson underneath.
private struct HelpGuidePageView: View {
    let page: HelpGuide.Page

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 330)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(LCColor.shadowDark.opacity(0.5), lineWidth: 0.5)
                )
                .shadow(color: LCColor.shadowDark, radius: 10, x: 6, y: 8)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(page.title)
                    .font(.manrope(17, .heavy))
                    .foregroundColor(LCColor.ink)
                Text(page.caption)
                    .font(.manrope(14, .medium))
                    .foregroundColor(LCColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, LCMetrics.screenMargin)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(page.title). \(page.caption)")
    }
}
