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

                    // Subscription Status
                    subscriptionStatusView
                        .padding(.horizontal)

                    // Features List
                    featuresList

                    // Restore Purchases
                    if !subscriptionManager.isSubscribed {
                        Button(action: {
                            Task {
                                await restorePurchases()
                            }
                        }) {
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
                // Refresh subscription status when view appears
                await subscriptionManager.checkSubscriptionStatus()
            }
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if subscriptionManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
        }
    }

    // MARK: - Status View

    @ViewBuilder
    private var subscriptionStatusView: some View {
        if subscriptionManager.isSubscribed {
            VStack(spacing: 16) {
                statusBadgeView
                
                Text(subscriptionStatusDescription)
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
        } else {
            // Subscription Options
            VStack(spacing: 16) {
                if let monthly = subscriptionManager.monthlyProduct {
                    SubscriptionOptionCard(
                        product: monthly,
                        isPopular: false
                    ) {
                        await purchase(product: monthly)
                    }
                }

                if let yearly = subscriptionManager.yearlyProduct {
                    SubscriptionOptionCard(
                        product: yearly,
                        isPopular: true
                    ) {
                        await purchase(product: yearly)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusBadgeView: some View {
        let status = subscriptionManager.subscriptionStatus
        
        switch status {
        case .subscribed:
            subscriptionBadge(text: "✅ Premium Active", color: .green)
            
        case .inGracePeriod:
            subscriptionBadge(text: "⚠️ Grace Period", color: .orange)
            
        case .inBillingRetryPeriod:
            subscriptionBadge(text: "⏳ Billing Issue", color: .orange)
            
        case .expired(let date):
            VStack(spacing: 8) {
                subscriptionBadge(text: "❌ Expired", color: .red)
                Text("Expired on \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
        case .revoked:
            subscriptionBadge(text: "🚫 Revoked", color: .red)
            
        case .notSubscribed, .unknown:
            subscriptionBadge(text: "❓ Unknown", color: .gray)
        }
    }

    private func subscriptionBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.headline)
            .foregroundColor(color)
    }

    private var subscriptionStatusDescription: String {
        switch subscriptionManager.subscriptionStatus {
        case .subscribed(let date):
            if let date = date {
                return "Your subscription renews on \(date.formatted(date: .abbreviated, time: .omitted))"
            }
            return "Premium features are active"
            
        case .inGracePeriod:
            return "Your payment failed but you still have access. Please update your payment method to avoid interruption."
            
        case .inBillingRetryPeriod:
            return "We're retrying your payment. Please update your payment method in Settings."
            
        case .expired, .revoked:
            return "Your subscription has ended. Subscribe again to regain access to premium features."
            
        case .notSubscribed, .unknown:
            return ""
        }
    }

    // MARK: - Features List

    private var featuresList: some View {
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
    }

    // MARK: - Actions

    private func purchase(product: Product) async {
        do {
            try await subscriptionManager.purchaseMonthly() // or purchaseYearly based on product.id
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func restorePurchases() async {
        do {
            try await subscriptionManager.restorePurchases()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
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

                // Show introductory offer if available
                if let subscription = product.subscription,
                   let introductoryOffer = subscription.introductoryOffer {
                    Text("Limited time: \(introductoryOffer.displayPrice)")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }

                // Regular price
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
            .background(Color.gray.opacity(0.1))
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
