//
//  MenuView.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//

import SwiftUI
import SwiftData
import FirebaseAuth

struct MenuView: View {
    @StateObject var viewModel = MainViewViewModel()
    /// LCColor's accents are statics, so switching palette has to rebuild the
    /// tree for the new colours to be read. Keying the signed-in content on the
    /// palette does exactly that, and leaves the auth view model alone.
    @ObservedObject private var theme = ThemeManager.shared
    @State private var showHelpOnFirstLaunch = false
    @State private var showOnboardingSettings = false
    @State private var hasCheckedFirstLaunch = false
    
    var body: some View {
        if viewModel.isSignedIn, !viewModel.currentUserId.isEmpty {
            accountView
                .id(theme.palette)
                // Shared neumorphic canvas behind the hosted list (never white).
                .background(LCColor.surface.ignoresSafeArea())
                .onAppear {
                    if !hasCheckedFirstLaunch {
                        checkAndShowOnboardingIfNeeded()
                        hasCheckedFirstLaunch = true
                    }
                }
                .sheet(isPresented: $showHelpOnFirstLaunch) {
                    HelpView(isFirstLaunch: true, onDismiss: {
                        markHelpAsSeen()
                        showHelpOnFirstLaunch = false
                        // After help, check if settings need to be shown
                        let settingsComing = checkAndShowSettingsIfNeeded()
                        // Preferences leads into the tour when it is coming;
                        // otherwise the tour follows the carousel straight away.
                        if !settingsComing { startFirstLaunchTour() }
                    })
                }
                .sheet(isPresented: $showOnboardingSettings) {
                    OnboardingSettingsView(onSave: {
                        showOnboardingSettings = false
                        startFirstLaunchTour()
                    })
                }
        }else{
            LoginView()
                // Keyed for the same reason the signed-in tree is: LCColor's
                // accents are statics SwiftUI cannot observe, so a subview whose
                // inputs have not changed keeps whatever colours it first read.
                // Logging out right after a palette change used to leave the
                // cover half repainted — a Present pink ground wearing the old
                // palette's capsules.
                .id(theme.palette)
                .onAppear {
                    hasCheckedFirstLaunch = false
                }
        }
    }
    
    @ViewBuilder
    var accountView: some View {
        IdealListView(userId: viewModel.currentUserId)
    }
    
    // Onboarding state is PER USER (OnboardingGate) — the old device-global
    // keys made every account after the first one on a device skip onboarding.
    private func checkAndShowOnboardingIfNeeded() {
        let uid = viewModel.currentUserId
        WalkthroughCoordinator.shared.setUser(uid)
        guard !uid.isEmpty else {
            AppLogger.debug(AppLogger.ui, "[Onboarding] check skipped: uid empty")
            return
        }
        let d = UserDefaults.standard
        AppLogger.debug(AppLogger.ui, "[Onboarding] check uid=\(uid) creation=\(String(describing: Auth.auth().currentUser?.metadata.creationDate)) userSeen=\(d.bool(forKey: OnboardingGate.seenHelpKey(uid: uid))) legacySeen=\(d.bool(forKey: OnboardingGate.legacySeenHelpKey))")

        // Account age decides whether the guided tours run on their own: a
        // returning user reinstalling the app knows it already.
        let isNewAccount = OnboardingGate.isNewAccount(
            creationDate: Auth.auth().currentUser?.metadata.creationDate)
        WalkthroughCoordinator.shared.setAccountAge(isNewAccount: isNewAccount)

        let outcome = OnboardingGate.decide(.init(
            isNewAccount: isNewAccount,
            userSeenHelp: d.bool(forKey: OnboardingGate.seenHelpKey(uid: uid)),
            userCompletedSettings: d.bool(forKey: OnboardingGate.completedSettingsKey(uid: uid)),
            legacySeenHelp: d.bool(forKey: OnboardingGate.legacySeenHelpKey),
            legacyCompletedSettings: d.bool(forKey: OnboardingGate.legacyCompletedSettingsKey)
        ))

        if outcome.markHelpSeen {
            // The carousel is off, so record it as done — otherwise this
            // decision would be taken again on every launch.
            d.set(true, forKey: OnboardingGate.seenHelpKey(uid: uid))
        }

        if outcome.migrateLegacyToUser {
            // Old account from the global-key era: adopt the device state as its
            // own. The globals are deliberately left in place for any other
            // legacy account on this device.
            d.set(true, forKey: OnboardingGate.seenHelpKey(uid: uid))
            d.set(d.bool(forKey: OnboardingGate.legacyCompletedSettingsKey),
                  forKey: OnboardingGate.completedSettingsKey(uid: uid))
        }

        AppLogger.debug(AppLogger.ui, "[Onboarding] decision=\(String(describing: outcome.decision)) migrate=\(outcome.migrateLegacyToUser)")
        switch outcome.decision {
        case .showHelp:
            // Small delay to ensure view is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showHelpOnFirstLaunch = true
            }
        case .showSettings:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showOnboardingSettings = true
            }
        case .none:
            // Nothing to set up. A brand-new account that has already been
            // through preferences still gets its tour.
            startFirstLaunchTour()
        }
    }

    /// - Returns: whether the preferences step is being presented.
    @discardableResult
    private func checkAndShowSettingsIfNeeded() -> Bool {
        let uid = viewModel.currentUserId
        guard !uid.isEmpty else { return false }
        let hasCompletedSettings = UserDefaults.standard.bool(
            forKey: OnboardingGate.completedSettingsKey(uid: uid))
        guard !hasCompletedSettings else { return false }
        // Small delay to ensure smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showOnboardingSettings = true
        }
        return true
    }

    /// The guided tour of the ideals list. The coordinator only lets it run for
    /// a newly created account; everyone else starts it from Help.
    private func startFirstLaunchTour() {
        let uid = viewModel.currentUserId
        guard !uid.isEmpty else { return }
        WalkthroughCoordinator.shared.setUser(uid)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            WalkthroughCoordinator.shared.start(.firstLaunchTour, onboardingFinished: true)
        }
    }

    private func markHelpAsSeen() {
        let uid = viewModel.currentUserId
        guard !uid.isEmpty else { return }
        UserDefaults.standard.set(true, forKey: OnboardingGate.seenHelpKey(uid: uid))
    }
}

#Preview {
    MenuView()
}
