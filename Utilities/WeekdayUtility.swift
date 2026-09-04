//
//  WeekdayUtility.swift
//  The Ideal Week
//
//  Shared helpers for week/day calculations based on user-selected week start day.
//

import Foundation
import FirebaseFirestore

/// Shared day model used by schedule pickers across the app.
struct DayInfo: Hashable {
    let weekday: Int        // 1 = Sunday, 2 = Monday, … 7 = Saturday
    let abbreviation: String
    let dayNumber: String
}

enum WeekdayUtility {
    /// The app-wide default week start day used when no user setting is available.
    static let defaultWeekStartDay = "Monday"

    /// Ordered day abbreviations indexed by `Calendar.weekday` (1-based: index 0 = Sunday).
    static let dayAbbreviations = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    static let weekdayMap: [String: Int] = [
        "Sunday": 1,
        "Monday": 2,
        "Tuesday": 3,
        "Wednesday": 4,
        "Thursday": 5,
        "Friday": 6,
        "Saturday": 7
    ]

    static func weekdayIndex(for weekStartDay: String, defaultValue: Int = 2) -> Int {
        weekdayMap[weekStartDay] ?? defaultValue
    }

    /// Cached calendars keyed by firstWeekday index to avoid repeated allocation.
    private static var calendarCache: [Int: Calendar] = [:]
    private static var calendarCacheBaseId: Calendar.Identifier?

    static func calendar(firstWeekday weekStartDay: String) -> Calendar {
        let idx = weekdayIndex(for: weekStartDay)
        let currentId = Calendar.current.identifier
        // Invalidate cache if system calendar changed (e.g. locale switch)
        if calendarCacheBaseId != currentId {
            calendarCache.removeAll()
            calendarCacheBaseId = currentId
        }
        if let cached = calendarCache[idx] {
            return cached
        }
        var cal = Calendar.current
        cal.firstWeekday = idx
        calendarCache[idx] = cal
        return cal
    }

    static func weekStart(for date: Date = DateProviderService.shared.now(), weekStartDay: String) -> Date {
        let customCalendar = calendar(firstWeekday: weekStartDay)
        let components = customCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = customCalendar.date(from: components) ?? date
        return customCalendar.startOfDay(for: start)
    }

    static func currentWeekRange(for date: Date = DateProviderService.shared.now(), weekStartDay: String) -> (start: Date, end: Date) {
        let customCalendar = calendar(firstWeekday: weekStartDay)
        let start = weekStart(for: date, weekStartDay: weekStartDay)
        let end = (customCalendar.date(byAdding: .day, value: 6, to: start) ?? start).endOfDay
        return (start, end)
    }

    static func nextWeekRange(for date: Date = DateProviderService.shared.now(), weekStartDay: String) -> (start: Date, end: Date) {
        let customCalendar = calendar(firstWeekday: weekStartDay)
        let currentStart = weekStart(for: date, weekStartDay: weekStartDay)
        let nextStart = customCalendar.date(byAdding: .day, value: 7, to: currentStart) ?? currentStart
        let nextEnd = (customCalendar.date(byAdding: .day, value: 6, to: nextStart) ?? nextStart).endOfDay
        return (customCalendar.startOfDay(for: nextStart), nextEnd)
    }

    static func previousWeekRange(for date: Date = DateProviderService.shared.now(), weekStartDay: String) -> (start: Date, end: Date) {
        let customCalendar = calendar(firstWeekday: weekStartDay)
        let currentStart = weekStart(for: date, weekStartDay: weekStartDay)
        let previousStart = customCalendar.date(byAdding: .day, value: -7, to: currentStart) ?? currentStart
        let previousEnd = (customCalendar.date(byAdding: .day, value: 6, to: previousStart) ?? previousStart).endOfDay
        return (customCalendar.startOfDay(for: previousStart), previousEnd)
    }

    /// Returns the week range containing the most recent ideal startDate that falls strictly before
    /// the current week. Treats wishlist (startDate == 0) implicitly as ineligible (caller must
    /// pre-filter or rely on the > 0 check inside).
    /// Returns nil if no eligible startDate exists (e.g. brand-new user, or every ideal is in the
    /// current/future weeks).
    static func lastActiveWeekRange(
        fromStartDates startDates: [TimeInterval],
        weekStartDay: String,
        referenceDate: Date = DateProviderService.shared.now()
    ) -> (start: Date, end: Date)? {
        let currentStartTs = weekStart(for: referenceDate, weekStartDay: weekStartDay).timeIntervalSince1970
        let eligible = startDates.lazy.filter { $0 > 0 && $0 < currentStartTs }
        guard let maxTs = eligible.max() else { return nil }
        let anchor = Date(timeIntervalSince1970: maxTs)
        let customCalendar = calendar(firstWeekday: weekStartDay)
        let start = weekStart(for: anchor, weekStartDay: weekStartDay)
        let end = (customCalendar.date(byAdding: .day, value: 6, to: start) ?? start).endOfDay
        return (start, end)
    }

