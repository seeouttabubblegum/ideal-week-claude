//
//  IdealListItemLabelV2.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 13/6/25.
//
//  2026-07 neumorphic redesign (6a ideal row):
//  • Title — Newsreader italic, letterpress-imprinted, left-aligned.
//  • Per-ideal "NEXT:" block — blue "NEXT:" above pink time + BOLDER day,
//    all three lines character-justified into a near-square block at the
//    row's right edge (time & day each ≈ half the title height).
//  • Tracking dots — up to 13 sunken dots (pink done / blue over); fewer than
//    13 shows the actual count plus ONE long sunken capsule stretching to the
//    width 13 dots would occupy. The whole rail is centred in screen width.
//

import SwiftUI
import UIKit

struct IdealListItemLabelV2: View {
    let item: Ideal
    let background: Color
    let viewModel: IdealListViewViewModel
    @Binding var itemToEdit: Ideal
    var onTap: (() -> Void)? = nil // Optional custom tap handler
    /// When true, suppress Button tap (a drag gesture is in progress).
    var swipeActive: Bool = false
    /// When false, hide the category icon (e.g. Next? planned/wishlist rows).
    var showCategoryIcon: Bool = true
    /// When false, hide the tracking-dot rail entirely (Next? planned/wishlist
    /// rows use feathered divider lines instead — never dot-fill lines).
    var showDoneCircles: Bool = true
    /// When true, show schedule indicator (NEXT text or bell icon) on the right of the top row.
    var showSchedule: Bool = false
    /// User's preferred week start day; required for accurate "upcoming this week" calculations.
    var weekStartDay: String = WeekdayUtility.defaultWeekStartDay
    /// Called when the bell (unscheduled) icon is tapped. Defaults to opening edit view.
    var onScheduleTap: (() -> Void)? = nil
    /// Optional trailing view (e.g. add-to-plan button). Shown in the title row when provided.
    private var trailingContent: () -> AnyView

    /// Diagnostic overlay state. Toggled by long-press on the schedule indicator so users
    /// (and developers) can compare the row's rendered NEXT/bell against the raw stored
    /// fields. Useful when Firestore data drift causes the indicator to disagree with the
    /// edit view's day picker.
    @State private var showingScheduleDiagnostic: Bool = false

    init(item: Ideal, background: Color, viewModel: IdealListViewViewModel, itemToEdit: Binding<Ideal>, onTap: (() -> Void)? = nil, swipeActive: Bool = false, showCategoryIcon: Bool = true, showDoneCircles: Bool = true, showSchedule: Bool = false, weekStartDay: String = WeekdayUtility.defaultWeekStartDay, onScheduleTap: (() -> Void)? = nil) {
        self.item = item
        self.background = background
        self.viewModel = viewModel
        self._itemToEdit = itemToEdit
        self.onTap = onTap
        self.swipeActive = swipeActive
        self.showCategoryIcon = showCategoryIcon
        self.showDoneCircles = showDoneCircles
        self.showSchedule = showSchedule
        self.weekStartDay = weekStartDay
        self.onScheduleTap = onScheduleTap
        self.trailingContent = { AnyView(EmptyView()) }
    }

    init(item: Ideal, background: Color, viewModel: IdealListViewViewModel, itemToEdit: Binding<Ideal>, onTap: (() -> Void)? = nil, swipeActive: Bool = false, showCategoryIcon: Bool = true, showDoneCircles: Bool = true, showSchedule: Bool = false, weekStartDay: String = WeekdayUtility.defaultWeekStartDay, onScheduleTap: (() -> Void)? = nil, @ViewBuilder trailingContent: @escaping () -> some View) {
        self.item = item
        self.background = background
        self.viewModel = viewModel
        self._itemToEdit = itemToEdit
        self.onTap = onTap
        self.swipeActive = swipeActive
        self.showCategoryIcon = showCategoryIcon
        self.showDoneCircles = showDoneCircles
        self.showSchedule = showSchedule
        self.weekStartDay = weekStartDay
        self.onScheduleTap = onScheduleTap
        self.trailingContent = { AnyView(trailingContent()) }
    }

