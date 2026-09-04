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
    
    var isFirstLaunch: Bool = false
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            if !isFirstLaunch {
                TopNav(pageTitle: "Help", isIdealList: false, showDrawer: $showDrawer, showingNewItemView: .constant(false))
            } else {
                // First-launch tutorial keeps the HELP wordmark, without the drawer control.
                Text("HELP")
                    .font(.hhSamuel(34))
                    .foregroundColor(LCColor.deepPink)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
            }

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
            .onAppear {
                if isFirstLaunch {
                    startAutoPlay()
                }
            }
            .onDisappear {
                stopAutoPlay()
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                // If user manually swipes to the last slide, dismiss and show settings
                if isFirstLaunch && newValue == 2 {
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

            if isFirstLaunch {
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
        }
        .background(LCColor.surface.ignoresSafeArea())
        .padding(.leading, MenuDrawer.contentInset)   // iPad sidebar inset (0 on iPhone)
        .overlay(alignment: .top){
            if !isFirstLaunch {
                MenuDrawer(showDrawer: $showDrawer,activeView:"help")
            }
        }
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
