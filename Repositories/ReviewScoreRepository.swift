//
//  ReviewScoreRepository.swift
//  The Ideal Week
//
//  Shared Firestore access for ideal review scores.
//

import Foundation
import FirebaseFirestore

enum ReviewScoreRepository {
    static func fetchScoresByIdeal(userId: String, idealIds: [String], db: Firestore = Firestore.firestore()) async -> [String: [ReviewScore]] {
        var result: [String: [ReviewScore]] = [:]

        await withTaskGroup(of: (String, [ReviewScore]).self) { group in
            for idealId in idealIds {
                group.addTask {
                    await fetchReviewScoresForIdeal(idealId: idealId, userId: userId, db: db)
                }
            }

            for await (idealId, scores) in group {
                result[idealId] = scores
            }
        }

        return result
    }

    private static func fetchReviewScoresForIdeal(idealId: String, userId: String, db: Firestore) async -> (String, [ReviewScore]) {
        await withCheckedContinuation { continuation in
            db.collection("users")
                .document(userId)
                .collection("ideals")
                .document(idealId)
                .collection("reviewScores")
                .order(by: "date")
                .getDocuments { snapshot, error in
                    if let error {
                        AppLogger.error(AppLogger.firestore, "[ReviewScoreRepository] Error fetching scores for ideal \(idealId): \(error.localizedDescription)")
                    }
                    let scores: [ReviewScore] = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: ReviewScore.self)
                    } ?? []
                    continuation.resume(returning: (idealId, scores))
                }
        }
    }
}