    var intTargetState: Int {
        if(item.targetCount == "6+"){
            return 6
        }
        return Int(item.targetCount) ?? 0
    }

    /// Tracking dot diameter (handoff: 17px sunken dots, 6px gaps).
    private let dotSize: CGFloat = 17
    private let dotGap: CGFloat = 6
    /// Width the maximum 13 completion dots occupy: 13 × 17 + 12 gaps of 6 = 293.
    /// The rail (dots + trailing long capsule) is always this wide, centred.
    private var dotsRailWidth: CGFloat { 13 * dotSize + 12 * dotGap }

    private var scheduleDisplay: IdealScheduleFormatter.Display {
        // For planned items (Next? tab), the ideal's startDate is next week's start —
        // use it as the anchor so we compute occurrences in that week, not the current one.
        let anchor: Date? = item.startDate > 0 ? Date(timeIntervalSince1970: item.startDate) : nil
        return IdealScheduleFormatter.display(
            schedules: item.effectiveReminderSchedules,
            consumedCount: max(0, item.doneCount - item.scheduleBaselineDoneCount),
            weekStartDay: weekStartDay,
            weekAnchor: anchor,
            now: DateProviderService.shared.now()
        )
    }

    /// Long-press diagnostic: human-readable dump of the ideal's schedule fields.
    /// Surfaced via `.alert(...)` so the user can sanity-check the stored data against
    /// what the row is rendering — useful when stale/corrupt Firestore data causes the
    /// NEXT label to disagree with the schedule picker in the edit view.
    private var scheduleDiagnosticText: String {
        let dayNames = ["?", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let groupsStr = item.effectiveReminderSchedules.enumerated().map { idx, s -> String in
            let days = s.days.sorted().map { ($0 >= 1 && $0 <= 7) ? dayNames[$0] : "?" }.joined(separator: ",")
            let h = Int(s.time) / 3600
            let m = (Int(s.time) % 3600) / 60
            return String(format: "  #%d [%@] %02d:%02d", idx + 1, days, h, m)
        }.joined(separator: "\n")
        let startDateStr: String = {
            guard item.startDate > 0 else { return "0 (wishlist)" }
            let d = Date(timeIntervalSince1970: item.startDate)
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd EEE"
            return f.string(from: d)
        }()
        return """
        reminders (\(item.effectiveReminderSchedules.count) groups):
        \(groupsStr.isEmpty ? "  (none)" : groupsStr)
        doneCount: \(item.doneCount) / target \(item.targetCount)
        startDate: \(startDateStr)
        reminderIds: \(item.reminderIds.count) ids
        weekStartDay: \(weekStartDay)
        """
    }

    private func accessibleScheduleLabel(for display: IdealScheduleFormatter.Display) -> String? {
        let dayName: [String: String] = ["SUN": "Sunday", "MON": "Monday", "TUE": "Tuesday", "WED": "Wednesday", "THU": "Thursday", "FRI": "Friday", "SAT": "Saturday"]
        func humanize(_ raw: String) -> String {
            let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { return raw }
            let time = parts[0].replacingOccurrences(of: " A", with: " AM").replacingOccurrences(of: " P", with: " PM")
            let day = dayName[parts[1]] ?? parts[1]
            return "\(time) \(day)"
        }
        switch display {
        case .next(let text):
            let body = text.replacingOccurrences(of: "NEXT: ", with: "")
            return "Next reminder \(humanize(body))"
        case .unscheduled:
            return nil
        }
    }

    @ViewBuilder
    private var scheduleIndicator: some View {
        // No TimelineView needed: display is driven by doneCount, not wall-clock time.
        // When doneCount changes (Firestore write), the parent re-emits and the row
        // re-renders with the new indicator automatically.
        Group {
            switch scheduleDisplay {
            case .unscheduled:
                Button {
                    guard !swipeActive else { return }
                    HapticFeedback.impact(style: .light)
                    if let onScheduleTap = onScheduleTap {
                        onScheduleTap()
                    } else {
                        itemToEdit = item
                        viewModel.showingEditItemView = true
                    }
                } label: {
                    // Handoff: raised button SHAPED to the bell glyph (not in a
                    // circle), tilted 37°, surface-coloured — visible only through
                    // its neumorphic drop-shadow pair. The glyph is the handoff's
                    // own bell SVG (31×33), not an SF-symbol stand-in.
                    HandoffBellGlyph()
                        .fill(LCColor.surface)
                        .frame(width: 31, height: 33)
                        .rotationEffect(.degrees(37))
                        .shadow(color: LCColor.shadowDark, radius: 0.7, x: 1.6, y: 2)
                        .shadow(color: LCColor.shadowLight, radius: 0.5, x: -1.6, y: -1.6)
                        .padding(8)            // ~44pt tap target
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Bell's bottom edge sits on the ideal title's baseline.
                .alignmentGuide(.lastTextBaseline) { $0[.bottom] - 8 }
                .accessibilityLabel("Add schedule")
                .accessibilityHint("Opens edit view to set a reminder day and time")
            case .next(let text):
                // Handoff 6a: a justified, near-square block at the row's right —
                //   NEXT:   (blue, Manrope heavy)
                //   12:45P  (pink, smaller)
                //   WED     (pink, BOLDER than the time — weeks are day-driven)
                // Every line's characters are spread edge-to-edge across the same
                // fixed width (per-character justification, like the HTML's
                // space-between spans), so the block reads as one solid square.
                // Time & day are each about half the ideal-title height.
                let body = text.replacingOccurrences(of: "NEXT: ", with: "")
                let parts = body.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                // Keep the space in "12:45 P" — the handoff justifies it as its own
                // character slot, which is what keeps the time's letter gaps tight.
                let timePart = parts.first ?? ""
                let dayPart = parts.count > 1 ? parts[1] : ""
                VStack(alignment: .trailing, spacing: 0) {
                    JustifiedCharsLine(text: "NEXT:", size: 13, color: LCColor.blue)
                        .padding(.bottom, 2)
                    JustifiedCharsLine(text: timePart, size: 11, color: LCColor.pink)
                    JustifiedCharsLine(text: dayPart, size: 13, color: LCColor.pink, stroke: 0.4)
                        .padding(.top, 1)
                }
                .frame(width: 42)
                // Day's baseline aligns with the title baseline (HStack alignment);
                // the block grows upward, tucked into the title's ascent.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibleScheduleLabel(for: scheduleDisplay) ?? text)
            }
        }
        // Long-press surfaces the raw stored fields so users can compare what the
        // formatter rendered against what's actually in the model. Useful for catching
        // data-drift between the row and the edit view's day picker.
        // `simultaneousGesture` (not `onLongPressGesture`) so it still fires when the
        // indicator is the bell Button (.unscheduled), whose own tap would otherwise
        // swallow a plain long-press.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                HapticFeedback.impact(style: .medium)
                showingScheduleDiagnostic = true
            }
        )
        .alert("Schedule Data", isPresented: $showingScheduleDiagnostic) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(scheduleDiagnosticText)
        }
    }

    var body: some View {
        Button(action: {
            guard !swipeActive else { return }
            HapticFeedback.impact(style: .light)
            if let onTap = onTap {
                onTap()
            } else {
                itemToEdit = item
                viewModel.showingEditItemView = true
            }
        }) {
            // Handoff 6a row: title left-aligned with the NEXT block / bell at the
            // trailing edge (day baseline on the title baseline), then a 16pt gap
            // to the centred tracking-dot rail.
            VStack(alignment: .center, spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 16) {
                    Text(item.title)
                        .font(.idealTitle(26))
                        .foregroundColor(LCColor.ink)
                        .imprinted()
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if showCategoryIcon, let category = Category(rawValue: item.category) {
                        // LC line icon, template-tinted blue (icon family from the
                        // handoff — never an SF-symbol stand-in).
                        Image(category.lcCategoryIconV2())
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .accentText(.blue)
                            .frame(width: 24, height: 24)
                            .alignmentGuide(.lastTextBaseline) { $0[.bottom] - 2 }
                            .accessibilityHidden(true)
                    }
                    trailingContent()
                    if showSchedule {
                        scheduleIndicator
                    }
                }
                .padding(.bottom, showDoneCircles ? 16 : 0)
                if showDoneCircles {
                    // Dots + trailing long capsule as one fixed-width rail, centred
                    // in the screen. When 13 dots are shown they fill the rail and
                    // the capsule is omitted.
                    let dotsShown = item.doneCount >= intTargetState
                        ? intTargetState + max(0, min(item.doneCount, 13) - intTargetState)
                        : intTargetState
                    HStack(spacing: dotGap) {
                        if item.doneCount >= intTargetState {
                            ForEach(0..<intTargetState, id: \.self) { _ in
                                NeumorphicCompletionDot(state: .completed, size: dotSize)
                            }
                            let overCap = min(item.doneCount, 13) - intTargetState
                            ForEach(0..<max(0, overCap), id: \.self) { _ in
                                NeumorphicCompletionDot(state: .overCompleted, size: dotSize)
                            }
                        } else {
                            ForEach(0..<item.doneCount, id: \.self) { _ in
                                NeumorphicCompletionDot(state: .completed, size: dotSize)
                            }
                            ForEach(0..<(intTargetState - item.doneCount), id: \.self) { _ in
                                NeumorphicCompletionDot(state: .empty, size: dotSize)
                            }
                        }
                        if dotsShown < 13 {
                            NeumorphicTrack(height: dotSize)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(width: dotsRailWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(item.doneCount) of \(intTargetState) done")
                }
                // showDoneCircles == false → no rail at all: Next? rows are
                // separated by feathered dividers drawn by the parent list
                // (handoff 1d: divider lines, not dot-fill lines).
            }
            .padding(.horizontal, pointsFromArtboardPixels(77))   // 77px side gutter
            .padding(.vertical, 0)
        }
        .buttonStyle(CardTapStyle(swipeActive: swipeActive))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(item.title), \(item.category)")
        .accessibilityAction(named: "Add schedule") {
            if showSchedule, item.effectiveReminderSchedules.isEmpty {
                if let onScheduleTap = onScheduleTap {
                    onScheduleTap()
                } else {
                    itemToEdit = item
                    viewModel.showingEditItemView = true
                }
            }
        }
        // NOTE: no .cornerRadius() here — it would clip the schedule overlay that
        // grows above the title. The rounded press tint lives in CardTapStyle.
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 0)
    }
}

