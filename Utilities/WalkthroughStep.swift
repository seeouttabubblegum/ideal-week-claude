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
    /// The whole slider with its 1–6+ numbers — where the slider card sits
    /// under, so it never covers them.
    case howOftenScale
    case saveButton
    // Next? page
    case addToNextList
    case nextNotice
    case planButton
    // The PIN screen
    case pinEntry
    case pinReason
    // First plan
    /// The heart on the first row of the "does this fit?" list.
    case planPickHeart
    /// The starter ideal a brand-new plan opens with.
    case starterIdeal
    /// The form the "Missed Anything?" step adds ideals through.
    case planAddForm
    /// "Add To My Next Week" under that form — the add card sits below it.
    case planAddButton
    /// Continue at the foot of the picking screens — the picks card sits
    /// above it, clear of the hearts.
    case planContinue
    case savePlanButton
    /// A screen's close button. Stays usable while a step waits, so the user
    /// is never left with Skip as the only way out.
    case screenClose
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
    /// The secret-PIN screen that guards planning early.
    case pinScreen
    case nextPage
    /// The planning flow's picking screens — Priority / More / the wishlist.
    case planningPicks
    /// The planning flow's "Missed Anything?" step, where ideals are added and
    /// the plan is saved.
    case planningAdd
}

/// Something the user did that a step can be waiting for.
enum WalkthroughEvent: Equatable {
    case enteredTitle
    /// The title field was emptied again.
    case clearedTitle
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
    /// The PIN screen opened.
    case openedPinScreen
    /// A PIN was set (or entered) and accepted. The user types it, never the app.
    case pinAccepted
    /// The PIN screen was closed without getting through it.
    case closedPinScreen
    /// The planning flow opened — where both Next? tours hand over.
    case openedPlanning
    /// The planning flow reached its "Missed Anything?" step. A picks card the
    /// user never tapped past is dropped, so the tour carries on here.
    case reachedPlanningAdd
    /// The planning flow closed, saved or cancelled.
    case closedPlanning
    /// The Next? page was closed.
    case closedNextPage
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
    /// Forced below — the card must not cover what sits under the control.
    case below
}

/// Where a card goes. Pure so the rule can be tested.
enum WalkthroughCardPlacement {
    /// Just under the control — or, when the screen runs out, as low as the
    /// card can sit while staying fully on screen (it may then overlap the
    /// control's lower edge; a card off the bottom edge is worse).
    static func belowY(targetMaxY: CGFloat, cardHeight: CGFloat, screenHeight: CGFloat,
                       halo: CGFloat, gap: CGFloat, margin: CGFloat) -> CGFloat {
        let below = targetMaxY + halo + gap
        return min(below, screenHeight - margin - cardHeight)
    }
}

/// Where touches still get through while a step keeps its control live. Pure
/// so it can be tested; the overlay blocks everything else.
enum WalkthroughHitArea {
    static func liveRects(target: CGRect?, escape: CGRect?, halo: CGFloat) -> [CGRect] {
        [target?.insetBy(dx: -halo, dy: -halo), escape].compactMap { $0 }
    }
}

/// What the step's card shows. Pure so the rule can be tested; the overlay
/// only draws it.
enum WalkthroughCardControls {
    /// A waiting step has no Next button, so on the last step Skip is the only
    /// way out of the tour — hiding it there left the card on screen with
    /// nothing to press.
    static func showsSkip(isLastStep: Bool, isWaiting: Bool) -> Bool {
        !isLastStep || isWaiting
    }
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
    /// The step has a Next button, but it stays disabled until this happens —
    /// and while it waits, the highlighted control stays usable. The title
    /// step: type a title, then Next.
    let nextUnlockedBy: WalkthroughEvent?
    /// Place the card against this spot instead of the highlighted one — the
    /// slider card sits under the numbers, not just under the knob it lights.
    let cardAnchor: WalkthroughSpot?
    /// The whole screen stays usable under the card — the review sheet, where
    /// the card says "drag the slider" and "SKIP leaves it out".
    let leavesScreenLive: Bool