    static func weekIdentifier(for date: Date = DateProviderService.shared.now(), weekStartDay: String) -> (year: Int, week: Int) {
        let customCalendar = calendar(firstWeekday: weekStartDay)
        return (
            customCalendar.component(.year, from: date),
            customCalendar.component(.weekOfYear, from: date)
        )
    }

    static func daysUntilNextWeekStart(from date: Date = DateProviderService.shared.now(), weekStartDay: String) -> Int {
        let startIndex = weekdayIndex(for: weekStartDay)
        let currentWeekday = Calendar.current.component(.weekday, from: date)
        let delta = (startIndex - currentWeekday + 7) % 7
        return delta == 0 ? 7 : delta
    }

    /// Day index since start of current week (S): 0 = S, 1 = S+1, ... 6 = S+6. For dates before S, returns 0.
    static func daysSinceWeekStart(from date: Date = DateProviderService.shared.now(), weekStartDay: String) -> Int {
        let customCalendar = calendar(firstWeekday: weekStartDay)
        let start = weekStart(for: date, weekStartDay: weekStartDay)
        let dayDiff = customCalendar.dateComponents([.day], from: start, to: date).day ?? 0
        return max(0, min(6, dayDiff))
    }

    /// Planning window = last 2 days of the current week [S+5 start-of-day, S+7 start-of-day),
    /// using the user's selected week-start setting.
    static func isWithinPlanningWindow(from date: Date = DateProviderService.shared.now(), weekStartDay: String) -> Bool {
        let customCalendar = calendar(firstWeekday: weekStartDay)
        let weekStartDate = weekStart(for: date, weekStartDay: weekStartDay)
        guard
            let windowStart = customCalendar.date(byAdding: .day, value: 5, to: weekStartDate),
            let weekEnd = customCalendar.date(byAdding: .day, value: 7, to: weekStartDate)
        else {
            return false
        }
        return date >= windowStart && date < weekEnd
    }
}

/// "Skip Reviews This Week?" is scoped to the week it was switched on in.
///
/// The decision lives here, apart from the flag it governs, so that every
/// completion path (list swipe, recap, …) asks the identical question — a
/// path that reads `skip_reviews` without expiring it first honours a flag
/// that ran out weeks ago.
enum SkipReviewsExpiry {
    /// Pure: has the week the flag was enabled in ended?
    static func shouldExpire(skipReviews: Bool,
                             lastResetDate: TimeInterval,
                             weekStartDay: String,
                             now: Date) -> Bool {
        guard skipReviews else { return false }
        // Legacy rows written before the set-date was stamped. Expire rather
        // than bail: an unstamped flag would otherwise never run out.
        guard lastResetDate > 0 else { return true }
        let currentWeekStart = WeekdayUtility.weekStart(for: now, weekStartDay: weekStartDay)
        return lastResetDate < currentWeekStart.timeIntervalSince1970
    }
}

enum IdealDuplicateGuard {
    private static let separator = "\u{1F}"
    private static let db = Firestore.firestore()

