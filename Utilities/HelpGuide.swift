//
//  HelpGuide.swift
//  The Ideal Week
//
//  The Help tab's walkthrough: the same lessons the in-app tours give, as a
//  sequence of real screenshots grouped into sections — so someone who skipped
//  the tours, or wants a reminder, can read the whole thing in one place.
//
//  The screenshots are captured from the app itself (asset names prefixed
//  `tour_`). Re-taking them: flip `IdealListView.showsTestLinks` to false, run
//  the simulator, `xcrun simctl io <udid> screenshot`, and replace the asset.
//
//  Copy here is a first draft for the client to edit, like the tour's.
//

import Foundation

enum HelpGuide {

    struct Page: Identifiable, Equatable {
        /// Stable id for the pager.
        let id: String
        /// Asset-catalog name of the screenshot.
        let imageName: String
        let title: String
        let caption: String
    }

    struct Section: Identifiable, Equatable {
        var id: String { title }
        let title: String
        /// One line under the section title, like Apple's intro pages.
        let summary: String
        let pages: [Page]
    }

    static let sections: [Section] = [
        Section(
            title: "Your week",
            summary: "What the app is made of, and where things live.",
            pages: [
                Page(id: "week.list",
                     imageName: "tour_list",
                     title: "Seven parts of a week",
                     caption: "Fix, Fitness, Feelings, Faculties, Family, Finance, Fun. Every ideal belongs to one of them, and the page is one band per part. The plus on a band adds to that part; NEXT plans the week ahead; the button top-right opens everything else."),
                Page(id: "week.ideals",
                     imageName: "tour_list_rows",
                     title: "Your ideals, and their dots",
                     caption: "Under each band sit that part's ideals. The dots are the target you set — one fills each time you mark the ideal done, and any past the target show as extra. The bell means no reminder is set yet."),
                Page(id: "week.progress",
                     imageName: "tour_progress",
                     title: "How the week is going",
                     caption: "Progress shows the rings for the three groups, how many ideals turned into actions, and the review scores you gave, category by category."),
            ]
        ),
        Section(
            title: "Adding an ideal",
            summary: "Small, doable, and yours.",
            pages: [
                Page(id: "add.form",
                     imageName: "tour_new_ideal",
                     title: "Say it small",
                     caption: "A short title beats an ambitious one — \u{201C}Walk 20 minutes\u{201D} rather than \u{201C}Get fit\u{201D}. Pick the part of the week it belongs to, then how often you want it this week. That target is what the tracking dots fill up."),
            ]
        ),
        Section(
            title: "Doing the week",
            summary: "Marking things done, and what the app asks afterwards.",
            pages: [
                Page(id: "do.review",
                     imageName: "tour_review",
                     title: "Mark it done, then say how it felt",
                     caption: "Swipe an ideal to the right each time you do it — one dot fills per time, and extra dots mean you went past your target. The app then asks how it felt: drag the slider, yellow for a good one, blue for a hard one. SKIP leaves the score out; the dot is filled either way."),
                Page(id: "do.reminder",
                     imageName: "tour_reminder",
                     title: "A nudge, if you want one",
                     caption: "The bell on an ideal means nothing is scheduled yet. Open it, switch Schedule a Reminder on, pick the days and a time, and save. The ideal then shows NEXT with the next one due."),
            ]
        ),
        Section(
            title: "Next week",
            summary: "Where next week takes shape, before it starts.",
            pages: [
                Page(id: "next.page",
                     imageName: "tour_next_open",
                     title: "The Next? page",
                     caption: "Nothing here touches the week you are in. Park anything you are not ready to commit to on the list at the top; the note lower down says where next week stands, and the button under it builds the plan."),
                Page(id: "next.locked",
                     imageName: "tour_next",
                     title: "Locked, earlier in the week",
                     caption: "Planning works best near the end of a week, when you know how this one went. Before then the same button reads Unlock Next Week\u{2019}s Plan and asks for a PIN, so planning early stays a deliberate choice. Near the weekend it opens straight away instead."),
                Page(id: "next.pin",
                     imageName: "tour_pin",
                     title: "Your PIN, not ours",
                     caption: "The first time, pick four digits and type them twice to set them; after that the screen just asks for them. The app never fills it in for you. Then you write a line about why next week cannot wait, and planning opens."),
                Page(id: "next.pick",
                     imageName: "tour_plan_pick",
                     title: "Picked, or waiting",
                     caption: "Planning walks you through what you already have. A filled heart is coming with you into next week; an empty one stays where it is and waits."),
                Page(id: "next.missed",
                     imageName: "tour_plan_missed",
                     title: "Anything missed?",
                     caption: "The last step names the parts of the week still empty and lets you add to them. The note updates as you add, and disappears once every part has something. The number on the check is how many ideals you are about to save."),
            ]
        ),
        Section(
            title: "Every week",
            summary: "The one prompt the app opens by itself.",
            pages: [
                Page(id: "weekly.prompt",
                     imageName: "tour_weekly_prompt",
                     title: "A new week, a choice",
                     caption: "When a week turns, the app looks back at the last one and asks what you want to do with the new one: plan it now, or skip straight to your list and plan later."),
            ]
        ),
    ]
}
