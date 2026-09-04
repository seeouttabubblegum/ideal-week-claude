//
//  User.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//

import Foundation
struct User: Codable{
    var id: String
    var first_name: String
    var last_name: String
    var email: String
    var joined: TimeInterval
    
    // Optional profile fields
    var date_of_birth: TimeInterval? = nil
    var gender: String? = nil
    var address: String? = nil
    var city: String? = nil
    var state: String? = nil
    var zip_code: String? = nil
    var country: String? = nil
    var height_feet: Int? = nil
    var height_inches: Int? = nil
    var weight_kg: Double? = nil
    var wake_up_time: String? = nil
    var sleep_time: String? = nil
    var work_time_start: String? = nil
    var work_time_end: String? = nil
    var bio: String? = nil
    var goal_focus_areas: String? = nil
}