/// The handoff 6a bell, traced from its SVG (viewBox 26×28): dome, top stem
/// nub (a round-capped 2.2-unit stroke, added as a stroked outline), and the
/// clapper arc. One filled shape so the neumorphic drop-shadow pair wraps the
/// whole silhouette exactly like the design's CSS filter.
private struct HandoffBellGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 26
        let sy = rect.height / 28
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var p = Path()
        // Dome: M13 3.6 c…z
        p.move(to: pt(13, 3.6))
        p.addCurve(to: pt(7, 10.0), control1: pt(9.4, 3.6), control2: pt(7, 6.2))
        p.addCurve(to: pt(4.6, 18.3), control1: pt(7, 14.6), control2: pt(6, 16.7))
        p.addCurve(to: pt(5.2, 20.0), control1: pt(4.1, 18.9), control2: pt(4.4, 19.9))
        p.addCurve(to: pt(20.8, 20.0), control1: pt(8.4, 20.5), control2: pt(17.6, 20.5))
        p.addCurve(to: pt(21.4, 18.3), control1: pt(21.6, 19.9), control2: pt(21.9, 18.9))
        p.addCurve(to: pt(19.0, 10.0), control1: pt(20.0, 16.7), control2: pt(19.0, 14.6))
        p.addCurve(to: pt(13, 3.6), control1: pt(19, 6.2), control2: pt(16.6, 3.6))
        p.closeSubpath()
        // Clapper: M10.4 22.6 c… s… z
        p.move(to: pt(10.4, 22.6))
        p.addCurve(to: pt(13.0, 25.2), control1: pt(10.7, 24.2), control2: pt(11.7, 25.2))
        p.addCurve(to: pt(15.6, 22.6), control1: pt(14.3, 25.2), control2: pt(15.3, 24.2))
        p.closeSubpath()
        // Stem nub: M13 1.8 v1.8, stroke 2.2 round-capped.
        var stem = Path()
        stem.move(to: pt(13, 1.8))
        stem.addLine(to: pt(13, 3.6))
        p.addPath(stem.strokedPath(StrokeStyle(lineWidth: 2.2 * sx, lineCap: .round)))
        return p
    }
}

