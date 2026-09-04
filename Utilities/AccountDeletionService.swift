//
//  AccountDeletionService.swift
//  The Ideal Week
//
//  Performs the account deletion described by `AccountDeletionPlan`.
//
//  Order matters. Firestore data is removed FIRST, while the user is still
//  authenticated — security rules only allow a user to touch their own
//  `users/{uid}` tree, so once the Auth account is gone the data would be
//  unreachable and orphaned forever. The Auth account is deleted last.
//
//  Firebase requires a recent sign-in before deleting an account. When the
//  session is old it returns `requiresRecentLogin`; the caller then collects the
//  password and calls `reauthenticate` before retrying.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import EventKit

enum AccountDeletionError: LocalizedError, Equatable {
    case notSignedIn
    case requiresRecentLogin
    case wrongPassword
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You are not signed in."
        case .requiresRecentLogin:
            return "For your security, please re-enter your password to continue."
        case .wrongPassword:
            return "That password doesn't match. Please try again."
        case .failed(let message):
            return message
        }
    }
}

final class AccountDeletionService {
    static let shared = AccountDeletionService()
    private init() {}

    private let db = Firestore.firestore()
    /// Firestore caps a batch at 500 writes.
    private let batchLimit = 400

    // MARK: - Re-authentication

    /// Refreshes the sign-in so `delete()` is allowed. Email/password is the
    /// only provider this app uses.
    func reauthenticate(password: String, completion: @escaping (Result<Void, AccountDeletionError>) -> Void) {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            completion(.failure(.notSignedIn))
            return
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        user.reauthenticate(with: credential) { _, error in
            DispatchQueue.main.async {
                guard let error = error as NSError? else {
                    completion(.success(()))
                    return
                }
                let code = AuthErrorCode(rawValue: error.code)
                if code == .wrongPassword || code == .invalidCredential || code == .invalidEmail {
                    completion(.failure(.wrongPassword))
                } else {
                    completion(.failure(.failed(error.localizedDescription)))
                }
            }
        }
    }

    // MARK: - Deletion

    /// Deletes the signed-in user's data and then their account.
    /// On `.requiresRecentLogin` the Firestore data is left untouched, so the
    /// caller can re-authenticate and call this again safely.
    func deleteAccount(completion: @escaping (Result<Void, AccountDeletionError>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(.notSignedIn))
            return
        }
        let uid = user.uid
        let plan = AccountDeletionPlan(userId: uid)

        // Ask Auth first whether it will even allow the delete. Wiping the
        // user's ideals and then failing on `requiresRecentLogin` would destroy
        // their data while leaving the account alive.
        user.getIDTokenForcingRefresh(true) { [weak self] _, error in
            guard let self else { return }
            if let error = error as NSError?,
               AuthErrorCode(rawValue: error.code) == .userTokenExpired
                || AuthErrorCode(rawValue: error.code) == .requiresRecentLogin {
                DispatchQueue.main.async { completion(.failure(.requiresRecentLogin)) }
                return
            }

            self.removeLocalReminders(uid: uid) {
                self.deleteFirestoreData(plan: plan) { firestoreResult in
                    switch firestoreResult {
                    case .failure(let error):
                        DispatchQueue.main.async { completion(.failure(error)) }
                    case .success:
                        user.delete { error in
                            DispatchQueue.main.async {
                                if let error = error as NSError? {
                                    if AuthErrorCode(rawValue: error.code) == .requiresRecentLogin {
                                        completion(.failure(.requiresRecentLogin))
                                    } else {
                                        completion(.failure(.failed(error.localizedDescription)))
                                    }
                                    return
                                }
                                self.clearLocalState(plan: plan)
                                AppLogger.info(AppLogger.auth, "Account deleted and local state cleared")
                                completion(.success(()))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Firestore

    private func deleteFirestoreData(plan: AccountDeletionPlan,
                                     completion: @escaping (Result<Void, AccountDeletionError>) -> Void) {
        let userDoc = db.document(plan.userDocumentPath)

        // reviewScores hang off each ideal, so those have to go before the
        // ideals themselves — a deleted parent document does not take its
        // subcollections with it in Firestore.
        userDoc.collection("ideals").getDocuments { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                completion(.failure(.failed(error.localizedDescription)))
                return
            }
            let idealIds = snapshot?.documents.map(\.documentID) ?? []
            let group = DispatchGroup()
            var firstError: Error?

            for idealId in idealIds {
                group.enter()
                self.deleteAll(in: self.db.collection(plan.reviewScoresPath(idealId: idealId))) { error in
                    if let error { firstError = firstError ?? error }
                    group.leave()
                }
            }

            group.notify(queue: .global()) {
                if let firstError {
                    completion(.failure(.failed(firstError.localizedDescription)))
                    return
                }
                let outer = DispatchGroup()
                var outerError: Error?
                for path in plan.userSubcollectionPaths {
                    outer.enter()
                    self.deleteAll(in: self.db.collection(path)) { error in
                        if let error { outerError = outerError ?? error }
                        outer.leave()
                    }
                }
                outer.notify(queue: .global()) {
                    if let outerError {
                        completion(.failure(.failed(outerError.localizedDescription)))
                        return
                    }
                    userDoc.delete { error in
                        if let error {
                            completion(.failure(.failed(error.localizedDescription)))
                        } else {
                            completion(.success(()))
                        }
                    }
                }
            }
        }
    }

    /// Deletes every document in a collection, a batch at a time.
    private func deleteAll(in collection: CollectionReference,
                           completion: @escaping (Error?) -> Void) {
        collection.limit(to: batchLimit).getDocuments { [weak self] snapshot, error in
            guard let self else { return }
            if let error { completion(error); return }
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                completion(nil)
                return
            }
            let batch = collection.firestore.batch()
            documents.forEach { batch.deleteDocument($0.reference) }
            batch.commit { error in
                if let error { completion(error); return }
                // A full page means there may be more.
                if documents.count < self.batchLimit {
                    completion(nil)
                } else {
                    self.deleteAll(in: collection, completion: completion)
                }
            }
        }
    }

    // MARK: - Local

    /// Removes the EKReminders this account created, before its ideals are gone
    /// and the reminder ids with them. Best-effort: reminder access may have
    /// been denied, in which case there is nothing of ours in the store anyway.
    private func removeLocalReminders(uid: String, completion: @escaping () -> Void) {
        db.collection("users").document(uid).collection("ideals").getDocuments { snapshot, _ in
            let documents = snapshot?.documents ?? []
            for document in documents {
                let data = document.data()
                let reminderIds = data["reminderIds"] as? [String] ?? []
                let legacyId = data["reminderId"] as? String
                guard !reminderIds.isEmpty || legacyId != nil else { continue }
                NotificationManager.removeRemindersForIdeal(reminderIds: reminderIds,
                                                            legacyReminderId: legacyId)
            }
            completion()
        }
    }

    private func clearLocalState(plan: AccountDeletionPlan) {
        BiometricCredentialStore.shared.clear()
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where plan.shouldClearUserDefaultsKey(key) {
            defaults.removeObject(forKey: key)
        }
    }
}
