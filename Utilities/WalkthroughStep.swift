//
//  WalkthroughStep.swift
//  The Ideal Week
//
//  What each walkthrough says, which part of the screen it points at, and what
//  it waits for.
//
//  The first-launch tour does not describe adding an ideal — it opens the New
//  Ideal screen and has the user type a title and save. Those steps wait for
//  the real thing to happen (`waitsFor`) instead of showing a Next button, and
//  while they wait the highlighted control stays live so it can be used.
//
//  Copy here is a first draft for the client to edit — it belongs in the app
//  text spreadsheet like the rest of the product's words.
//

import Foundation

/// A part of the screen a step can point at. The view that draws it marks
/// itself with `.walkthroughSpot(_:)`; a step with no spot is a plain card.
enum WalkthroughSpot: String {
    // Ideals list
    case categoryBand
    case addIdealButton
    case trackingDots
    case nextPill
    case drawerToggle
    // Review sheet
    case moodSlider
    case reviewSubmit
    // Setting a reminder
    case scheduleBell
    case scheduleToggle
    case reminderDays
    // New Ideal
    case categoryPicker
    case titleField
    /// The slider's drag knob, not the whole row — the step asks for a drag.
    case howOftenKnob
    case saveButton
    // Next? page
    case addToNextList
    case nextNotice
    case planButton
    // First plan
    case starterIdeal
    case savePlanButton
}

/// Which screen a step belongs to. Each screen hosts the tour itself — an
/// overlay on the list cannot reach over a sheet.
enum WalkthroughScreen {
    case idealsList
    case newIdeal
    /// "How You Doin'?" — opens when an ideal is swiped done.
    case reviewSheet
    /// The edit screen, reached from an ideal's bell — where reminders are set.
    case editIdeal
    case nextPage
    case planningSheet
}

/// Something the user did that a step can be waiting for.
enum WalkthroughEvent: Equatable {
    case enteredTitle
    case pickedCategory
    case changedHowOften
    case savedIdeal
    /// An ideal was swiped done — the review sheet is on its way.
    case markedDone
    /// The review sheet closed, scored or skipped.
    case finishedReview
    /// The bell was tapped and the edit screen opened.
    case openedScheduleEditor
    /// "Schedule a Reminder?" was switched on.
    case enabledReminder
    /// A day was picked for the reminder.
    case pickedReminderDay
    /// The edit screen saved.
    case savedSchedule
    /// The edit screen closed without saving.
    case closedScheduleEditor
    /// The New Ideal screen closed without a save — the tour must not sit
    /// waiting for an event that can no longer arrive.
    case closedNewIdeal
}

/// Something the tour asks the app to do when a step begins.
enum WalkthroughRequest: Equatable {
    case openNewIdeal
}

/// A small picture drawn inside a step's card, for things the user's own
/// screen cannot show yet — an empty Next? page has no picked and unpicked
/// items to point at.
enum WalkthroughIllustration: Equatable {
    /// Two example rows: one taken into next week, one left behind.
    case selectionExample
}

/// Where the card sits relative to the highlighted control.
enum WalkthroughPlacement {
    case auto
    /// Forced above — the step opens the keyboard, which would bury a card
    /// placed underneath.
    case above
}

struct WalkthroughStep: Identifiable, Equatable {
    let id: String
    let screen: WalkthroughScreen
    let spot: WalkthroughSpot?
    /// Shown above the message. Empty on the one step that must stay as short
    /// as it can — see the title step.
    let title: String
    let message: String
    /// When set, the step has no Next button: it ends when the user does this.
    let waitsFor: WalkthroughEvent?
    /// Asked of the app when this step begins.
    let request: WalkthroughRequest?
    let placement: WalkthroughPlacement
    /// The step puts the cursor in the title field and opens the keyboard.
    let focusesTitleField: Bool
    /// Drawn inside the card, under the message.
    let illustration: WalkthroughIllustration?

    init(_ id: String,
         screen: WalkthroughScreen = .idealsList,
         spot: WalkthroughSpot? = nil,
         title: String,
         message: String,
         waitsFor: WalkthroughEvent? = nil,
         request: WalkthroughRequest? = nil,
         placement: WalkthroughPlacement = .auto,
         focusesTitleField: Bool = false,
         illustration: WalkthroughIllustration? = nil) {
        self.id = id
        self.screen = screen
        self.spot = spot
        self.title = title
        self.message = message
        self.waitsFor = waitsFor
        self.request = request
        self.placement = placement
        self.focusesTitleField = focusesTitleField
        self.illustration = illustration
    }