    static func normalizedTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizedCategory(_ category: String) -> String {
        category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func duplicateKey(category: String, title: String) -> String? {
        let normalizedCategory = normalizedCategory(category)
        let normalizedTitle = normalizedTitle(title)
        guard !normalizedCategory.isEmpty, !normalizedTitle.isEmpty else { return nil }
        return "\(normalizedCategory)\(separator)\(normalizedTitle)"
    }

    static func displayLabel(title: String, category: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = trimmedTitle.isEmpty ? "Untitled" : trimmedTitle
        let safeCategory = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Uncategorized" : category
        return "\"\(safeTitle)\" (\(safeCategory))"
    }

    /// Cleanup counterpart of the create-time guard: given ideals already scoped
    /// to ONE week, return the copies that should be deleted — for every
    /// `duplicateKey` collision keep one and hand back the rest.
    ///
    /// Pure (no Firestore) so the decision is unit-testable, and keyed by
    /// `duplicateKey` so the cleaner and the guard can never disagree about what
    /// "duplicate" means. Wishlist ideals are exempt — the create-time guard
    /// ignores them, so duplicates among them are legal.
    static func duplicatesToRemove(from ideals: [Ideal]) -> [Ideal] {
        var byKey: [String: [Ideal]] = [:]
        for ideal in ideals {
            guard !ideal.wishlistEnabled else { continue }
            guard let key = duplicateKey(category: ideal.category, title: ideal.title) else { continue }
            // Also key on the week the ideal belongs to. Defensive: if a caller
            // ever passes a slightly wrong week window, two DIFFERENT weeks'
            // copies of a recurring ideal ("Walk Dog" every week) still can't
            // fuse into a false duplicate and get last week's copy deleted.
            byKey["\(ideal.startDate)\(separator)\(key)", default: []].append(ideal)
        }

        var toRemove: [Ideal] = []
        for (_, group) in byKey where group.count > 1 {
            // Survivor = the copy holding the most PROGRESS. Only then the
            // newest, and finally the highest id.
            //
            // Progress wins over recency because the copies are not
            // interchangeable: if the user has been ticking off one copy and a
            // stray duplicate arrived later, "keep the newest" would throw the
            // completions away. Counts are never merged — that would invent
            // completions the user never made.
            //
            // The id tie-break keeps the choice identical on every device: two
            // clients cleaning at once must not each keep a different copy and
            // delete the other's, which would erase the ideal entirely.
            let sorted = group.sorted {
                ($0.doneCount, $0.createdDate, $0.id) > ($1.doneCount, $1.createdDate, $1.id)
            }
            toRemove.append(contentsOf: sorted.dropFirst())
        }
        return toRemove
    }

    static func currentWeekBounds(weekStartDay: String) -> (start: TimeInterval, nextStart: TimeInterval) {
        let start = WeekdayUtility.weekStart(weekStartDay: weekStartDay).timeIntervalSince1970
        let nextStart = WeekdayUtility.nextWeekRange(weekStartDay: weekStartDay).start.timeIntervalSince1970
        return (start, nextStart)
    }

    static func fetchCurrentWeekKeys(userId: String, weekStartDay: String, excludingIds: Set<String> = [], completion: @escaping (Result<Set<String>, Error>) -> Void) {
        let bounds = currentWeekBounds(weekStartDay: weekStartDay)
        let query = db.collection("users")
            .document(userId)
            .collection("ideals")
            .whereField("startDate", isGreaterThanOrEqualTo: bounds.start)
            .whereField("startDate", isLessThan: bounds.nextStart)

        func keys(from snapshot: QuerySnapshot?) -> Set<String> {
            var keys: Set<String> = []
            for document in snapshot?.documents ?? [] {
                if excludingIds.contains(document.documentID) { continue }
                let data = document.data()
                let wishlistEnabled = data["wishlistEnabled"] as? Bool ?? false
                if wishlistEnabled { continue }

                let category = data["category"] as? String ?? ""
                let title = data["title"] as? String ?? ""
                if let key = duplicateKey(category: category, title: title) {
                    keys.insert(key)
                }
            }
            return keys
        }

        // Read the CACHE first: it contains local pending writes (an ideal saved
        // seconds ago on a slow uplink) that a server read can miss — that gap
        // let a retried save slip past this guard and write a duplicate (client
        // bug 2026-07-15). Then union with the server read for cross-device
        // truth; if the server read fails but the cache read worked, guard with
        // the cached keys instead of failing the save flow outright.
        query.getDocuments(source: .cache) { cacheSnapshot, cacheError in
            let cacheKeys: Set<String>? = cacheError == nil ? keys(from: cacheSnapshot) : nil
            query.getDocuments { snapshot, error in
                if let error = error {
                    if let cacheKeys {
                        completion(.success(cacheKeys))
                    } else {
                        completion(.failure(error))
                    }
                    return
                }
                var merged = keys(from: snapshot)
                if let cacheKeys {
                    merged.formUnion(cacheKeys)
                }
                completion(.success(merged))
            }
        }
    }

    static func fetchKeysForIdealIds(userId: String, idealIds: [String], completion: @escaping (Result<Set<String>, Error>) -> Void) {
        fetchKeyMapForIdealIds(userId: userId, idealIds: idealIds) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let keyMap):
                completion(.success(Set(keyMap.values)))
            }
        }
    }

    static func fetchKeyMapForIdealIds(userId: String, idealIds: [String], completion: @escaping (Result<[String: String], Error>) -> Void) {
        let uniqueIds = Array(Set(idealIds))
        guard !uniqueIds.isEmpty else {
            completion(.success([:]))
            return
        }

        let chunks = stride(from: 0, to: uniqueIds.count, by: 30).map {
            Array(uniqueIds[$0..<min($0 + 30, uniqueIds.count)])
        }

        let idealsCollection = db.collection("users").document(userId).collection("ideals")
        let group = DispatchGroup()
        var keyMap: [String: String] = [:]
        var firstError: Error?
        let lock = NSLock()

        for chunk in chunks {
            group.enter()
            idealsCollection
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments { snapshot, error in
                    defer { group.leave() }

                    if let error {
                        lock.lock()
                        if firstError == nil {
                            firstError = error
                        }
                        lock.unlock()
                        return
                    }

                    let docs = snapshot?.documents ?? []
                    var localMap: [String: String] = [:]
                    for doc in docs {
                        let data = doc.data()
                        let wishlistEnabled = data["wishlistEnabled"] as? Bool ?? false
                        if wishlistEnabled { continue }
                        let category = data["category"] as? String ?? ""
                        let title = data["title"] as? String ?? ""
                        if let key = duplicateKey(category: category, title: title) {
                            localMap[doc.documentID] = key
                        }
                    }

                    lock.lock()
                    for (docId, key) in localMap {
                        keyMap[docId] = key
                    }
                    lock.unlock()
                }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
            } else {
                completion(.success(keyMap))
            }
        }
    }
}
