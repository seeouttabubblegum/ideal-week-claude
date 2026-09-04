//
//  The_Ideal_WeekApp.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 22/5/25.
//


import SwiftData
import SwiftUI
import FirebaseCore
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  var modelContext: ModelContext?
  
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    
    // Request notification permissions on first launch
    UNUserNotificationCenter.current().delegate = self
    // Note: modelContext will be set from the App struct after initialization
    // Reminders are only removed when the ideal is deleted or the user changes the schedule (not when past due).

    return true
  }
  
  func applicationDidBecomeActive(_ application: UIApplication) {
  }
  
  func requestNotificationAuthorization() {
    NotificationManager.shared.requestAuthorization(modelContext: modelContext)
  }
  
  
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound, .badge])
  }
  
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    completionHandler()
  }
}
@main
struct The_Ideal_WeekApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var blurApp = false
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([MainSettings.self, UserProfileSettings.self])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // If persistent store fails, try in-memory as fallback
            AppLogger.error(AppLogger.app, "Failed to initialize persistent ModelContainer: \(error.localizedDescription)")
            do {
                let schema = Schema([MainSettings.self, UserProfileSettings.self])
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: [configuration])
                AppLogger.info(AppLogger.app, "Using in-memory ModelContainer as fallback")
            } catch {
                fatalError("Failed to initialize ModelContainer: \(error.localizedDescription)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MenuView()
                .background(LCColor.surface.ignoresSafeArea())
                .preferredColorScheme(.light)
                .onAppear {
                    delegate.modelContext = container.mainContext
                    delegate.requestNotificationAuthorization()
                }
                .overlay {
                    if blurApp {
                        LCColor.surface.ignoresSafeArea()
                    }
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            blurApp = newPhase != .active
            // App-wide "open" counter (weekly prompt's second chance is per open:
            // launch, or return from background). Reported here so it is bumped
            // even when the ideal list is not the screen on top.
            AppOpenSession.noteScenePhase(newPhase)
        }
    }
}