/// One line of the NEXT block: the characters are distributed edge-to-edge
/// (space-between) across the block's fixed width, so all lines share the same
/// left and right verticals → a justified square block.
///
/// Matches the handoff's CSS exactly:
/// • `line-height:1` — the line box is exactly `size` tall (the natural Manrope
///   line height is ~1.36×, which read as extra vertical air between the lines);
///   glyphs centre in the box just like CSS negative half-leading.
/// • `-webkit-text-stroke` — `stroke > 0` thickens each glyph by stacking
///   offset copies half the stroke width out in eight directions (the day row
///   is deliberately BOLDER than ExtraBold — weeks are day-driven).
private struct JustifiedCharsLine: View {
    let text: String
    let size: CGFloat
    let color: Color
    var stroke: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, ch in
                if index > 0 { Spacer(minLength: 0) }
                strokedChar(String(ch))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: size)
    }

    @ViewBuilder
    private func strokedChar(_ ch: String) -> some View {
        let glyph = Text(ch)
            .font(.manrope(size, .heavy))
            .foregroundColor(color)
            .lineLimit(1)
            .fixedSize()
        if stroke > 0 {
            // CSS text-stroke is centred on the outline, so half its width lands
            // outside the glyph. Cardinal copies at r, diagonals at r/√2.
            let r = stroke / 2
            let d = r * 0.7071
            glyph.background {
                ZStack {
                    glyph.offset(x: r, y: 0)
                    glyph.offset(x: -r, y: 0)
                    glyph.offset(x: 0, y: r)
                    glyph.offset(x: 0, y: -r)
                    glyph.offset(x: d, y: d)
                    glyph.offset(x: d, y: -d)
                    glyph.offset(x: -d, y: d)
                    glyph.offset(x: -d, y: -d)
                }
            }
        } else {
            glyph
        }
    }
}

