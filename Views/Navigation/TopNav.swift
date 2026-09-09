//
//  TopNav.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 26/8/25.
//

import SwiftData
import SwiftUI

// When false, applies navigationDestination; when true, leaves content unchanged (caller handles destination).
private struct ConditionalNavigationDestinationModifier<Destination: View>: ViewModifier {
    let applyModifier: Bool
    @Binding var isPresented: Bool
    @ViewBuilder let destination: () -> Destination

    func body(content: Content) -> some View {
        if applyModifier {
            content.navigationDestination(isPresented: $isPresented, destination: destination)
        } else {
            content
        }
    }
}

/// Raised YELLOW rounded-rect "NEXT" pill (handoff 6a) — depresses to sunken
/// while pressed like every raised control.
private struct NeuNextPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(NeuPressableBackground(
                shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                fill: LCColor.yellow,
                cssOffset: LCNeumorphism.raisedOffsetMedium,
                cssBlur: LCNeumorphism.raisedBlurMedium,
                pressed: configuration.isPressed))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct TopNav: View {
    @Query var storedAccentColors: [MainSettings]
    var accentColor: Color {
        // Follows the palette chosen in Settings (LCPalette).
        LCColor.pink
    }
    let pageTitle: String
    let isIdealList: Bool
    @Binding var showDrawer: Bool
    @Binding var showingNewItemView: Bool
    /// When non-nil and isIdealList, show a progress icon to the left of the gear that links to the progress page.
    var userId: String? = nil
    /// When non-nil and not isIdealList (e.g. on progress page), show an ideals icon to the left of the gear that links to the ideals page.
    var idealsUserId: String? = nil
    /// When true (My Progress / 1h header), the drawer gear uses the BLUE 30pt
    /// settings glyph instead of the default pink 24pt one (handoff: 6a header is
    /// pink, the 1h "My Progress" header is blue).
    var usesBlueDrawerGlyph: Bool = false
    /// When provided (e.g. when TopNav is inside a List), parent owns navigation; TopNav will not attach navigationDestination.
    var externalGoToProgress: Binding<Bool>? = nil
    var externalGoToIdeals: Binding<Bool>? = nil
    /// When provided (ideals page), show the "NEXT" pill that opens the planning page.
    var onNextTapped: (() -> Void)? = nil
    /// Grouped completion (3 values, outer→inner ring, then centre pie) for the
    /// header progress icon. When non-empty on the ideal list, the icon (tucked
    /// next to "MY" in the wordmark) links to the progress page.
    var progressRings: [Double] = []

    @State private var goToProgress = false
    @State private var goToIdeals = false

    /// Static motivational line shown beside the wordmark (handoff 6a display copy).
    private let headerQuote = "Small actions compound into meaningful change, but what makes those actions work isn't the action itself. It's the system behind it."

    private var effectiveGoToProgress: Binding<Bool> {
        if let b = externalGoToProgress { return b }
        return $goToProgress
    }
    private var effectiveGoToIdeals: Binding<Bool> {
        if let b = externalGoToIdeals { return b }
        return $goToIdeals
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isIdealList {
                idealListHeader
            } else {
                titleHeader
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(ConditionalNavigationDestinationModifier(
            applyModifier: externalGoToProgress == nil,
            isPresented: effectiveGoToProgress,
            destination: {
                if let userId = userId {
                    HistoryProgressView(userId: userId)
                } else {
                    EmptyView()
                }
            }
        ))
        .modifier(ConditionalNavigationDestinationModifier(
            applyModifier: externalGoToIdeals == nil,
            isPresented: effectiveGoToIdeals,
            destination: {
                if let idealsUserId = idealsUserId {
                    IdealListView(userId: idealsUserId, initialLoaderMinVisibleDuration: 0.45)
                } else {
                    EmptyView()
                }
            }
        ))
    }

    // MARK: - Ideal-list header (handoff 6a)
    //
    // Left: stacked "MY / IDEAL / WEEK" wordmark (HH Samuel, blue, ~2× body)
    // with the progress rings tucked next to "MY", and the yellow NEXT pill
    // below. Middle: the motivational quote, aligned with "IDEAL WEEK".
    // Top-right: raised settings circle (opens the drawer).

    private var idealListHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                wordmark
                // "NEXT" pill — opens the planning ("Next?") page.
                if let onNextTapped = onNextTapped {
                    Button {
                        HapticFeedback.impact()
                        onNextTapped()
                    } label: {
                        HStack(spacing: 6) {
                            Text("NEXT")
                                .font(.manrope(15, .heavy))
                                // Sits ON the tertiary-role NEXT pill.
                                .accentText(.pink, on: .yellow)
                                .lineLimit(1)
                                .fixedSize()
                            Image("Next Puzzle_Blue")
                                .renderingMode(.template)
                                .resizable().scaledToFit()
                                .accentText(.blue)
                                .frame(width: 20, height: 20)
                        }
                        .fixedSize()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(NeuNextPillButtonStyle())
                    .accessibilityLabel("Next week planning")
                }
            }
            // Quote block — runs all the way to the header's right edge
            // (handoff: `flex:1` with no right margin), horizontally aligned
            // with the "IDEAL WEEK" lines. The settings button does NOT sit
            // beside it — see the overlay below.
            Text(headerQuote)
                .font(.manrope(15, .medium))
                // Body copy, so it never takes the lightest colour: a paragraph
                // wearing the silhouette shadow reads as outlined and heavy.
                .accentBodyText(.pink)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 64)
        }
        .padding(.leading, 22)
        .padding(.trailing, 22)
        .padding(.top, 16)
        .padding(.bottom, 12)
        // Handoff 6a pins the settings circle with `position:absolute;
        // top:16px; right:22px`, so it floats ABOVE the row and claims no
        // horizontal space. As an HStack sibling it was stealing ~56pt
        // (button + gap) from the quote, squeezing it left and leaving the
        // right side empty. The quote starts 64pt down, well clear of the
        // 40pt button, so nothing collides.
        .overlay(alignment: .topTrailing) {
            // iPad: the menu is a permanent left sidebar, so the drawer toggle
            // would open a second copy — hide it. iPhone unchanged.
            if !MenuDrawer.isPersistentSidebar {
                drawerButton
                    .padding(.top, 16)
                    .padding(.trailing, 22)
            }
        }
    }

    /// "MY / IDEAL / WEEK" — HH Samuel, blue, tight stacked lines; the grouped
    /// progress icon sits next to "MY" and links to the progress page.
    private var wordmark: some View {
        // HH Samuel renders at ~0.8 line-height in the handoff; negative VStack
        // spacing tightens the stacked lines to match.
        VStack(alignment: .leading, spacing: -12) {
            HStack(alignment: .center, spacing: 4) {
                Text("MY")
                    .font(.hhSamuel(58))
                    .accentOutlinedText(.blue, outline: .blue, width: 1.2)
                    .accessibilityLabel("My Ideal Week")
                if userId != nil, !progressRings.isEmpty {
                    Button {
                        guard !effectiveGoToProgress.wrappedValue else { return }
                        HapticFeedback.impact()
                        withAnimation(.easeInOut(duration: 1)) {
                            showDrawer = false
                            effectiveGoToProgress.wrappedValue = true
                        }
                    } label: {
                        GroupedProgressRingsIcon(progress: progressRings)
                            .frame(width: 42, height: 42)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Progress")
                }
            }
            Text("IDEAL")
                .font(.hhSamuel(58))
                .accentOutlinedText(.blue, outline: .blue, width: 1.2)
                .accessibilityHidden(true)
            Text("WEEK")
                .font(.hhSamuel(58))
                .accentOutlinedText(.blue, outline: .blue, width: 1.2)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Title header (Profile / Progress / Settings / Help)

    private var titleHeader: some View {
        HStack(alignment: .center) {
            Text(pageTitle.uppercased())
                .font(.hhSamuel(34))
                .accentText(.pink)
                .lineLimit(1)            // keep on one line; shrink to fit beside the controls
                .minimumScaleFactor(0.55)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            HStack(spacing: 12) {
                // Ideals icon (on Progress page) – Button for consistent behavior
                if !isIdealList, idealsUserId != nil {
                    Button {
                        guard !effectiveGoToIdeals.wrappedValue else { return }
                        HapticFeedback.impact()
                        IdealListView.requestResetToAllTabOnNextAppear()
                        withAnimation(.easeInOut(duration: 1)) {
                            showDrawer = false
                            effectiveGoToIdeals.wrappedValue = true
                        }
                    } label: {
                        // Pink checklist — three rules, each ticked. (The
                        // handoff's vertical bars read as an audio waveform.)
                        IdealsChecklistGlyph()
                            .stroke(LCColor.glyph(.pink), style: StrokeStyle(
                                lineWidth: 2.0, lineCap: .round, lineJoin: .round))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(NeuCircleButtonStyle(diameter: 40))
                    .accessibilityLabel("Ideals")
                }
                if !MenuDrawer.isPersistentSidebar {
                    drawerButton
                }
            }
        }
        .padding(.horizontal, LCMetrics.screenMargin)
        .padding(.vertical, 12)
    }

    // MARK: - Shared controls

    /// Settings toggle (LC "Solid Settings" — opens the drawer). Raised surface
    /// circle. Pink 24pt glyph on the 6a header; blue 30pt on the 1h "My
    /// Progress" header (`usesBlueDrawerGlyph`).
    private var drawerButton: some View {
        Button {
            HapticFeedback.impact()
            showDrawer = true
        } label: {
            Image(usesBlueDrawerGlyph ? "Solid Settings_Blue" : "Solid Settings_Pink")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundColor(usesBlueDrawerGlyph ? LCColor.glyph(.blue) : LCColor.glyph(.pink))
                .frame(width: usesBlueDrawerGlyph ? 30 : 24,
                       height: usesBlueDrawerGlyph ? 30 : 24)
        }
        .buttonStyle(NeuCircleButtonStyle(diameter: 40))
        .accessibilityLabel("Settings")
    }
}

// The checklist mark itself lives in Views/Components/IdealsChecklistGlyph.swift
// — the menu drawer's "My Ideals" row draws the same symbol.

#if DEBUG
#Preview {
    VStack(spacing: 24) {
        TopNav(
            pageTitle: "My Ideal Week",
            isIdealList: true,
            showDrawer: .constant(false),
            showingNewItemView: .constant(false),
            userId: PreviewData.userId,
            onNextTapped: {},
            progressRings: [0.8, 0.5, 0.3]
        )
        TopNav(
            pageTitle: "My Progress",
            isIdealList: false,
            showDrawer: .constant(false),
            showingNewItemView: .constant(false),
            idealsUserId: PreviewData.userId
        )
    }
    .background(LCColor.surface)
    .modelContainer(for: MainSettings.self, inMemory: true)
}
#endif
