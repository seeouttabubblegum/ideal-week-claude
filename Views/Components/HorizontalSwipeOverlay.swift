//
//  HorizontalSwipeOverlay.swift
//  The Ideal Week
//
//  Moved out of LastWeekReviewView (2026-09-04) verbatim — the type was
//  already internal and self-contained. Behaviour unchanged.
//

import SwiftUI
import UIKit

// MARK: - UIKit horizontal swipe recognizer (scroll-safe)
// Uses UIPanGestureRecognizer with velocity check in gestureRecognizerShouldBegin
// so vertical pans FAIL immediately and the ScrollView takes over with zero delay.

struct HorizontalSwipeOverlay: UIViewRepresentable {
    var onTap: () -> Void
    var onChanged: (CGFloat) -> Void
    var onSwipeCompleted: () -> Void
    var onEnded: () -> Void

    /// Swipe completion threshold in points.
    static let swipeThreshold: CGFloat = 50
    /// Haptic trigger threshold in points.
    static let hapticThreshold: CGFloat = 40

    /// Pure function: should a pan with this velocity begin as a horizontal swipe?
    /// Rightward + horizontal dominance (1.5× ratio) required.
    static func shouldBeginHorizontalPan(velocityX: CGFloat, velocityY: CGFloat) -> Bool {
        velocityX > 0 && abs(velocityX) > abs(velocityY) * 1.5
    }

    /// Pure function: clamp a drag translation to [0, maxOffset].
    static func clampedOffset(translationX: CGFloat, maxOffset: CGFloat) -> CGFloat {
        max(0, min(maxOffset, translationX))
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.require(toFail: pan) // Tap only fires when pan doesn't recognize
        tap.cancelsTouchesInView = false

        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onChanged = onChanged
        context.coordinator.onSwipeCompleted = onSwipeCompleted
        context.coordinator.onEnded = onEnded
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onChanged: onChanged, onSwipeCompleted: onSwipeCompleted, onEnded: onEnded)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: () -> Void
        var onChanged: (CGFloat) -> Void
        var onSwipeCompleted: () -> Void
        var onEnded: () -> Void
        private(set) var didTriggerHaptic = false

        init(onTap: @escaping () -> Void, onChanged: @escaping (CGFloat) -> Void, onSwipeCompleted: @escaping () -> Void, onEnded: @escaping () -> Void) {
            self.onTap = onTap
            self.onChanged = onChanged
            self.onSwipeCompleted = onSwipeCompleted
            self.onEnded = onEnded
        }

        // KEY: Only begin pan if clearly rightward-horizontal.
        // Vertical or leftward pans fail instantly → ScrollView handles them.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
                return true // Allow tap gesture to begin normally
            }
            let velocity = pan.velocity(in: pan.view)
            return HorizontalSwipeOverlay.shouldBeginHorizontalPan(velocityX: velocity.x, velocityY: velocity.y)
        }

        // Exclusive: when pan fires, own the gesture fully
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return false
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            onTap()
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            let maxOffset = (gesture.view?.bounds.width ?? UIScreen.main.bounds.width) / 4.0

            switch gesture.state {
            case .changed:
                let clamped = HorizontalSwipeOverlay.clampedOffset(translationX: translation.x, maxOffset: maxOffset)
                onChanged(clamped)
                if clamped > HorizontalSwipeOverlay.hapticThreshold && !didTriggerHaptic {
                    HapticFeedback.impact(style: .light)
                    didTriggerHaptic = true
                }
            case .ended:
                didTriggerHaptic = false
                if translation.x > HorizontalSwipeOverlay.swipeThreshold {
                    onSwipeCompleted()
                }
                onEnded()
            case .cancelled, .failed:
                didTriggerHaptic = false
                onEnded()
            default:
                break
            }
        }
    }
}
