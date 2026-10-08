//
//  DumpFlowView.swift
//  The Ideal Week
//
//  The first-week dump (client, 2026-10-02; book chapter 9). Screens, in
//  order: the dump → one "Which of these are your …?" per F (Fix → Finance),
//  each with how often under every pick and, when nothing is left to pick,
//  a field to add ideas for that F → Finance saves. Logic lives in `DumpFlowState`;
//  the save is the weekly prompt's own (`PlanningSheetViewModel.savePlanning`
//  into the current week), so the duplicate guard, plan records and the
//  in-flight guard all come with it. No PIN.
//
//  The same screens serve the second week's weekly prompt (client,
//  2026-10-08): no dump screen, last week's ideals each under its own F, the
//  Next? list offered on every F, and an add field on every F in both runs.
//

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseFirestore

struct DumpFlowView: View {
    @ObservedObject private var coordinator = DumpFlowCoordinator.shared
    @StateObject private var planning = PlanningSheetViewModel()
    @Query private var storedTempSettings: [MainSettings]

    private let mode: DumpFlowMode
    /// Second week: the last active week's ideals not already in this week.
    private let lastWeekIdeals: [Ideal]
    /// Second week: told whether anything was saved (the first week reports
    /// to `DumpFlowCoordinator` instead).
    private let onFinish: ((Bool) -> Void)?

    @State private var state: DumpFlowState

    init(mode: DumpFlowMode = .firstWeek, lastWeekIdeals: [Ideal] = [],
         onFinish: ((Bool) -> Void)? = nil) {
        self.mode = mode
        self.lastWeekIdeals = lastWeekIdeals
        self.onFinish = onFinish
        _state = State(initialValue: DumpFlowState(mode: mode))
    }
    @State private var draftTitle = ""
    /// The add field on each F's screen, one per F.
    @State private var addDrafts: [Category: String] = [:]
    @State private var notice: String?
    @State private var hasLoadedNextList = false
    @State private var showLeaveConfirm = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    /// The skipped-duplicates notice ends the flow once it is read.
    @State private var finishAfterAlert = false
    @FocusState private var dumpFieldFocused: Bool

    private let repository = IdealRepository()

    private var uid: String { Auth.auth().currentUser?.uid ?? "" }
    private var weekStartDay: String { storedTempSettings.first?.week_start_day ?? "Monday" }

