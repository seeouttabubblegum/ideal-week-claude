//
//  PixelConversion.swift
//  The Ideal Week
//
//  Global helper to convert raw pixel values (e.g. measured off @3x design
//  artboards) into SwiftUI points using the device's screen scale.
//

import UIKit

/// Converts a pixel value to points using the *current device* scale:
/// `points = pixels / UIScreen.main.scale`.
///
/// Use this when the pixel value comes from the live device (e.g. a measurement
/// taken at runtime). Falls back to a scale of 1 if the main screen scale is
/// unavailable (e.g. some preview/headless contexts).
func pointsFromPixels(_ pixels: CGFloat) -> CGFloat {
    let scale = UIScreen.main.scale
    return pixels / (scale > 0 ? scale : 1)
}

/// Fixed scale of the design artboards the web designer hands off (iPhone 17 Pro /
/// Pro Max are both @3x: 1179×2556 and 1320×2868 px respectively).
let designArtboardScale: CGFloat = 3

/// Converts a pixel value measured off the @3x design artboard into points,
/// always dividing by 3 — independent of the device the app actually runs on.
///
/// Prefer this over `pointsFromPixels` for design specs: a spec value like
/// "77px gap" must render as the same 25.67pt on every device (Pro, Pro Max,
/// and the older @2x phones alike), so the conversion must use the artboard's
/// fixed @3x scale, not the device's own scale.
func pointsFromArtboardPixels(_ pixels: CGFloat) -> CGFloat {
    pixels / designArtboardScale
}
