//
//  CommunityIdealService.swift
//  The Ideal Week
//
//  Handles reading from and writing to the root-level `community_ideals` Firestore collection.
//  Documents are keyed by a normalized version of the ideal title so the same title from
//  multiple users accumulates into a single document.
//

import Foundation
import FirebaseFirestore

struct CommunityIdeal {
    let title: String
    let category: String
    let totalScore: Int
    let reviewCount: Int
    var avgScore: Double { reviewCount > 0 ? Double(totalScore) / Double(reviewCount) : 0 }
}

final class CommunityIdealService {
    static let shared = CommunityIdealService()
    private let db = Firestore.firestore()
    private init() {}

    // MARK: - Document key

    /// Normalises a title into a safe, stable Firestore document ID.
    /// e.g. "Sleep Early!" → "sleep_early" (max 100 chars)
    static func titleKey(for title: String) -> String {
        let cleaned = title
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == " " }
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
        return String(cleaned.prefix(100))
    }

    // MARK: - Write

    /// Upserts an ideal title into community_ideals, atomically incrementing score counters.
    func upsert(title: String, category: String, score: Int) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let key = CommunityIdealService.titleKey(for: title)
        db.collection("community_ideals").document(key).setData([
            "title": title,
            "category": category,
            "totalScore": FieldValue.increment(Int64(score)),
            "reviewCount": FieldValue.increment(Int64(1)),
            "lastUpdated": Date().timeIntervalSince1970
        ], merge: true)
    }

    // MARK: - Read

    /// Fetches top community ideals, filters personal titles via PersonalContentFilter,
    /// then returns the top `resultLimit` sorted by average score descending.
    func fetchTopCommunityIdeals(resultLimit: Int = 25) async -> [CommunityIdeal] {
        return await withCheckedContinuation { continuation in
            db.collection("community_ideals")
                .order(by: "reviewCount", descending: true)
                .limit(to: 200)
                .getDocuments { snapshot, error in
                    guard let docs = snapshot?.documents, !docs.isEmpty else {
                        continuation.resume(returning: [])
                        return
                    }

                    let parsed: [CommunityIdeal] = docs.compactMap { doc in
                        let data = doc.data()
                        guard
                            let title = data["title"] as? String,
                            let category = data["category"] as? String,
                            let totalScore = data["totalScore"] as? Int,
                            let reviewCount = data["reviewCount"] as? Int,
                            reviewCount > 0
                        else { return nil }
                        return CommunityIdeal(
                            title: title,
                            category: category,
                            totalScore: totalScore,
                            reviewCount: reviewCount
                        )
                    }

                    // Filter personal titles using on-device Apple NaturalLanguage AI
                    let filtered = parsed.filter { !PersonalContentFilter.isPersonal($0.title) }

                    // Sort by average score descending, then cap
                    let sorted = filtered
                        .sorted { $0.avgScore > $1.avgScore }
                        .prefix(resultLimit)

                    continuation.resume(returning: Array(sorted))
                }
        }
    }
}
