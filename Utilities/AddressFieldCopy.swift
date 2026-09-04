//
//  AddressFieldCopy.swift
//  The Ideal Week
//
//  Naming for the address form's postal field, which is one input with two
//  names depending on the selected country (client, 2026-09-02).
//
//  The keyboard travels with the label on purpose. A US zip is digits only, so
//  the number pad is right there — but Canadian ("K1A 0B1") and UK ("SW1A 1AA")
//  codes contain letters, and a number pad makes the field impossible to fill.
//  Keeping both answers in one place stops the label from being localised while
//  the keyboard silently stays US-only.
//

import UIKit

enum AddressFieldCopy {
    private static let unitedStates = "United States"

    static func postalLabel(country: String) -> String {
        country == unitedStates ? "Zip Code" : "Postal Code"
    }

    static func postalUsesNumberPad(country: String) -> Bool {
        country == unitedStates
    }

    static func postalKeyboard(country: String) -> UIKeyboardType {
        postalUsesNumberPad(country: country) ? .numberPad : .default
    }
}
