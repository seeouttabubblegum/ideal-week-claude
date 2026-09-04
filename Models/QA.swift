//
//  QA.swift
//  The Ideal Week
//
//  Created on 1/15/25.
//

import Foundation

struct QA: Codable {
    var id: String
    var userId: String
    var question: String
    var answer: String
    var createdDate: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case id, userId, question, answer, createdDate
    }
    
    init(id: String = UUID().uuidString, userId: String, question: String, answer: String, createdDate: TimeInterval = Date().timeIntervalSince1970) {
        self.id = id
        self.userId = userId
        self.question = question
        self.answer = answer
        self.createdDate = createdDate
    }
}