/// Card press style: scale + dim on press, no default Button chrome.
/// Inner buttons (e.g. ADD) take priority over this outer Button automatically.
private struct CardTapStyle: ButtonStyle {
    /// While a swipe is in progress the finger stays down, so `isPressed` would
    /// otherwise hold the card in its pressed (grey) state for the whole swipe.
    /// Suppress the press tint/scale then so the card stays white while swiping.
    var swipeActive: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !swipeActive
        configuration.label
            // Rounded press tint applied as a BACKGROUND SHAPE (not a clip) so the
            // card itself never clips its content — this lets the NEXT schedule block
            // grow up past the title into the gap above without being cut off.
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(pressed ? Color.black.opacity(0.06) : Color.clear))
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: pressed)
    }
}


#if DEBUG
private struct IdealListItemLabelV2_PreviewHost: View {
    @StateObject private var vm = IdealListViewViewModel()
    @State private var edit = PreviewData.sampleIdeal

    private func row(_ item: Ideal) -> some View {
        IdealListItemLabelV2(
            item: item,
            background: LCColor.pink,
            viewModel: vm,
            itemToEdit: $edit,
            onTap: {},
            showCategoryIcon: false,
            showSchedule: true,
            weekStartDay: PreviewData.weekStartDay
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            row(PreviewData.ideal("Try New Glasses", category: .fix, done: 0, target: "5", days: [PreviewData.futureDay])) // NEXT
            NeuFeatheredDivider().padding(.vertical, 30)
            row(PreviewData.ideal("Walk The Dog", category: .fitness, done: 3, target: "7"))                                // partial + bell
            NeuFeatheredDivider().padding(.vertical, 30)
            row(PreviewData.ideal("Manage Carpet Install", category: .fix, done: 1, target: "1"))                           // done
        }
        .padding(.vertical, 24)
        .background(LCColor.surface)
    }
}

#Preview("Ideal row states") {
    IdealListItemLabelV2_PreviewHost()
}
#endif
