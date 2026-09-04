//
//  IdealHistoryDetailView.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 28/8/25.
//
//  Restyled to the 2026-07 neumorphic handoff — screen 7k "Ideal Details"
//  (read-only history detail): Overview + Timeline grouped lists on the
//  shared surface, feathered dividers, HH Samuel headings, raised Close.
//

import SwiftData
import SwiftUI

struct IdealHistoryDetailView: View {
    let item: Ideal
    @StateObject private var viewModel: IdealHistoryDetailViewViewModel
    @Binding var detailViewPresented: Bool
    @Environment(\.dismiss) private var dismiss

    @Query var storedTempSettings: [MainSettings]
    var accentColor: Color {
        if let firstSettings = storedTempSettings.first {
            return Color(red: firstSettings.red, green: firstSettings.green, blue: firstSettings.blue, opacity: firstSettings.opacity)
        } else {
            return Color("default_color")
        }
    }
    var textColor: Color {
        if let firstSettings = storedTempSettings.first {
            return Color(red: firstSettings.textColorRed, green: firstSettings.textColorGreen, blue: firstSettings.textColorBlue, opacity: firstSettings.textColorOpacity)
        } else {
            return Color.black
        }
    }

    init(item: Ideal, detailViewPresented: Binding<Bool>) {
        self.item = item
        _viewModel = StateObject(wrappedValue: IdealHistoryDetailViewViewModel(ideal: item))
        _detailViewPresented = detailViewPresented
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Date-only formatter for the Week Start row ("Jul 6, 2026" in the handoff).
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// One row of the Timeline grouped list (label + pink value).
    private struct TimelineRow {
        let label: String
        let value: String
        /// Review Score renders heavier (Manrope 800/16) than the date rows (15).
        let emphasized: Bool
    }

    /// Timeline rows, in handoff order, skipping anything unset.
    private var timelineRows: [TimelineRow] {
        var rows: [TimelineRow] = []
        // Start Date (week) - Read-only when set
        if item.startDate > 0 {
            rows.append(TimelineRow(label: "Week Start",
                                    value: Self.dateOnlyFormatter.string(from: Date(timeIntervalSince1970: item.startDate)),
                                    emphasized: false))
        }
        // Schedule Date - Read-only
        if item.scheduleDateTime > 0 {
            rows.append(TimelineRow(label: "Scheduled Date",
                                    value: Self.dateFormatter.string(from: Date(timeIntervalSince1970: item.scheduleDateTime)),
                                    emphasized: false))
        }
        // Created Date - Read-only
        if item.createdDate > 0 {
            rows.append(TimelineRow(label: "Created",
                                    value: Self.dateFormatter.string(from: Date(timeIntervalSince1970: item.createdDate)),
                                    emphasized: false))
        }
        // Review Score - Read-only (if exists)
        if let reviewScore = item.reviewScore {
            let display = ReviewScoreScale.display(fromStored: reviewScore)
            rows.append(TimelineRow(label: "Review Score",
                                    value: "\(ReviewScoreScale.formattedDisplay(display))/7",
                                    emphasized: true))
        }
        // Legacy: active field kept for backward compatibility; inactive no longer used for filtering
        return rows
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header — raised close circle left, HH Samuel title centered (7k).
            ZStack {
                Text("IDEAL DETAILS")
                    .font(.hhSamuel(34))
                    .foregroundColor(LCColor.deepPink)
                HStack {
                    NeuCloseButton(action: { detailViewPresented = false }, diameter: 36)
                    Spacer()
                }
                .padding(.horizontal, LCMetrics.screenMargin)
            }
            .frame(height: 56)
            .padding(.top, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Overview", topPadding: 14)

                    VStack(spacing: 0) {
                        // Category - Read-only
                        detailRow(label: "Category") {
                            if let cat = Category(rawValue: item.category) {
                                HStack(spacing: 10) {
                                    Image(cat.lcCategoryIconV2())
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .foregroundColor(LCColor.blue)
                                    Text(cat.rawValue)
                                        .font(.manrope(16))
                                        .foregroundColor(LCColor.pink)
                                }
                            } else {
                                Text(item.category)
                                    .font(.manrope(16))
                                    .foregroundColor(LCColor.pink)
                            }
                        }

                        rowDivider

                        // Title - Read-only (Newsreader italic, letterpressed)
                        detailRow(label: "Title") {
                            Text(item.title)
                                .font(.idealTitle(18))
                                .foregroundColor(LCColor.ink)
                                .imprinted()
                                .multilineTextAlignment(.trailing)
                        }

                        rowDivider

                        // Done Count - Read-only
                        detailRow(label: "Total Completed") {
                            Text("\(item.doneCount)")
                                .font(.manrope(16))
                                .foregroundColor(LCColor.pink)
                        }

                        rowDivider

                        // Target Count - Read-only
                        detailRow(label: "Target This Week") {
                            Text(item.targetCount)
                                .font(.manrope(16))
                                .foregroundColor(LCColor.pink)
                        }

                        // Notes - Read-only
                        if !item.notes.isEmpty {
                            rowDivider
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.manrope(16, .heavy))
                                    .foregroundColor(LCColor.ink)
                                Text(item.notes)
                                    .font(.manrope(15, .medium))
                                    .foregroundColor(LCColor.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                        }
                    }
                    .padding(.horizontal, LCMetrics.screenMargin)

                    let rows = timelineRows
                    if !rows.isEmpty {
                        sectionHeader("Timeline", topPadding: 18)

                        VStack(spacing: 0) {
                            ForEach(rows.indices, id: \.self) { index in
                                if index > 0 { rowDivider }
                                detailRow(label: rows[index].label) {
                                    Text(rows[index].value)
                                        .font(rows[index].emphasized ? .manrope(16, .heavy) : .manrope(15))
                                        .foregroundColor(LCColor.pink)
                                }
                            }
                        }
                        .padding(.horizontal, LCMetrics.screenMargin)
                    }

                    // Raised full-width Close pill (7k).
                    TLButton(title: "Close", background: .pink) {
                        detailViewPresented = false
                    }
                    .padding(.top, 26)
                    .padding(.horizontal, LCMetrics.screenMargin)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(LCColor.surface.ignoresSafeArea())
        .navigationTitle("Ideal Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Neumorphic building blocks (7k)

    /// HH Samuel section header ("OVERVIEW" / "TIMELINE"), deep pink.
    private func sectionHeader(_ title: String, topPadding: CGFloat) -> some View {
        Text(title.uppercased())
            .font(.hhSamuel(22))
            .foregroundColor(LCColor.deepPink)
            .kerning(0.3)
            .padding(.top, topPadding)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
    }

    /// Grouped display row: Manrope 800 label left, value trailing.
    private func detailRow<Value: View>(label: String, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.manrope(16, .heavy))
                .foregroundColor(LCColor.ink)
            Spacer(minLength: 12)
            value()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
    }

    /// Feathered in-card divider (a break, not a track line).
    private var rowDivider: some View {
        NeuFeatheredDivider(widthFraction: 0.9)
            .padding(.horizontal, 16)
    }
}

#Preview {
    IdealHistoryDetailView(
        item: Ideal(
            id: "123",
            category: "Fix",
            title: "Get Milk",
            notes: "Remember to get 2% milk",
            scheduleDateTime: Date().timeIntervalSince1970,
            createdDate: Date().timeIntervalSince1970,
            targetCount: "3",
            doneCount: 2,
            active: false
        ),
        detailViewPresented: .constant(true)
    )
}