    static func == (lhs: WalkthroughStep, rhs: WalkthroughStep) -> Bool { lhs.id == rhs.id }
}

extension Walkthrough {
    var steps: [WalkthroughStep] {
        switch self {
        case .firstLaunchTour:
            return [
                WalkthroughStep("tour.categories", spot: .categoryBand,
                                title: "Seven parts of a week",
                                message: "Fix, Fitness, Feelings, Faculties, Family, Finance, Fun. Your week is built from all seven, not just the loudest one."),
                WalkthroughStep("tour.add", spot: .addIdealButton,
                                title: "Add your first ideal",
                                message: "The plus on a band adds something to that part of your week. Tap Next and we will open it for you."),

                // The form. These steps wait for the real thing to happen.
                // No heading: the card sits above the title field with the
                // keyboard up, and a heading pushed it down over the field.
                WalkthroughStep("ideal.title", screen: .newIdeal, spot: .titleField,
                                title: "",
                                message: "Type a short title — something you could actually do this week. \u{201C}Walk 20 minutes\u{201D} beats \u{201C}Get fit\u{201D}.",
                                waitsFor: .enteredTitle,
                                request: .openNewIdeal,
                                placement: .above,
                                focusesTitleField: true),
                WalkthroughStep("ideal.category", screen: .newIdeal, spot: .categoryPicker,
                                title: "Which part of the week?",
                                message: "Tap the icon for the part of your week this belongs to. Fix is fine if you are not sure.",
                                waitsFor: .pickedCategory),
                WalkthroughStep("ideal.howOften", screen: .newIdeal, spot: .howOftenKnob,
                                title: "How often this week?",
                                message: "Drag the knob. This is the target your tracking dots fill up — start low, you can always do more.",
                                waitsFor: .changedHowOften),
                WalkthroughStep("ideal.save", screen: .newIdeal, spot: .saveButton,
                                title: "Save it",
                                message: "Tap the check and it joins your week.",
                                waitsFor: .savedIdeal),

                // Back on the list, with their own ideal in it. This one is not
                // a card to tap past: the user swipes, which opens the review.
                WalkthroughStep("tour.dots", spot: .trackingDots,
                                title: "Mark it done",
                                message: "There it is. Swipe it to the right — one dot fills each time you do it, and extra dots mean you went past your target. Try it now.",
                                waitsFor: .markedDone),

                // The review sheet the swipe opens.
                WalkthroughStep("review.slider", screen: .reviewSheet, spot: .moodSlider,
                                title: "How did that feel?",
                                message: "Every time you mark something done the app asks this. Drag the slider — yellow is a good one, blue is a hard one."),
                WalkthroughStep("review.submit", screen: .reviewSheet, spot: .reviewSubmit,
                                title: "Keep it",
                                message: "The arrow saves your score and closes this. SKIP leaves it out — your dot is filled either way.",
                                waitsFor: .finishedReview),
                // Setting a reminder, on the ideal they just made.
                WalkthroughStep("schedule.bell", spot: .scheduleBell,
                                title: "Want a nudge?",
                                message: "The bell means nothing is scheduled yet. Tap it to open the ideal.",
                                waitsFor: .openedScheduleEditor),
                WalkthroughStep("schedule.toggle", screen: .editIdeal, spot: .scheduleToggle,
                                title: "Schedule a reminder",
                                message: "Switch this on and the days appear.",
                                waitsFor: .enabledReminder),
                WalkthroughStep("schedule.days", screen: .editIdeal, spot: .reminderDays,
                                title: "Pick your days",
                                message: "Tap the days you want reminding on. The time sits beside them — tap it to change it.",
                                waitsFor: .pickedReminderDay),
                WalkthroughStep("schedule.save", screen: .editIdeal, spot: .saveButton,
                                title: "Save the reminder",
                                message: "Tap the check. Your phone will nudge you on those days, and the ideal shows NEXT with the next one.",
                                waitsFor: .savedSchedule),

                WalkthroughStep("tour.next", spot: .nextPill,
                                title: "Plan the next week",
                                message: "NEXT is where next week gets planned, and where things you are not ready for can wait."),
                WalkthroughStep("tour.drawer", spot: .drawerToggle,
                                title: "Everything else",
                                message: "Progress, profile, settings and help live behind this button."),
            ]
        case .nextTab:
            return [
                WalkthroughStep("next.what", screen: .nextPage,
                                title: "This is next week",
                                message: "Nothing you do here touches the week you are in. This is where next week takes shape, before it starts."),
                WalkthroughStep("next.example", screen: .nextPage,
                                title: "Picked, or waiting",
                                message: "When you plan, every ideal shows one of these two. A filled heart is coming with you into next week; an empty one stays on the list and waits.",
                                illustration: .selectionExample),
                WalkthroughStep("next.list", screen: .nextPage, spot: .addToNextList,
                                title: "Park an idea",
                                message: "Anything you are not ready to commit to goes here. It sits on this list — no week, no target — until you plan it in."),
                WalkthroughStep("next.notice", screen: .nextPage, spot: .nextNotice,
                                title: "What this note tells you",
                                message: "It says whether next week has a plan yet, and what the button below will do — start a plan, or add more to the one you have."),
                WalkthroughStep("next.plan", screen: .nextPage, spot: .planButton,
                                title: "Make the plan",
                                message: "This builds next week from the ideals you already have, your parked list, and anything new. Close to the weekend it opens straight away; earlier in the week it asks for your PIN first, so planning early stays a deliberate choice."),
                WalkthroughStep("next.after", screen: .nextPage,
                                title: "After you save",
                                message: "Your plan appears at the top of this page under NEXT WEEK, and moves into My Ideals when the week turns."),
            ]
        case .firstPlan:
            return [
                WalkthroughStep("plan.starter", screen: .planningSheet, spot: .starterIdeal,
                                title: "One to start you off",
                                message: "We put one ideal in for you. Change the words, change how often, or remove it with the cross — it is yours."),
                WalkthroughStep("plan.add", screen: .planningSheet,
                                title: "Add as many as you like",
                                message: "Fill in the form below and tap Add for each one. The note underneath tells you which categories are still empty."),
                WalkthroughStep("plan.save", screen: .planningSheet, spot: .savePlanButton,
                                title: "Save when you are done",
                                message: "The number on the check is how many ideals you are about to save."),
            ]
        }
    }
}

