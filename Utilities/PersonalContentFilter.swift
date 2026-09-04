//
//  PersonalContentFilter.swift
//  The Ideal Week
//
//  On-device Apple NaturalLanguage filter that detects personal/private ideal titles
//  so only generic, universally-applicable titles surface in community top ideals.
//

import NaturalLanguage

struct PersonalContentFilter {

    // Returns true if the title appears to be personal/private and should be excluded
    // from community top ideals.
    static func isPersonal(_ title: String) -> Bool {
        let lower = title.lowercased()

        // 1. Keyword blocklist — family relationships + personal admin terms
        // Multi-word phrases use substring match; single words use whole-word match
        // to avoid false positives like "ola" matching "polar", "son" matching "lesson"
        if hasPersonalKeyword(lower) {
            return true
        }

        // 2. NLTagger — detect proper personal names (e.g. "Jen", "John", "Sarah")
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = title
        var hasPersonalName = false
        tagger.enumerateTags(
            in: title.startIndex..<title.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, _ in
            if tag == .personalName {
                hasPersonalName = true
                return false // stop enumeration
            }
            return true
        }
        return hasPersonalName
    }

    // Checks the lowercased title against personalKeywords.
    // Multi-word phrases → substring match (they're specific enough).
    // Single words → whole-word match to avoid "ola" matching "polar", "son" matching "lesson", etc.
    private static func hasPersonalKeyword(_ lower: String) -> Bool {
        for kw in personalKeywords {
            if kw.contains(" ") {
                // Multi-word phrase: substring is fine
                if lower.contains(kw) { return true }
            } else {
                // Single word: check ALL occurrences for word-boundary match
                var searchStart = lower.startIndex
                while let range = lower.range(of: kw, range: searchStart..<lower.endIndex) {
                    let before = range.lowerBound == lower.startIndex
                        || !lower[lower.index(before: range.lowerBound)].isLetter
                    let after = range.upperBound == lower.endIndex
                        || !lower[range.upperBound].isLetter
                    if before && after { return true }
                    searchStart = range.upperBound
                }
            }
        }
        return false
    }

    // Family, relationship, and personal admin keywords
    private static let personalKeywords: [String] = [
        // Family / relationship words
        "mom", "dad", "mama", "papa", "nana", "grandma", "grandpa",
        "grandad", "granny", "nan", "granddad",
        "sister", "brother", "wife", "husband", "partner",
        "daughter", "son", "aunt", "uncle", "cousin", "niece", "nephew",
        "fiancé", "fiancee", "boyfriend", "girlfriend",
        // Social roles
        "boss", "manager", "coworker", "colleague", "client", "customer",
        "therapist", "counsellor", "counselor",
        // Personal admin
        "tax", "taxes", "invoice", "bill", "bills", "receipt",
        "mortgage", "rent", "landlord",
        "appointment", "dentist", "doctor", "physician", "prescription",
        "lawyer", "attorney", "accountant",
        "passport", "visa", "license", "licence",
        "insurance", "policy", "claim",
        "salary", "paycheck", "payslip",
        "bank", "banking", "loan", "credit card",
        // Transport / ride-hailing / errands
        "lyft", "careem", "grab", "ola", "bolt", "eb",
        "taxi", "cab", "pickup", "pick up", "drop off", "dropoff",
        "airport", "flight", "boarding", "check-in", "check in",
        "parcel", "package", "courier", "delivery", "shipment",
        // Specific named services / places
        "amazon", "walmart", "costco", "ikea", "dmv",
        // Calendar / scheduling specifics
        "meeting", "interview", "call with", "zoom with", "lunch with",
        "dinner with", "coffee with", "catch up with",
    ]
}
