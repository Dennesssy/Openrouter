//
//  SubscriptionView.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import SwiftUI
import StoreKit
#if os(iOS)
import UIKit
#endif

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var monthlyProduct: Product?
    @State private var yearlyProduct: Product?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.yellow)

                        Text("OpenRouter Premium")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Unlock advanced features for power users")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)

                    if subscriptionManager.isSubscribed {
                        // Current Subscription Status
                        VStack(spacing: 16) {
                            Text("✅ Premium Active")
                                .font(.headline)
                                .foregroundColor(.green)

                            Text("You have access to all premium features")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
#if os(iOS)
                        .background(Color(.systemGray6))
#else
                        .background(Color.gray.opacity(0.2))
#endif
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        // Subscription Options
                        VStack(spacing: 16) {
                            if let monthly = monthlyProduct {
                                SubscriptionOptionCard(
                                    product: monthly,
                                    isPopular: false,
                                    action: { await purchase(product: monthly) }
                                )
                            }

                            if let yearly = yearlyProduct {
                                SubscriptionOptionCard(
                                    product: yearly,
                                    isPopular: true,
                                    action: { await purchase(product: yearly) }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Features List
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Premium Features")
                            .font(.headline)
                            .padding(.horizontal)

                        FeatureRow(icon: "chart.bar.fill", title: "Advanced Analytics", description: "Detailed spending trends and model performance")
                        FeatureRow(icon: "square.and.arrow.up", title: "Export Conversations", description: "Save chats as PDF or Markdown files")
                        FeatureRow(icon: "star.fill", title: "Custom Model Ordering", description: "Reorder and favorite your preferred models")
                        FeatureRow(icon: "target", title: "Model A/B Testing", description: "Compare responses side-by-side")
                        FeatureRow(icon: "bell.fill", title: "Budget Alerts", description: "Get notified when approaching spending limits")
                        FeatureRow(icon: "cloud.fill", title: "Cloud Sync", description: "Sync preferences across devices (coming soon)")
                        FeatureRow(icon: "person.fill", title: "Priority Support", description: "Direct access to our support team")
                    }
                    .padding(.horizontal)

                    // Restore Purchases
                    if !subscriptionManager.isSubscribed {
                        Button(action: restorePurchases) {
                            Text("Restore Purchases")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 16)
                    }

                    Spacer()
                }
                .padding(.bottom, 32)
            }
#if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Done") {
                dismiss()
            }
        }
    }
#endif
            .task {
                await loadProducts()
            }
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
        }
    }


    private func loadProducts() async {
        do {
            monthlyProduct = try await subscriptionManager.getMonthlyProduct()
            yearlyProduct = try await subscriptionManager.getYearlyProduct()
        } catch {
            print("Error loading products: \(error)")
        }
    }

    private func purchase(product: Product) async {
        isLoading = true
        defer { isLoading = false }

        do {
            switch product.id {
            case subscriptionManager.monthlyProductId:
                try await subscriptionManager.purchaseMonthly()
            case subscriptionManager.yearlyProductId:
                try await subscriptionManager.purchaseYearly()
            default:
                throw SubscriptionError.productNotFound
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func restorePurchases() {
        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                try await subscriptionManager.restorePurchases()
            } catch {
                errorMessage = "Failed to restore purchases"
                showError = true
            }
        }
    }
}

struct SubscriptionOptionCard: View {
    let product: Product
    let isPopular: Bool
    let action: () async -> Void

    @State private var isPurchasing = false

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                if isPopular {
                    Text("MOST POPULAR")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }

                Text(product.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)

                if let subscription = product.subscription {
                    Text({
                        let period = subscription.subscriptionPeriod
                        let unit: String
                        switch period.unit {
                        case .day: unit = period.value == 1 ? "day" : "days"
                        case .week: unit = period.value == 1 ? "week" : "weeks"
                        case .month: unit = period.value == 1 ? "month" : "months"
                        case .year: unit = period.value == 1 ? "year" : "years"
                        @unknown default: unit = "period"
                        }
                        return "\(period.value) \(unit)"
                    }())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text(product.displayPrice)
                    .font(.title)
                    .fontWeight(.bold)

                Button(action: {
                    Task {
                        isPurchasing = true
                        await action()
                        isPurchasing = false
                    }
                }) {
                    ZStack {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Subscribe")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isPurchasing)
            }
            .padding()
#if os(iOS)
            .background(Color(.systemBackground))
#else
#if os(iOS)
            .background(Color(.systemBackground))
#else
            .background(Color.gray.opacity(0.1))
#endif
#endif
            .cornerRadius(16)
            .shadow(radius: 4)
            .overlay {
                if isPopular {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue, lineWidth: 2)
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SubscriptionView()
}