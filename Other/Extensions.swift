//
//  Extensions.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//

import Foundation
import SwiftUI
import UIKit

extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: opacity
        )
    }
    func getComponents() -> (red: Double, green: Double, blue: Double, opacity: Double) {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        return (Double(red), Double(green), Double(blue), Double(opacity))
    }
    
    /// Converts RGB to HSL
    func toHSL() -> (hue: Double, saturation: Double, lightness: Double) {
        let components = getComponents()
        let r = components.red
        let g = components.green
        let b = components.blue
        
        let max = Swift.max(r, g, b)
        let min = Swift.min(r, g, b)
        let delta = max - min
        
        var h: Double = 0
        var s: Double = 0
        let l = (max + min) / 2.0
        
        if delta != 0 {
            s = l > 0.5 ? delta / (2.0 - max - min) : delta / (max + min)
            
            if max == r {
                h = ((g - b) / delta + (g < b ? 6.0 : 0.0)) / 6.0
            } else if max == g {
                h = ((b - r) / delta + 2.0) / 6.0
            } else {
                h = ((r - g) / delta + 4.0) / 6.0
            }
        }
        
        return (h, s, l)
    }
    
    /// Converts HSL to RGB Color
    static func fromHSL(hue: Double, saturation: Double, lightness: Double, opacity: Double = 1.0) -> Color {
        let h = hue
        let s = saturation
        let l = lightness
        
        var r: Double = 0
        var g: Double = 0
        var b: Double = 0
        
        if s == 0 {
            r = l
            g = l
            b = l
        } else {
            let q = l < 0.5 ? l * (1 + s) : l + s - l * s
            let p = 2 * l - q
            
            r = hueToRGB(p: p, q: q, t: h + 1.0/3.0)
            g = hueToRGB(p: p, q: q, t: h)
            b = hueToRGB(p: p, q: q, t: h - 1.0/3.0)
        }
        
        return Color(red: r, green: g, blue: b, opacity: opacity)
    }
    
    private static func hueToRGB(p: Double, q: Double, t: Double) -> Double {
        var t = t
        if t < 0 { t += 1 }
        if t > 1 { t -= 1 }
        if t < 1.0/6.0 { return p + (q - p) * 6 * t }
        if t < 1.0/2.0 { return q }
        if t < 2.0/3.0 { return p + (q - p) * (2.0/3.0 - t) * 6 }
        return p
    }
    
    
    /// Returns the complementary color (180° rotation on the color wheel)
    func complementaryColor() -> Color {
        let components = getComponents()
        let hsl = toHSL()
        
        // Complementary color: hue + 180° (0.5 of the color wheel)
        let complementaryHue = (hsl.hue + 0.5).truncatingRemainder(dividingBy: 1.0)
        return Color.fromHSL(hue: complementaryHue, saturation: hsl.saturation, lightness: hsl.lightness, opacity: components.opacity)
    }
    
    /// Returns the original color and its complementary color
    func complementaryColors() -> (color1: Color, color2: Color) {
        return (self, complementaryColor())
    }
    
    /// Returns a lighter version of the color by increasing lightness
    func lighter(by amount: Double = 0.3) -> Color {
        let components = getComponents()
        let hsl = toHSL()
        
        // Increase lightness, but cap at 0.95 to avoid pure white
        let newLightness = min(hsl.lightness + amount, 0.95)
        return Color.fromHSL(hue: hsl.hue, saturation: hsl.saturation, lightness: newLightness, opacity: components.opacity)
    }
}
extension Encodable {
    func asDictionary() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else {
            return [:]
        }
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json ?? [:]
        } catch {
            return [:]
        }
    }
}

extension Date {
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
}