/// Where a running walkthrough is up to. A value type so the sequencing can be
/// tested without a screen.
struct WalkthroughRun: Equatable {
    let walkthrough: Walkthrough
    private(set) var index: Int = 0
    private(set) var isFinished = false

    init(walkthrough: Walkthrough) {
        self.walkthrough = walkthrough
    }

    var step: WalkthroughStep? {
        guard !isFinished, walkthrough.steps.indices.contains(index) else { return nil }
        return walkthrough.steps[index]
    }

    var isOnLastStep: Bool { index == walkthrough.steps.count - 1 }

    /// The step is waiting for the user to do something, so it shows no Next
    /// button and the highlighted control stays usable.
    var isWaiting: Bool { step?.waitsFor != nil }

    /// Next. Ignored while a step is waiting for the user — the tour cannot
    /// skip past "type a title" on a button press.
    mutating func advance() {
        guard !isFinished, !isWaiting else { return }
        moveOn()
    }

    /// Something happened in the app.
    mutating func report(_ event: WalkthroughEvent) {
        guard !isFinished, let step else { return }
        if step.waitsFor == event {
            moveOn()
            return
        }
        // Leaving the New Ideal screen without saving: resume on the list
        // rather than waiting for a save that is not coming.
        if event == .closedNewIdeal, step.screen == .newIdeal {
            while let current = self.step, current.screen == .newIdeal {
                moveOn()
            }
        }
        // The review sheet closed while an earlier review step was still on
        // screen (skipped without dragging): step past the rest of them.
        if event == .finishedReview, step.screen == .reviewSheet {
            while let current = self.step, current.screen == .reviewSheet {
                moveOn()
            }
        }
        // Same for the edit screen: left without saving the reminder.
        if event == .closedScheduleEditor, step.screen == .editIdeal {
            while let current = self.step, current.screen == .editIdeal {
                moveOn()
            }
        }
    }

    mutating func skip() { isFinished = true }

    private mutating func moveOn() {
        if isOnLastStep { isFinished = true } else { index += 1 }
    }
}

/// Which ideal the tour's "mark it done" step points at.
enum TourIdealHighlight {
    /// The one the tour just had the user create, matched by title; otherwise
    /// the first ideal on the page — which is the only one a new user has.
    static func idealId(in rows: [(id: String, title: String)], createdTitle: String?) -> String? {
        if let createdTitle {
            let wanted = createdTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if let match = rows.first(where: {
                $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(wanted) == .orderedSame
            }) {
                return match.id
            }
        }
        return rows.first?.id
    }
}
