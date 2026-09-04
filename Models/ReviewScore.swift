//
//  ReviewScore.swift
//  The Ideal Week
//
//  Created for storing individual review scores for each time an ideal is marked as done
//

import Foundation

struct ReviewScore: Codable, Identifiable, Equatable {
    let id: String
    let idealId: String  // Reference to the Ideal
    let position: Int    // The doneCount when this review was submitted
    let score: Int       // Review score (0-100, where 0-10 scale is multiplied by 10)
    let date: TimeInterval  // Date when the review was submitted
    
    init(id: String, idealId: String, position: Int, score: Int, date: TimeInterval) {
        self.id = id
        self.idealId = idealId
        self.position = position
        self.score = score
        self.date = date
    }
}
