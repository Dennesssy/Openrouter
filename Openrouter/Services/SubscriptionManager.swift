//
//  SubscriptionManager.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation
import StoreKit
import Combine
import OSLog

@MainActor
class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isSubscribed = false
    @Published var subscriptionStatus: SubscriptionState = .notSubscribed
    @Published var isLoading = false
    
    private let logger = Logger(subsystem: "com.openrouter.app", category: "Subscription")
    
    // Callback to sync with UserPreferences
    var onSubscriptionStatusChanged: ((Bool) -> Void)?

    // Product IDs
    let monthlyProductId = "com.openrouter.premium.monthly"
    let yearlyProductId = "com.openrouter.premium.yearly"
    
    // Subscription group ID (configure in App Store Connect)
    let subscriptionGroupId = "premium_subscriptions"

    private var products: [Product] = []
    private var updatesTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    enum SubscriptionState: Equatable {
        case notSubscribed
        case subscribed(expirationDate: Date?)
        case inGracePeriod(expirationDate: Date)  // Payment failed, but user retains access
        case inBillingRetryPeriod(expirationDate: Date)  // System is retrying payment
        case expired(expirationDate: Date)  // Subscription ended
        case revoked  // Refund or other issue caused revocation
        case unknown  // Unable to determine status
        
        var allowsPremiumAccess: Bool {
            switch self {
            case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                return true
            case .notSubscribed, .expired, .revoked, .unknown:
                return false
            }
        }
    }

    override init() {
        super.init()
        setupTransactionListener()
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            self.products = try await Product.products(for: [monthlyProductId, yearlyProductId])
            logger.info("Loaded \(self.products.count) products")
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
        }
    }

    var monthlyProduct: Product? {
        products.first { $0.id == monthlyProductId }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == yearlyProductId }
    }

    // MARK: - Subscription Status

    private func setupTransactionListener() {
        updatesTask = Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                do {
                    guard let self = self else { return }
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.checkSubscriptionStatus()
                    self.logger.info("Transaction finished: \(transaction.productID)")
                } catch {
                    self?.logger.error("Transaction update failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func checkSubscriptionStatus() async {
        do {
            // Use the new currentEntitlements(for:) API for more efficient checking
            var hasActiveSubscription = false
            var status: Product.SubscriptionInfo.Status? = nil
            
            // Check monthly subscription
            for await verificationResult in Transaction.currentEntitlements(for: monthlyProductId) {
                if case .verified = verificationResult {
                    hasActiveSubscription = true
                    if let product = monthlyProduct,
                       let subscription = product.subscription,
                       let productStatus = try await subscription.status.first {
                        status = productStatus
                    }
                    break
                }
            }
            
            // Check yearly subscription if no monthly found
            if !hasActiveSubscription {
                for await verificationResult in Transaction.currentEntitlements(for: yearlyProductId) {
                    if case .verified = verificationResult {
                        hasActiveSubscription = true
                        if let product = yearlyProduct,
                           let subscription = product.subscription,
                           let productStatus = try await subscription.status.first {
                            status = productStatus
                        }
                        break
                    }
                }
            }

            let previousSubscriptionState = isSubscribed
            
            if let status = status {
                let state = status.state
                
                // Get expiration date from the transaction
                let expirationDate: Date? = {
                    switch status.transaction {
                    case .verified(let transaction):
                        return transaction.expirationDate
                    case .unverified(let transaction, _):
                        // Even unverified transactions can provide expiration date
                        return transaction.expirationDate
                    }
                }()
                
                // Use if-else because RenewalState is a struct, not an enum
                if state == .subscribed {
                    isSubscribed = true
                    subscriptionStatus = .subscribed(expirationDate: expirationDate)
                    logger.info("Subscription active, renews on: \(expirationDate?.description ?? "unknown")")
                } else if state == .inGracePeriod {
                    isSubscribed = true  // Still allow access during grace period
                    let expiration = expirationDate ?? Date()
                    subscriptionStatus = .inGracePeriod(expirationDate: expiration)
                    logger.warning("Subscription in grace period, expires: \(expiration)")
                } else if state == .inBillingRetryPeriod {
                    // Per Apple docs, billing retry period does NOT grant entitlement
                    // However, we choose to maintain access for better UX
                    isSubscribed = true
                    let expiration = expirationDate ?? Date()
                    subscriptionStatus = .inBillingRetryPeriod(expirationDate: expiration)
                    logger.warning("Subscription in billing retry, expires: \(expiration)")
                } else if state == .expired {
                    isSubscribed = false
                    let expiration = expirationDate ?? Date()
                    subscriptionStatus = .expired(expirationDate: expiration)
                    logger.notice("Subscription expired on: \(expiration)")
                } else if state == .revoked {
                    isSubscribed = false
                    subscriptionStatus = .revoked
                    logger.error("Subscription was revoked")
                } else {
                    // Unknown state
                    isSubscribed = false
                    subscriptionStatus = .unknown
                    logger.warning("Unknown subscription state")
                }
            } else {
                isSubscribed = false
                subscriptionStatus = .notSubscribed
            }
            
            // Notify if subscription status changed
            if previousSubscriptionState != isSubscribed {
                onSubscriptionStatusChanged?(isSubscribed)
            }

        } catch {
            logger.error("Error checking subscription status: \(error.localizedDescription)")
            isSubscribed = false
            subscriptionStatus = .unknown
        }
    }

    private func calculateExpirationDate(for transaction: Transaction) -> Date? {
        guard transaction.productType == .autoRenewable else {
            return nil
        }
        return transaction.expirationDate
    }

    // MARK: - Purchase

    func purchaseMonthly() async throws {
        guard let product = monthlyProduct else {
            throw SubscriptionError.productNotFound
        }
        try await purchase(product)
    }

    func purchaseYearly() async throws {
        guard let product = yearlyProduct else {
            throw SubscriptionError.productNotFound
        }
        try await purchase(product)
    }

    private func purchase(_ product: Product) async throws {
        isLoading = true
        defer { isLoading = false }

        logger.info("Starting purchase for: \(product.id)")

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            logger.info("Purchase successful, verifying...")
            let transaction = try checkVerified(verification)
            
            // Log successful purchase
            logger.notice("✅ Purchase completed: \(product.id)")
            
            // Deliver content immediately for verified transaction
            await transaction.finish()
            await checkSubscriptionStatus()
            
        case .userCancelled:
            logger.info("Purchase cancelled by user")
            throw SubscriptionError.userCancelled
            
        case .pending:
            logger.info("Purchase pending (e.g., Ask to Buy)")
            throw SubscriptionError.pending
            
        @unknown default:
            logger.error("Unknown purchase result")
            throw SubscriptionError.unknown
        }
    }

    // MARK: - Restore

    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        logger.info("Starting restore purchases")

        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            logger.info("Restore completed")
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
            throw SubscriptionError.restoreFailed(error)
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, _):
            // In production, you might want to verify with your server
            // For now, we reject unverified transactions
            logger.error("Transaction verification failed - possible tampering detected")
            throw SubscriptionError.failedVerification
            
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - User Info

    func getSubscriptionDescription() async -> String {
        if isSubscribed {
            let statusText: String
            let expireText: String?

            switch subscriptionStatus {
            case .subscribed(let date):
                statusText = "Active"
                expireText = date?.formatted(date: .abbreviated, time: .omitted)
            case .inGracePeriod(let date):
                statusText = "Grace Period"
                expireText = date.formatted(date: .abbreviated, time: .omitted)
            case .inBillingRetryPeriod(let date):
                statusText = "Billing Retry"
                expireText = date.formatted(date: .abbreviated, time: .omitted)
            case .expired(let date):
                statusText = "Expired"
                expireText = date.formatted(date: .abbreviated, time: .omitted)
            case .revoked:
                statusText = "Revoked"
                expireText = nil
            case .notSubscribed, .unknown:
                statusText = "Unknown"
                expireText = nil
            }

            if let expire = expireText {
                return "Premium (\(statusText)) - Renews \(expire)"
            } else {
                return "Premium (\(statusText))"
            }
        } else {
            return "Upgrade to Premium for advanced analytics, export features, and more"
        }
    }

    var canAccessPremiumFeatures: Bool {
        isSubscribed
    }
    
    // Check if subscription is shared via Family Sharing
    func isSubscriptionShared() async -> Bool {
        for await entitlement in Transaction.currentEntitlements(for: monthlyProductId) {
            if case .verified(let transaction) = entitlement {
                return transaction.ownershipType == .familyShared
            }
        }
        
        for await entitlement in Transaction.currentEntitlements(for: yearlyProductId) {
            if case .verified(let transaction) = entitlement {
                return transaction.ownershipType == .familyShared
            }
        }
        
        return false
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case productNotFound
    case userCancelled
    case pending
    case failedVerification
    case restoreFailed(Error)
    case purchaseFailed(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Subscription product not found. Please contact support."
        case .userCancelled:
            return "Purchase was cancelled."
        case .pending:
            return "Purchase is pending approval."
        case .failedVerification:
            return "Could not verify purchase. Please contact support."
        case .restoreFailed(let error):
            return "Failed to restore purchases: \(error.localizedDescription)"
        case .purchaseFailed(let message):
            return message
        case .unknown:
            return "An unknown error occurred."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .productNotFound:
            return "Please make sure you're using the latest version of the app."
        case .pending:
            return "Complete the purchase in Settings > [Your Name] > Subscriptions."
        case .failedVerification:
            return "Contact support if this issue persists."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
}
