//
//  SubscriptionManager.swift
//  The Ideal Week
//
//  Created for managing subscriptions
//

import Foundation
import StoreKit
import UIKit

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let productIDs = AppStoreConfig.productIDs
    private let expectedAppleID = AppStoreConfig.expectedAppleID
    private let isWorkflowEnabled = AppStoreConfig.isSubscriptionWorkflowEnabled
    private var bootstrapTask: Task<Void, Never>?
    private var transactionUpdatesTask: Task<Void, Never>?
    
    // Server API credentials removed from client app for security.
    // These must only exist on a secure backend server.
    
    init() {
        guard isWorkflowEnabled else { return }
        bootstrapTask = Task { [weak self] in
            guard let self else { return }
            await self.loadProducts()
            await self.updatePurchasedProducts()
            self.startTransactionListenerIfNeeded()
        }
    }

    private func logDebug(_ message: String) {
        AppLogger.debug(AppLogger.subscription, message)
    }

    private func logError(_ message: String) {
        AppLogger.error(AppLogger.subscription, message)
    }
    
    private func startTransactionListenerIfNeeded() {
        guard transactionUpdatesTask == nil else { return }
        
        transactionUpdatesTask = Task { [weak self] in
            // Listen for new transactions (including offer code redemptions from sandbox)
            for await result in Transaction.updates {
                if Task.isCancelled { break }
                guard let self else { break }
                await self.handleTransactionUpdate(result)
            }
        }
    }
    
    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            logDebug("===========================================")
            logDebug("NEW TRANSACTION DETECTED:")
            logDebug("Product ID: \(transaction.productID)")
            logDebug("Transaction ID: \(transaction.id)")
            logDebug("Original Transaction ID: \(transaction.originalID)")
            logDebug("Purchase Date: \(transaction.purchaseDate)")
            if let expirationDate = transaction.expirationDate {
                logDebug("Expiration Date: \(expirationDate)")
            }
            logDebug("Expected Apple ID for reference: \(expectedAppleID)")
            logDebug("===========================================")
            await transaction.finish()
            await updatePurchasedProducts()
        } catch {
            logError("Transaction verification failed: \(error)")
        }
    }
    
    deinit {
        bootstrapTask?.cancel()
        transactionUpdatesTask?.cancel()
    }
    
    func loadProducts() async {
        guard isWorkflowEnabled else {
            products = []
            isLoading = false
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        
        logDebug("===========================================")
        logDebug("LOADING PRODUCTS FROM APP STORE CONNECT:")
        logDebug("Source: App Store Connect (NOT local StoreKit Configuration)")
        logDebug("Product IDs to load: \(productIDs)")
        logDebug("Bundle ID: \(AppStoreConfig.bundleIdentifier)")
        logDebug("Subscription Group: \(AppStoreConfig.subscriptionGroupName) (ID: \(AppStoreConfig.subscriptionGroupID))")
        logDebug("App Store Server API credentials: [removed from client]")
        logDebug("Expected Apple ID: \(expectedAppleID)")
        logDebug("===========================================")
        
        // Product.products(for:) loads from App Store Connect, not local StoreKit Configuration files
        // This ensures real products are used for sandbox and production testing
        do {
            let loadedProducts = try await Product.products(for: productIDs)
            logDebug("Loaded \(loadedProducts.count) products. Product IDs requested: \(productIDs)")
            
            if loadedProducts.isEmpty {
                let detailedError = """
                No products found for IDs: idealweekapp, idealweekappyearly
                
                Configuration:
                - Bundle ID: \(AppStoreConfig.bundleIdentifier)
                - Product IDs: \(productIDs)
                - Subscription Group ID: \(AppStoreConfig.subscriptionGroupID)
                - Subscription Group Name: \(AppStoreConfig.subscriptionGroupName)
                - App Store Server API credentials: [removed from client]
                
                Please verify in App Store Connect:
                1. Product IDs "idealweekapp" and "idealweekappyearly" exist and are created
                2. Products are associated with bundle ID: \(AppStoreConfig.bundleIdentifier)
                3. Products are in subscription group "app fees" (ID: \(AppStoreConfig.subscriptionGroupID))
                4. Product status is "Ready to Submit" or "Approved"
                5. For sandbox testing: Products are enabled for sandbox testing
                6. You're signed in with a sandbox tester account in Settings > App Store
                7. StoreKit Configuration schema in Xcode is set to "None"
                
                Common issues:
                - Product IDs typo or mismatch
                - Products not associated with this app
                - Products not in the correct subscription group
                - Products not approved/ready for testing
                - Wrong sandbox account signed in
                - StoreKit Configuration file interfering (set schema to "None" in Xcode)
                """
                errorMessage = "No products found. Please check your App Store Connect configuration. Product IDs: idealweekapp, idealweekappyearly. Ensure StoreKit Configuration schema is set to 'None' in Xcode."
                logDebug("===========================================")
                logError("WARNING: NO PRODUCTS LOADED")
                logDebug("===========================================")
                logDebug(detailedError)
                logDebug("===========================================")
            } else {
                products = loadedProducts.sorted { product1, product2 in
                    // Sort yearly first, then monthly
                    if product1.id.contains("yearly") {
                        return true
                    } else if product2.id.contains("yearly") {
                        return false
                    }
                    return product1.id < product2.id
                }
                logDebug("===========================================")
                logDebug("SUCCESSFULLY LOADED PRODUCTS:")
                for product in products {
                    logDebug("  - Product ID: \(product.id)")
                    logDebug("    Display Name: \(product.displayName)")
                    logDebug("    Description: \(product.description)")
                    if let subscription = product.subscription {
                        logDebug("    Subscription Duration: \(subscription.subscriptionPeriod)")
                    }
                }
                logDebug("===========================================")
            }
        } catch {
            let detailedError = """
            Failed to load products: \(error.localizedDescription)
            
            Error details:
            - Product IDs requested: \(productIDs)
            - Bundle ID: \(AppStoreConfig.bundleIdentifier)
            - Error: \(error)
            
            Troubleshooting:
            1. Check internet connection
            2. Verify product exists in App Store Connect
            3. Ensure product is associated with correct bundle ID
            4. Check if signed in with correct sandbox account
            """
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            logDebug("===========================================")
            logError("ERROR LOADING PRODUCTS:")
            logDebug("===========================================")
            logDebug(detailedError)
            logDebug("===========================================")
            products = []
        }
        
        isLoading = false
    }
    
    func updatePurchasedProducts() async {
        guard isWorkflowEnabled else {
            purchasedProductIDs = []
            return
        }

        var newProductIDs: Set<String> = []
        logDebug("===========================================")
        logDebug("CHECKING CURRENT ENTITLEMENTS:")
        logDebug("Expected Apple ID for reference: \(expectedAppleID)")
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                logDebug("---")
                logDebug("Product ID: \(transaction.productID)")
                logDebug("Transaction ID: \(transaction.id)")
                logDebug("Original Transaction ID: \(transaction.originalID)")
                
                // Check if transaction is still valid (not expired)
                if let expirationDate = transaction.expirationDate {
                    logDebug("Expiration Date: \(expirationDate)")
                    if expirationDate > Date() {
                        newProductIDs.insert(transaction.productID)
                        logDebug("Status: ACTIVE (not expired)")
                    } else {
                        logDebug("Status: EXPIRED")
                    }
                } else {
                    // No expiration date means it's a non-consumable or lifetime purchase
                    newProductIDs.insert(transaction.productID)
                    logDebug("Status: ACTIVE (lifetime/non-consumable)")
                }
            } catch {
                logError("Transaction verification failed: \(error)")
            }
        }
        purchasedProductIDs = newProductIDs
        logDebug("---")
        logDebug("Active subscriptions: \(purchasedProductIDs)")
        logDebug("===========================================")
    }
    
    func purchase(_ product: Product) async throws -> Transaction? {
        logDebug("===========================================")
        logDebug("ATTEMPTING PURCHASE:")
        logDebug("Product ID: \(product.id)")
        logDebug("Product Display Name: \(product.displayName)")
        logDebug("Expected Apple ID for reference: \(expectedAppleID)")
        logDebug("===========================================")
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            logDebug("===========================================")
            logDebug("PURCHASE SUCCESSFUL:")
            logDebug("Product ID: \(transaction.productID)")
            logDebug("Transaction ID: \(transaction.id)")
            logDebug("Original Transaction ID: \(transaction.originalID)")
            logDebug("Purchase Date: \(transaction.purchaseDate)")
            if let expirationDate = transaction.expirationDate {
                logDebug("Expiration Date: \(expirationDate)")
            }
            logDebug("Expected Apple ID for reference: \(expectedAppleID)")
            logDebug("===========================================")
            await transaction.finish()
            await updatePurchasedProducts()
            return transaction
        case .userCancelled:
            logDebug("Purchase cancelled by user")
            return nil
        case .pending:
            logDebug("Purchase is pending")
            return nil
        @unknown default:
            return nil
        }
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    var hasActiveSubscription: Bool {
        guard isWorkflowEnabled else { return true }
        return !purchasedProductIDs.isEmpty
    }
    
    func restorePurchases() async {
        guard isWorkflowEnabled else { return }

        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func presentCodeRedemptionSheet() {
        guard isWorkflowEnabled else { return }

        // Present the offer code redemption sheet using StoreKit
        Task { @MainActor in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                errorMessage = "Unable to access window scene. Please try again."
                return
            }
            
            // Use StoreKit 2's method to present offer code redemption
            do {
                try await AppStore.presentOfferCodeRedeemSheet(in: windowScene)
                // Wait a bit for the redemption to process
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                // After redemption, update subscription status
                await updatePurchasedProducts()
            } catch {
                let errorDesc = error.localizedDescription
                // Provide helpful error message for common issues
                if errorDesc.contains("connect") || errorDesc.contains("network") {
                    errorMessage = "Cannot connect to App Store. Please check your internet connection and make sure you're signed in with a sandbox tester account in Settings > App Store."
                } else {
                    errorMessage = "Failed to open offer code redemption: \(errorDesc). Make sure you're signed in with a sandbox account and offer codes are configured in App Store Connect."
                }
                logError("Error presenting offer code redemption: \(error)")
            }
        }
    }
    
    
    // Check if a subscription is active by looking at current entitlements
    // This will be called periodically to check for new redemptions
    func checkSubscriptionStatus() async {
        guard isWorkflowEnabled else { return }
        await updatePurchasedProducts()
    }
}

enum StoreError: Error {
    case failedVerification
}