    var body: some View {
        VStack(spacing: 0) {
            NeuSheetHeader(title: DumpFlowCopy.headerTitle(for: mode), titleSize: 26,
                           onClose: { showLeaveConfirm = true })
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    stageContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, LCMetrics.screenMargin)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            bottomBar
        }
        .background(LCColor.surface.ignoresSafeArea())
        .onAppear(perform: loadEntries)
        .alert(DumpFlowCopy.leaveTitle(for: mode), isPresented: $showLeaveConfirm) {
            Button(DumpFlowCopy.leaveCancel, role: .cancel) {}
            Button(DumpFlowCopy.leaveConfirm, role: .destructive) {
                finish(saved: false)
            }
        } message: {
            Text(DumpFlowCopy.leaveMessage(for: mode))
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button(DumpFlowCopy.okButton) {
                if finishAfterAlert {
                    finishAfterAlert = false
                    finish(saved: true)
                }
            }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Stages

    @ViewBuilder
    private var stageContent: some View {
        switch state.stage {
        case .dump:
            dumpStage
        case .sort(let category):
            sortStage(category)
        }
    }

    private var dumpStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            stageTitle(DumpFlowCopy.dumpTitle)
            stageMessage(DumpFlowCopy.dumpMessage)
            addField(placeholder: DumpFlowCopy.dumpPlaceholder, text: $draftTitle,
                     focus: $dumpFieldFocused) { addFromDumpField() }
            if let notice {
                Text(notice)
                    .font(.manrope(14, .bold))
                    .accentText(.pink)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(state.entries) { entry in
                    HStack(spacing: 12) {
                        entryTitle(entry.title)
                        Spacer(minLength: 8)
                        if entry.isNew {
                            NeuCloseButton(action: { remove(entry) }, diameter: 30)
                                .accessibilityLabel("Remove \(entry.title)")
                        }
                    }
                    .padding(.vertical, 12)
                    NeuFeatheredDivider()
                }
            }
        }
    }

    /// One F: heart what belongs here and set how often right under it. The
    /// add field is always there (client, 2026-10-08); when nothing is left
    /// to pick, the screen also says so.
    private func sortStage(_ category: Category) -> some View {
        let shown = state.entries(for: category)
        let nothingLeft = state.nothingLeftToPick(for: category)
        return VStack(alignment: .leading, spacing: 12) {
            // The F's group, as the book names it.
            if let group = DumpFlowCopy.progress(for: state.stage) {
                Text(group)
                    .font(.manrope(15, .heavy))
                    .accentText(.pink)
            }
            stageTitle(DumpFlowCopy.sortTitle(category))
            stageMessage(category.subheading)
            if nothingLeft {
                Text(DumpFlowCopy.nothingLeft(category))
                    .font(.manrope(16, .bold))
                    .accentText(.pink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                stageMessage(DumpFlowCopy.sortHint(for: mode))
            }
            addField(placeholder: DumpFlowCopy.addPlaceholder(category),
                     text: Binding(get: { addDrafts[category] ?? "" },
                                   set: { addDrafts[category] = $0 })) {
                addFromPassField(category)
            }
            if let notice {
                Text(notice)
                    .font(.manrope(14, .bold))
                    .accentText(.pink)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(shown) { entry in
                    let picked = state.isPicked(entry.id, for: category)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Button {
                                togglePick(entry.id, category)
                            } label: {
                                HStack {
                                    entryTitle(entry.title)
                                    Spacer(minLength: 8)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            NeuHeartSelectButton(isSelected: picked) { togglePick(entry.id, category) }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(picked ? .isSelected : [])
                        if picked {
                            Text(DumpFlowCopy.howOftenLabel)
                                .font(.manrope(14, .heavy))
                                .foregroundColor(LCColor.ink)
                            HowOftenSliderView(value: Binding(
                                get: { state.target(for: entry.id) },
                                set: { state.setTarget($0, for: entry.id) }
                            ))
                        }
                    }
                    .padding(.vertical, 12)
                    NeuFeatheredDivider()
                }
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 14) {
            if canGoBack {
                NeuBackCircleButton(action: goBack, diameter: 48)
                    .accessibilityLabel(DumpFlowCopy.backButton)
            }
            Button(action: goForward) {
                ZStack {
                    if planning.isSaving {
                        ProgressView()
                    } else {
                        Text(state.isLastStage ? DumpFlowCopy.saveButton : DumpFlowCopy.continueButton)
                            .font(.manrope(20, .heavy))
                            .accentText(.pink)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(NextCTAButtonStyle())
            .disabled(!state.canContinue || planning.isSaving)
            .opacity(state.canContinue ? 1 : 0.45)
        }
        .padding(.horizontal, LCMetrics.screenMargin)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(LCColor.surface)
    }

    /// The first screen of the run has nothing behind it.
    private var canGoBack: Bool {
        switch mode {
        case .firstWeek: return state.stage != .dump
        case .secondWeek: return state.stage != .sort(DumpFlowState.sortOrder[0])
        }
    }

    // MARK: - Small pieces

    private func stageTitle(_ text: String) -> some View {
        Text(text)
            .font(.manrope(24, .heavy))
            .foregroundColor(LCColor.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func stageMessage(_ text: String) -> some View {
        Text(text)
            .font(.manrope(16, .medium))
            .foregroundColor(LCColor.ink.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func entryTitle(_ title: String) -> some View {
        Text(title)
            .font(.idealTitle(21))
            .foregroundColor(LCColor.ink)
            .imprinted()
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A sunken title field with its Add button — the dump and an F with
    /// nothing left to pick both use it.
    private func addField(placeholder: String, text: Binding<String>,
                          focus: FocusState<Bool>.Binding? = nil,
                          onAdd: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Group {
                if let focus {
                    TextField(placeholder, text: text).focused(focus)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(.manrope(16, .medium))
            .foregroundColor(LCColor.ink)
            .submitLabel(.done)
            .onSubmit(onAdd)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .neuSunkenCapsule()
            addButton(enabled: !DumpFlowState.cleanTitle(text.wrappedValue).isEmpty, action: onAdd)
        }
    }

    private func addButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(DumpFlowCopy.addButton)
                .font(.manrope(16, .heavy))
                .accentText(.pink)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .neuRaised(cornerRadius: 22)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }

    // MARK: - Actions

    private func togglePick(_ id: String, _ category: Category) {
        HapticFeedback.impact()
        withAnimation(.easeOut(duration: 0.15)) {
            state.togglePick(id, for: category)
        }
    }

    private func goForward() {
        dumpFieldFocused = false
        notice = nil
        if state.isLastStage {
            save()
            return
        }
        HapticFeedback.impact()
        withAnimation(.easeOut(duration: 0.2)) {
            state.goNext()
        }
    }

    private func goBack() {
        notice = nil
        HapticFeedback.impact()
        withAnimation(.easeOut(duration: 0.2)) {
            state.goBack()
        }
    }

    private func addFromDumpField() {
        if addEntry(title: draftTitle, pickedFor: nil) {
            draftTitle = ""
            dumpFieldFocused = true
        }
    }

    private func addFromPassField(_ category: Category) {
        if addEntry(title: addDrafts[category] ?? "", pickedFor: category) {
            addDrafts[category] = ""
        }
    }

    /// Saves the idea as a Next? item right away — the dump is the Next?
    /// list, so leaving half way keeps everything written so far.
    @discardableResult
    private func addEntry(title raw: String, pickedFor category: Category?) -> Bool {
        let title = DumpFlowState.cleanTitle(raw)
        guard !title.isEmpty, !uid.isEmpty else { return false }
        guard !state.contains(title: title) else {
            notice = DumpFlowCopy.alreadyInDump
            return false
        }
        let id = UUID().uuidString
        let now = Date().timeIntervalSince1970
        // Same fields as a Next? item made from the list's "Add To The Next List".
        let item = Ideal(id: id,
                         category: Category.fix.rawValue,
                         title: title,
                         notes: "",
                         scheduleDateTime: now,
                         createdDate: now,
                         targetCount: "1",
                         doneCount: 0,
                         active: true,
                         wishlistEnabled: true,
                         startDate: 0)
        HapticFeedback.impact()
        withAnimation(.easeOut(duration: 0.15)) {
            _ = state.add(DumpFlowState.Entry(id: id, title: title, isNew: true), pickedFor: category)
        }
        notice = nil
        let userId = uid
        Firestore.firestore().collection("users").document(userId).collection("ideals")
            .document(id)
            .setData(item.asDictionary()) { error in
                guard let error else { return }
                AppLogger.error(AppLogger.firestore, "[DumpFlow] add failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    state.remove(id: id)
                    presentAlert(DumpFlowCopy.saveFailedTitle, DumpFlowCopy.addFailedMessage)
                }
            }
        return true
    }

    private func remove(_ entry: DumpFlowState.Entry) {
        guard entry.isNew, !uid.isEmpty else { return }
        HapticFeedback.impact()
        withAnimation(.easeOut(duration: 0.15)) {
            state.remove(id: entry.id)
        }
        repository.deleteIdeal(userId: uid, idealId: entry.id) { error in
            if let error {
                AppLogger.error(AppLogger.firestore, "[DumpFlow] remove failed: \(error.localizedDescription)")
            }
        }
    }

    /// Second week: last week's ideals first, each under its own F. Both
    /// runs then add the Next? list.
    private func loadEntries() {
        guard !hasLoadedNextList, !uid.isEmpty else { return }
        if mode == .secondWeek {
            for ideal in lastWeekIdeals {
                let category = Category(rawValue: ideal.category) ?? .fix
                state.add(DumpFlowState.Entry(id: ideal.id, title: ideal.title, isNew: false,
                                              fixedCategory: category),
                          allowSameTitle: true)
            }
        }
        loadNextList()
    }

    /// Anything already on the Next? list belongs in the dump too (an
    /// interrupted first run, or the test link on an existing account).
    private func loadNextList() {
        guard !hasLoadedNextList, !uid.isEmpty else { return }
        hasLoadedNextList = true
        let allowSameTitle = mode == .secondWeek
        Firestore.firestore().collection("users").document(uid).collection("ideals")
            .whereField("wishlistEnabled", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error {
                    AppLogger.error(AppLogger.firestore, "[DumpFlow] Next? list read failed: \(error.localizedDescription)")
                    return
                }
                let docs = (snapshot?.documents ?? []).sorted {
                    ($0.data()["createdDate"] as? TimeInterval ?? 0) < ($1.data()["createdDate"] as? TimeInterval ?? 0)
                }
                DispatchQueue.main.async {
                    for doc in docs {
                        guard let title = doc.data()["title"] as? String else { continue }
                        _ = state.add(DumpFlowState.Entry(id: doc.documentID, title: title, isNew: false),
                                      allowSameTitle: allowSameTitle)
                    }
                }
            }
    }

    private func save() {
        guard !planning.isSaving else { return }
        let plan = state.savePlan
        guard state.hasPicks else {
            // Nothing picked: everything stays on Next?. The first week is
            // still done; the second week's prompt is left as if cancelled.
            finish(saved: mode == .firstWeek)
            return
        }
        // Last week's picks are copied into this week; Next? items and new
        // ones move in place. Both carry their F and number.
        let lastWeekIds = Set(plan.lastWeekIds)
        planning.selectedIdealIds = lastWeekIds
        planning.plannedCategories = plan.categories
        planning.plannedTargets = plan.targets
        planning.selectedWishlistIdealIds = Set(plan.wishlistIds)
        planning.wishlistCategories = plan.categories
        planning.wishlistTargets = plan.targets
        planning.savePlanning(selectedIdeals: lastWeekIdeals.filter { lastWeekIds.contains($0.id) },
                              selectedWishlistIdeals: state.pickedIdeals,
                              weekStartDay: weekStartDay,
                              requireReason: false,
                              isWeeklyPrompt: true) { result in
            if !result.validationDuplicates.isEmpty {
                presentAlert(DumpFlowCopy.duplicatesTitle,
                             DumpFlowCopy.duplicatesMessage(result.validationDuplicates))
                return
            }
            guard result.success else {
                presentAlert(DumpFlowCopy.saveFailedTitle, DumpFlowCopy.saveFailedMessage)
                return
            }
            if !result.skippedDuplicates.isEmpty {
                finishAfterAlert = true
                presentAlert(DumpFlowCopy.skippedTitle,
                             DumpFlowCopy.skippedMessage(result.skippedDuplicates))
                return
            }
            HapticFeedback.success()
            finish(saved: true)
        }
    }

    private func finish(saved: Bool) {
        switch mode {
        case .firstWeek: coordinator.finish(saved: saved, uid: uid)
        case .secondWeek: onFinish?(saved)
        }
    }

    private func presentAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
