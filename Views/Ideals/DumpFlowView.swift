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
    /// The add field of an F with nothing left to pick, one per F.
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

    /// One F: heart what belongs here and set how often right under it.
    /// When every idea already went to an earlier F, say so and offer to add
    /// ideas for this one (client, 2026-10-02).
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
            } else {
                stageMessage(DumpFlowCopy.sortHint)
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
