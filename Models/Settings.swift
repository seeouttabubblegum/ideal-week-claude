//
//  Settings.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 6/10/25.
//

import Foundation
import Observation
import SwiftUI
import SwiftData

@Model
class Settings{
    var isDarkMode: Bool
    init(isDarkMode: Bool = false) {
        self.isDarkMode = isDarkMode
    }
}
