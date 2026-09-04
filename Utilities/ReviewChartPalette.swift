//
//  ReviewChartPalette.swift
//  The Ideal Week
//
//  Shared chart color generation for category-based review charts.
//

import SwiftUI

enum ReviewChartPalette {
    static func color(for category: Category, fallback: Color) -> Color {
        let allCategories = Category.allCases
        guard let index = allCategories.firstIndex(of: category) else {
            return fallback
        }

        let totalCategories = allCategories.count
        let hueStep = 360.0 / Double(totalCategories)
        let baseHue = (Double(index) * hueStep).truncatingRemainder(dividingBy: 360.0) / 360.0
        let saturation = 0.75 + Double(index % 3) * 0.1
        let brightness = 0.5 + Double((index / 3) % 3) * 0.15

        return Color(hue: baseHue, saturation: saturation, brightness: brightness)
    }
}