    init(_ id: String,
         screen: WalkthroughScreen = .idealsList,
         spot: WalkthroughSpot? = nil,
         title: String,
         message: String,
         waitsFor: WalkthroughEvent? = nil,
         request: WalkthroughRequest? = nil,
         placement: WalkthroughPlacement = .auto,
         focusesTitleField: Bool = false,
         illustration: WalkthroughIllustration? = nil,
         nextUnlockedBy: WalkthroughEvent? = nil,
         cardAnchor: WalkthroughSpot? = nil,
         leavesScreenLive: Bool = false) {
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
        self.nextUnlockedBy = nextUnlockedBy
        self.cardAnchor = cardAnchor
        self.leavesScreenLive = leavesScreenLive
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
                                message: "Fix, Fitness, Feelings, Faculties, Family, Fun, Finance. Your week is built from all seven, not just the loudest one."),
                WalkthroughStep("tour.add", spot: .addIdealButton,
                                title: "Add your first ideal",
                                message: "The plus on a band adds something to that part of your week. Tap Next and we will open it for you."),

                // The form. These steps wait for the real thing to happen.
                // No heading: the card sits above the title field with the
                // keyboard up, and a heading pushed it down over the field.
                // Next, not the first letter typed, moves this one on: the
                // category card used to jump in mid-word with the keyboard up.
                WalkthroughStep("ideal.title", screen: .newIdeal, spot: .titleField,
                                title: "",
                                message: "Type a short title — something you could actually do this week. \u{201C}Walk 20 minutes\u{201D} beats \u{201C}Get fit\u{201D}. Tap Next when it reads right.",
                                request: .openNewIdeal,
                                placement: .above,
                                focusesTitleField: true,
                                nextUnlockedBy: .enteredTitle),
                WalkthroughStep("ideal.category", screen: .newIdeal, spot: .categoryPicker,
                                title: "Which part of the week?",
                                message: "Tap the icon for the part of your week this belongs to. Fix is fine if you are not sure.",
                                waitsFor: .pickedCategory),
                WalkthroughStep("ideal.howOften", screen: .newIdeal, spot: .howOftenKnob,
                                title: "How often this week?",
                                message: "Drag the knob. This is the target your tracking dots fill up — start low, you can always do more.",
                                waitsFor: .changedHowOften,
                                placement: .below,
                                cardAnchor: .howOftenScale),
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
                                message: "Every time you mark something done the app asks this. Drag the slider — yellow is a good one, blue is a hard one.",
                                leavesScreenLive: true),
                WalkthroughStep("review.submit", screen: .reviewSheet, spot: .reviewSubmit,
                                title: "Keep it",
                                message: "The arrow saves your score and closes this. SKIP leaves it out — your dot is filled either way.",
                                waitsFor: .finishedReview,
                                placement: .above,
                                cardAnchor: .moodSlider,
                                leavesScreenLive: true),
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
        case .nextPageOpen:
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
                                message: "It is open right now, so tap it and we will walk through planning next week together.",
                                waitsFor: .openedPlanning),
            ]
        case .nextPageLocked:
            return [
                WalkthroughStep("locked.what", screen: .nextPage,
                                title: "This is next week",
                                message: "Nothing you do here touches the week you are in. This is where next week takes shape, before it starts."),
                WalkthroughStep("locked.example", screen: .nextPage,
                                title: "Picked, or waiting",
                                message: "When you plan, every ideal shows one of these two. A filled heart is coming with you into next week; an empty one stays on the list and waits.",
                                illustration: .selectionExample),
                WalkthroughStep("locked.list", screen: .nextPage, spot: .addToNextList,
                                title: "Park an idea",
                                message: "Anything you are not ready to commit to goes here. It sits on this list — no week, no target — until you plan it in."),
                WalkthroughStep("locked.notice", screen: .nextPage, spot: .nextNotice,
                                title: "What this note tells you",
                                message: "It says whether next week has a plan yet, and what the button below will do."),
                WalkthroughStep("locked.unlock", screen: .nextPage, spot: .planButton,
                                title: "Why it is locked",
                                message: "Planning works best near the end of a week, when you know how this one went. Earlier than that the app asks for a PIN, so planning early is a choice you make on purpose. Tap to open it.",
                                waitsFor: .openedPinScreen),
                // Above the boxes: the confirm row sits right under them, and
                // the keyboard comes up from below.
                WalkthroughStep("locked.pin", screen: .pinScreen, spot: .pinEntry,
                                title: "Set your PIN",
                                message: "Pick four digits you will remember and type them in, then type them again to confirm. It is yours — the app never fills it in for you. Next time, this screen just asks for it.",
                                waitsFor: .pinAccepted,
                                placement: .above),
                WalkthroughStep("locked.reason", screen: .pinScreen, spot: .pinReason,
                                title: "Why plan early?",
                                message: "One line for yourself about why next week cannot wait. Then Confirm, and planning opens.",
                                waitsFor: .openedPlanning),
            ]
        case .firstPlan:
            return [
                // Each card belongs to the screen it talks about: after Next
                // here, the next card waits for "Missed Anything?".
                WalkthroughStep("plan.pick", screen: .planningPicks, spot: .planPickHeart,
                                title: "Picked, or waiting",
                                message: "Tap the heart on anything you want in the week you are planning — filled means it comes with you, empty means it waits. Then Continue at the bottom; the last step has two more tips.",
                                placement: .above,
                                cardAnchor: .planContinue,
                                leavesScreenLive: true),
                WalkthroughStep("plan.add", screen: .planningAdd, spot: .planAddForm,
                                title: "Add as many as you like",
                                message: "Fill in the form, then tap Add. The note above lists what is still empty.",
                                placement: .below,
                                cardAnchor: .planAddButton,
                                leavesScreenLive: true),
                WalkthroughStep("plan.save", screen: .planningAdd, spot: .savePlanButton,
                                title: "Save when you are done",
                                message: "The number on the check is how many ideals you are about to save."),
            ]
        case .firstPlanStarter:
            return [
                WalkthroughStep("starter.one", screen: .planningAdd, spot: .starterIdeal,
                                title: "One to start you off",
                                message: "We put one ideal in for you, so your first plan does not start on a blank page. Change the words, change how often, or remove it with the cross — it is yours."),
                WalkthroughStep("starter.add", screen: .planningAdd, spot: .planAddForm,
                                title: "Add as many as you like",
                                message: "Fill in the form, then tap Add. The note above lists what is still empty.",
                                placement: .below,
                                cardAnchor: .planAddButton,
                                leavesScreenLive: true),
                WalkthroughStep("starter.save", screen: .planningAdd, spot: .savePlanButton,
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

    /// Whether this step's Next has been unlocked (`nextUnlockedBy`).
    private(set) var nextUnlocked = false

    /// The step shows a Next button that cannot be pressed yet.
    var nextIsLocked: Bool { step?.nextUnlockedBy != nil && !nextUnlocked }

    /// The highlighted control stays usable under the card — a waiting step,
    /// or one whose Next unlocks on something done in that control.
    var keepsControlLive: Bool {
        isWaiting || step?.nextUnlockedBy != nil || step?.leavesScreenLive == true
    }

    /// Next. Ignored while a step is waiting for the user, or its Next is not
    /// unlocked yet — the tour cannot skip past "type a title" on a press.
    mutating func advance() {
        guard !isFinished, !isWaiting, !nextIsLocked else { return }
        moveOn()
    }

    /// Something happened in the app.
    mutating func report(_ event: WalkthroughEvent) {
        guard !isFinished, let step else { return }
        if step.waitsFor == event {
            moveOn()
            return
        }
        // Unlocks Next; the user still taps it.
        if step.nextUnlockedBy == event {
            nextUnlocked = true
            return
        }
        if event == .clearedTitle, step.nextUnlockedBy == .enteredTitle {
            nextUnlocked = false
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
        // The PIN screen closed without getting through it. Everything left in
        // this tour lives beyond that screen, so the tour is done — the page
        // itself has already been explained.
        if event == .closedPinScreen, step.screen == .pinScreen {
            while let current = self.step, current.screen == .pinScreen {
                moveOn()
            }
        }
        // Continued past the picks without tapping Next: the picks card is
        // about a screen the user has left.
        if event == .reachedPlanningAdd, step.screen == .planningPicks {
            while let current = self.step, current.screen == .planningPicks {
                moveOn()
            }
        }
        // The Next? page closed while its own steps were showing: the tour
        // (and the PIN steps it would lead to) is over. Not once the PIN
        // screen is up — that opens OVER the page, which reports the page as
        // gone; the PIN screen's own close handles leaving it.
        if event == .closedNextPage, step.screen == .nextPage {
            while let current = self.step,
                  current.screen == .nextPage || current.screen == .pinScreen {
                moveOn()
            }
        }
        // Planning closed: nothing of its tour is left to show.
        if event == .closedPlanning,
           step.screen == .planningPicks || step.screen == .planningAdd {
            while let current = self.step,
                  current.screen == .planningPicks || current.screen == .planningAdd {
                moveOn()
            }
        }
    }

    mutating func skip() { isFinished = true }

    private mutating func moveOn() {
        nextUnlocked = false
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
