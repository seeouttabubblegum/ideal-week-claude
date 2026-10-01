//
//  DumpFlowView.swift
//  The Ideal Week
//
//  The first-week dump (client, 2026-10-02; book chapter 9). Screens, in
//  order: the dump → one "Which of these are your …?" per F (Fix → Finance)
//  → empty Fs, if any → how often → save. Logic lives in `DumpFlowState`;
//  the save is the weekly prompt's own (`PlanningSheetViewModel.savePlanning`
//  into the current week), so the duplicate guard, plan records and the
//  in-flight guard all come with it. No PIN.
//

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseFirestore

struct DumpFlowView: View {
    @ObservedObject private var coordinator = DumpFlowCoordinator.shared
    @StateObject private var planning = PlanningSheetViewModel()
    @Query private var storedTempSettings: [MainSettings]

    @State private var state = DumpFlowState()
    @State private var draftTitle = ""
    /// Fill-screen fields, one per empty F.
    @State private var fillDrafts: [Category: String] = [:]
    /// The Fs that were empty when the fill screen opened — kept, so a field
    /// does not vanish the moment its F gets an ideal.
    @State private var fillCategories: [Category] = []
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
            NeuSheetHeader(title: DumpFlowCopy.headerTitle, titleSize: 26,
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
        .onAppear(perform: loadNextList)
        .alert(DumpFlowCopy.leaveTitle, isPresented: $showLeaveConfirm) {
            Button(DumpFlowCopy.leaveCancel, role: .cancel) {}
            Button(DumpFlowCopy.leaveConfirm, role: .destructive) {
                coordinator.finish(saved: false, uid: uid)
            }
        } message: {
            Text(DumpFlowCopy.leaveMessage)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button(DumpFlowCopy.okButton) {
                if finishAfterAlert {
                    finishAfterAlert = false
                    coordinator.finish(saved: true, uid: uid)
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
        case .fillEmpty:
            fillStage
        case .howOften:
            howOftenStage
        }
    }

    private var dumpStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            stageTitle(DumpFlowCopy.dumpTitle)
            stageMessage(DumpFlowCopy.dumpMessage)
            HStack(spacing: 10) {
                TextField(DumpFlowCopy.dumpPlaceholder, text: $draftTitle)
                    .font(.manrope(16, .medium))
                    .foregroundColor(LCColor.ink)
                    .submitLabel(.done)
                    .focused($dumpFieldFocused)
                    .onSubmit { addFromDumpField() }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .neuSunkenCapsule()
                addButton(enabled: !DumpFlowState.cleanTitle(draftTitle).isEmpty) { addFromDumpField() }
            }
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

    private func sortStage(_ category: Category) -> some View {
        let shown = state.entries(for: category)
        return VStack(alignment: .leading, spacing: 12) {
            if let progress = DumpFlowCopy.progress(for: state.stage) {
                Text(progress)
                    .font(.manrope(13, .heavy))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundColor(LCColor.ink.opacity(0.6))
            }
            stageTitle(DumpFlowCopy.sortTitle(category))
            stageMessage(category.subheading)
            stageMessage(DumpFlowCopy.sortHint)
            if shown.isEmpty {
                stageMessage(DumpFlowCopy.sortNothingLeft)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(shown) { entry in
                    let picked = state.isPicked(entry.id, for: category)
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
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(picked ? .isSelected : [])
                    NeuFeatheredDivider()
                }
            }
        }
    }

    private var fillStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            stageTitle(DumpFlowCopy.fillTitle)
            stageMessage(DumpFlowCopy.fillMessage)
            ForEach(fillCategories, id: \.self) { category in
                VStack(alignment: .leading, spacing: 10) {
                    Text(category.rawValue)
                        .font(.manrope(18, .heavy))
                        .accentText(.pink)
                    ForEach(state.pickedEntries.filter { $0.category == category }) { item in
                        entryTitle(item.entry.title)
                    }
                    HStack(spacing: 10) {
                        TextField(DumpFlowCopy.fillPlaceholder(category), text: Binding(
                            get: { fillDrafts[category] ?? "" },
                            set: { fillDrafts[category] = $0 }
                        ))
                        .font(.manrope(16, .medium))
                        .foregroundColor(LCColor.ink)
                        .submitLabel(.done)
                        .onSubmit { addFromFillField(category) }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .neuSunkenCapsule()
                        addButton(enabled: !DumpFlowState.cleanTitle(fillDrafts[category] ?? "").isEmpty) {
                            addFromFillField(category)
                        }
                    }
                }
                .padding(.vertical, 6)
                NeuFeatheredDivider()
            }
            if let notice {
                Text(notice)
                    .font(.manrope(14, .bold))
                    .accentText(.pink)
            }
        }
    }

    private var howOftenStage: some View {
        let picked = state.pickedEntries
        return VStack(alignment: .leading, spacing: 16) {
            stageTitle(DumpFlowCopy.howOftenTitle)
            stageMessage(picked.isEmpty ? DumpFlowCopy.howOftenNothingPicked : DumpFlowCopy.howOftenMessage)
            ForEach(DumpFlowState.sortOrder.filter { category in picked.contains { $0.category == category } },
                    id: \.self) { category in
                VStack(alignment: .leading, spacing: 14) {
                    Text(category.rawValue)
                        .font(.manrope(18, .heavy))
                        .accentText(.pink)
                    ForEach(picked.filter { $0.category == category }) { item in
                        VStack(alignment: .leading, spacing: 10) {
                            entryTitle(item.entry.title)
                            HowOftenSliderView(value: Binding(
                                get: { state.target(for: item.entry.id) },
                                set: { state.setTarget($0, for: item.entry.id) }
                            ))
                        }
                        .padding(.bottom, 6)
                    }
                }
                .padding(.vertical, 6)
                NeuFeatheredDivider()
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 14) {
            if state.stage != .dump {
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
            if state.stage == .fillEmpty, fillCategories.isEmpty {
                fillCategories = state.emptyCategories
            }
        }
    }

    private func goBack() {
        notice = nil
        HapticFeedback.impact()
        withAnimation(.easeOut(duration: 0.2)) {
            state.goBack()
            // Returning to a pass can change which Fs are empty.
            if case .sort = state.stage { fillCategories = [] }
        }
    }

    private func addFromDumpField() {
        if addEntry(title: draftTitle, pickedFor: nil) {
            draftTitle = ""
            dumpFieldFocused = true
        }
    }

    private func addFromFillField(_ category: Category) {
        if addEntry(title: fillDrafts[category] ?? "", pickedFor: category) {
            fillDrafts[category] = ""
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

    /// Anything already on the Next? list belongs in the dump too (an
    /// interrupted first run, or the test link on an existing account).
    private func loadNextList() {
        guard !hasLoadedNextList, !uid.isEmpty else { return }
        hasLoadedNextList = true
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
                        _ = state.add(DumpFlowState.Entry(id: doc.documentID, title: title, isNew: false))
                    }
                }
            }
    }

    private func save() {
        guard !planning.isSaving else { return }
        let plan = state.savePlan
        guard !plan.wishlistIds.isEmpty else {
            // Nothing picked: everything stays on Next?.
            coordinator.finish(saved: true, uid: uid)
            return
        }
        planning.selectedWishlistIdealIds = Set(plan.wishlistIds)
        planning.wishlistCategories = plan.categories
        planning.wishlistTargets = plan.targets
        planning.savePlanning(selectedIdeals: [],
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
            coordinator.finish(saved: true, uid: uid)
        }
    }

    private func presentAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
