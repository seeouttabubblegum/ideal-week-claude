//
//  PlannedIdealRecord.swift
//  The Ideal Week
//
//  Stores the IDs of ideals planned via the Next? flow.
//

import Foundation

struct PlannedIdealRecord: Codable, Identifiable, Equatable {
    /// Firestore collection name under users/{uid}/...
    static let collectionName = "planned_ideal_records"
    
    /// Use the planned ideal's ID as the Firestore document ID.
    let id: String
    /// Start date assigned when this ideal was planned (typically next week start).
    var startDate: TimeInterval
    /// Record creation timestamp.
    var createdDate: TimeInterval
    
    init(id: String, startDate: TimeInterval, createdDate: TimeInterval) {
        self.id = id
        self.startDate = startDate
        self.createdDate = createdDate
    }
}
