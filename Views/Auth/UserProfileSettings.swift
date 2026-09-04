//
//  UserProfileSettings.swift
//  The Ideal Week
//
//  Created for local profile picture storage
//

import SwiftData
import Foundation

@Model
class UserProfileSettings {
    var profilePictureData: Data?
    var userId: String
    
    init(userId: String, profilePictureData: Data? = nil) {
        self.userId = userId
        self.profilePictureData = profilePictureData
    }
}
