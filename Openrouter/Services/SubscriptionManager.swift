//
//  SubscriptionManager.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation
import StoreKit
import Combine

@MainActor
class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isSubscribed = false
    @Published var subscriptionStatus: Product.SubscriptionInfo.Status?

    private var updatesTask: Task<Void, Never>?

    // Product IDs
    let monthlyProductId = "com.openrouter.premium.monthly"
    let yearlyProductId = "com.openrouter.premium.yearly"

    override init() {
        super.init()
        updatesTask = listenForTransactions()
        checkSubscriptionStatus()
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Subscription Status

    func checkSubscriptionStatus() {
        Task {
            do {
                let products = try await Product.products(for: [monthlyProductId, yearlyProductId])
                guard let product = products.first else { return }

                let statuses = try await product.subscription?.status ?? []
                subscriptionStatus = statuses.first

                // Update subscription status based on current entitlements (async sequence)
                var subscribed = false
                for await transaction in Transaction.currentEntitlements {
                    switch transaction {
                    case .verified(let txn):
                        if txn.productID == monthlyProductId || txn.productID == yearlyProductId {
                            subscribed = true
                        }
                    case .unverified:
                        continue
                    }
                }
                isSubscribed = subscribed
            } catch {
                print("Error checking subscription status: \(error)")
            }
        }
    }

    // MARK: - Purchase Subscription

    func purchaseMonthly() async throws {
        try await purchase(productId: monthlyProductId)
    }

    func purchaseYearly() async throws {
        try await purchase(productId: yearlyProductId)
    }

    private func purchase(productId: String) async throws {
        let products = try await Product.products(for: [productId])
        guard let product = products.first else {
            throw SubscriptionError.productNotFound
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            checkSubscriptionStatus()

        case .userCancelled:
            throw SubscriptionError.userCancelled

        case .pending:
            throw SubscriptionError.pending

        @unknown default:
            throw SubscriptionError.unknown
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async throws {
        try await AppStore.sync()
        checkSubscriptionStatus()
    }

    // MARK: - Transaction Updates

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerified(result)
                    await transaction?.finish()
                    await MainActor.run {
                        self?.checkSubscriptionStatus()
                    }
                } catch {
                    print("Transaction update failed: \(error)")
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Product Information

    func getMonthlyProduct() async throws -> Product? {
        let products = try await Product.products(for: [monthlyProductId])
        return products.first
    }

    func getYearlyProduct() async throws -> Product? {
        let products = try await Product.products(for: [yearlyProductId])
        return products.first
    }

    func getAllProducts() async throws -> [Product] {
        try await Product.products(for: [monthlyProductId, yearlyProductId])
    }
}

// MARK: - Errors

enum SubscriptionError: Error {
    case productNotFound
    case userCancelled
    case pending
    case failedVerification
    case unknown
}

// MARK: - Subscription View Extension

extension SubscriptionManager {
    var subscriptionDescription: String {
        if isSubscribed {
            return "Premium features are active"
        } else {
            return "Upgrade to Premium for advanced analytics, export features, and more"
        }
    }

    var canAccessPremiumFeatures: Bool {
        isSubscribed
    }
}