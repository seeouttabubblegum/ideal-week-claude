//
//  DateProviderService.swift
//  The Ideal Week
//
//  Central "now" abstraction for weekly prompt and other date-sensitive logic.
//  When virtual override is disabled (default), returns real Date().
//  DEBUG panel can enable override and set a virtual date for testing.
//

import Foundation

/// Provides the current date/time. Production uses real time; DEBUG can override for testing.
/// All property writes happen on the main thread (SwiftUI bindings). Reads via now() are safe
/// because the underlying Bool and Date are value types with atomic reads on Apple platforms.
final class DateProviderService: ObservableObject {
    static let shared = DateProviderService()

    private enum Keys {
        static let isVirtualDateOverrideEnabled = "debug_virtual_date_override_enabled"
        static let virtualDate = "debug_virtual_date_override_value"
    }

    /// When true and virtualDate is set, now() returns virtualDate. Otherwise returns Date().
    @Published var isVirtualDateOverrideEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isVirtualDateOverrideEnabled, forKey: Keys.isVirtualDateOverrideEnabled)
        }
    }

    /// Virtual date used when isVirtualDateOverrideEnabled is true.
    @Published var virtualDate: Date {
        didSet {
            UserDefaults.standard.set(virtualDate.timeIntervalSince1970, forKey: Keys.virtualDate)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        let storedTimestamp = defaults.object(forKey: Keys.virtualDate) as? TimeInterval ?? Date().timeIntervalSince1970
        self.virtualDate = Date(timeIntervalSince1970: storedTimestamp)
        #if DEBUG
        self.isVirtualDateOverrideEnabled = defaults.bool(forKey: Keys.isVirtualDateOverrideEnabled)
        #else
        // Release builds never run on a virtual clock. The flag lives in
        // UserDefaults and survives an app update, so a tester who left the
        // override on in a TestFlight build would otherwise carry it into the
        // App Store build — with the controls compiled out, they could never
        // turn it back off. Clear it rather than merely ignoring it, because
        // other code reads this property directly (e.g. the weekly-prompt test
        // gate) and must agree that we are on real time.
        self.isVirtualDateOverrideEnabled = false
        defaults.removeObject(forKey: Keys.isVirtualDateOverrideEnabled)
        #endif
    }

    /// Returns virtual date when override is enabled, otherwise real now.
    func now() -> Date {
        #if DEBUG
        if isVirtualDateOverrideEnabled {
            return virtualDate
        }
        #endif
        return Date()
    }

    /// Set virtual date to real now (e.g. "Set to Now" in debug panel).
    func setVirtualToNow() {
        virtualDate = Date()
    }

    func setUsingDeviceTime(_ useDeviceTime: Bool) {
        if useDeviceTime {
            isVirtualDateOverrideEnabled = false
        } else {
            if virtualDate.timeIntervalSince1970 == 0 {
                virtualDate = Date()
            }
            isVirtualDateOverrideEnabled = true
        }
    }
}
