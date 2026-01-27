//
//  SettingsView.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]

    @State private var apiKey = ""
    @State private var defaultTemperature = 0.7
    @State private var defaultMaxTokens = 2048
    @State private var costLimitPerSession = 1.0
    @State private var showCostWarnings = true
    @State private var dailyBudgetLimit: Double = 5.0
    @State private var currencyCode = "USD"
    @State private var isSubscribedToPremium = false
    @State private var showSubscriptionView = false

    private var userPreferences: UserPreferences? {
        preferences.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("API Configuration") {
                    SecureField("OpenRouter API Key", text: $apiKey)
                        .textContentType(.password)

                    if KeychainManager.shared.hasAPIKey() {
                        Text("API key is set")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("API key required for chat functionality")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                Section("Default Parameters") {
                    VStack(alignment: .leading) {
                        Text("Temperature: \(String(format: "%.1f", defaultTemperature))")
                        Slider(value: $defaultTemperature, in: 0...2, step: 0.1)
                        Text("Controls randomness. Lower values make output more focused.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading) {
                        Text("Max Tokens: \(defaultMaxTokens)")
                        Slider(value: Binding(
                            get: { Double(defaultMaxTokens) },
                            set: { defaultMaxTokens = Int($0) }
                        ), in: 256...8192, step: 256)
                        Text("Maximum length of generated response.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Cost Management") {
                    VStack(alignment: .leading) {
                        Text("Daily Budget: $\(String(format: "%.2f", dailyBudgetLimit))")
                        Slider(value: $dailyBudgetLimit, in: 1...50, step: 1)
                        Text("Daily spending limit to control costs.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading) {
                        Text("Per Session Limit: $\(String(format: "%.2f", costLimitPerSession))")
                        Slider(value: $costLimitPerSession, in: 0.1...10, step: 0.1)
                        Text("Maximum cost per chat session.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Toggle("Show Cost Warnings", isOn: $showCostWarnings)

                    Picker("Currency", selection: $currencyCode) {
                        Text("USD").tag("USD")
                        Text("EUR").tag("EUR")
                        Text("GBP").tag("GBP")
                    }
                }

                Section("Subscription") {
                    HStack {
                        Text("Premium Status")
                        Spacer()
                        if isSubscribedToPremium {
                            Text("Active")
                                .foregroundColor(.green)
                        } else {
                            Button("Upgrade") {
                                showSubscriptionView = true
                            }
                            .foregroundColor(.blue)
                        }
                    }

                    if isSubscribedToPremium {
                        Text("Premium features: Advanced analytics, export, custom ordering")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Data Management") {
                    Button(action: clearAllData) {
                        Text("Clear All Chat History")
                            .foregroundColor(.red)
                    }

                    Button(action: reimportModels) {
                        Text("Re-import Models")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Models", value: "345 available")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadPreferences()
            }
            .onDisappear {
                savePreferences()
            }
            .sheet(isPresented: $showSubscriptionView) {
                SubscriptionView()
            }
        }
    }

    private func loadPreferences() {
        // Load API key from Keychain
        do {
            apiKey = try KeychainManager.shared.getAPIKey()
        } catch {
            apiKey = ""
        }

        if let prefs = userPreferences {
            defaultTemperature = prefs.defaultTemperature
            defaultMaxTokens = prefs.defaultMaxTokens
            dailyBudgetLimit = prefs.dailyBudgetLimit ?? 5.0
            costLimitPerSession = prefs.costLimitPerSession
            showCostWarnings = prefs.showCostWarnings
            currencyCode = prefs.currencyCode
            isSubscribedToPremium = prefs.isSubscribedToPremium
        }
    }

    private func savePreferences() {
        // Save API key to Keychain
        do {
            if apiKey.isEmpty {
                try KeychainManager.shared.deleteAPIKey()
            } else {
                try KeychainManager.shared.saveAPIKey(apiKey)
            }
        } catch {
            print("Error saving API key: \(error)")
        }

        if var prefs = userPreferences {
            prefs.defaultTemperature = defaultTemperature
            prefs.defaultMaxTokens = defaultMaxTokens
            prefs.dailyBudgetLimit = dailyBudgetLimit
            prefs.costLimitPerSession = costLimitPerSession
            prefs.showCostWarnings = showCostWarnings
            prefs.currencyCode = currencyCode
            prefs.isSubscribedToPremium = isSubscribedToPremium
        } else {
            let newPrefs = UserPreferences(
                isSubscribedToPremium: isSubscribedToPremium,
                currencyCode: currencyCode,
                dailyBudgetLimit: dailyBudgetLimit,
                defaultTemperature: defaultTemperature,
                defaultMaxTokens: defaultMaxTokens,
                costLimitPerSession: costLimitPerSession,
                showCostWarnings: showCostWarnings
            )
            modelContext.insert(newPrefs)
        }

        try? modelContext.save()
    }

    private func clearAllData() {
        // TODO: Implement clear all chat data
        print("Clear all chat history")
    }

    private func reimportModels() {
        // TODO: Implement re-import models
        print("Re-import models")
    }
}