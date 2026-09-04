//
//  AppLogger.swift
//  The Ideal Week
//
//  Centralized app logging.
//

import Foundation
import OSLog

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "org.loveandchaos.theidealweek"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let subscription = Logger(subsystem: subsystem, category: "subscription")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let firestore = Logger(subsystem: subsystem, category: "firestore")
    static let ui = Logger(subsystem: subsystem, category: "ui")

    static func debug(_ logger: Logger, _ message: String) {
#if DEBUG
        logger.log(level: .debug, "\(message, privacy: .public)")
#endif
    }

    static func info(_ logger: Logger, _ message: String) {
        logger.log(level: .info, "\(message, privacy: .public)")
    }

    static func error(_ logger: Logger, _ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
