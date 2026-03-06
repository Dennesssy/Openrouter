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
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var apiKey = ""
    @State private var defaultTemperature = 0.7
    @State private var defaultMaxTokens = 2048
    @State private var costLimitPerSession = 1.0
    @State private var showCostWarnings = true
    @State private var dailyBudgetLimit: Double = 5.0
    @State private var currencyCode = "USD"
    @State private var showSubscriptionView = false
    @State private var showClearConfirmation = false
    @State private var isReimporting = false

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
                        if subscriptionManager.isSubscribed {
                            Text("Active")
                                .foregroundColor(.green)
                        } else {
                            Button("Upgrade") {
                                showSubscriptionView = true
                            }
                            .foregroundColor(.blue)
                        }
                    }

                    if subscriptionManager.isSubscribed {
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
                        HStack {
                            Text("Re-import Models")
                            if isReimporting {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isReimporting)
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Models", value: "345 available")
                }
            }
            .navigationTitle("Settings")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .onAppear {
                loadPreferences()
                // Sync subscription status on appear
                Task {
                    await subscriptionManager.checkSubscriptionStatus()
                    syncSubscriptionStatus()
                }
            }
            .onDisappear {
                savePreferences()
            }
            .sheet(isPresented: $showSubscriptionView) {
                SubscriptionView()
            }
            .onChange(of: subscriptionManager.isSubscribed) { oldValue, newValue in
                syncSubscriptionStatus()
            }
            .confirmationDialog("Clear All Data", isPresented: $showClearConfirmation) {
                Button("Clear All Chat History", role: .destructive) {
                    performClearAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all chat sessions, messages, and cost logs. This action cannot be undone.")
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
        }
    }
    
    private func syncSubscriptionStatus() {
        guard var prefs = userPreferences else { return }
        prefs.isSubscribedToPremium = subscriptionManager.isSubscribed
        try? modelContext.save()
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
            prefs.isSubscribedToPremium = subscriptionManager.isSubscribed
        } else {
            let newPrefs = UserPreferences()
            newPrefs.isSubscribedToPremium = subscriptionManager.isSubscribed
            newPrefs.currencyCode = currencyCode
            newPrefs.dailyBudgetLimit = dailyBudgetLimit
            newPrefs.defaultTemperature = defaultTemperature
            newPrefs.defaultMaxTokens = defaultMaxTokens
            newPrefs.costLimitPerSession = costLimitPerSession
            newPrefs.showCostWarnings = showCostWarnings
            modelContext.insert(newPrefs)
        }

        try? modelContext.save()
    }
    
    private func clearAllData() {
        showClearConfirmation = true
    }
    
    private func performClearAllData() {
        // Delete all chat sessions and messages
        do {
            let sessionDescriptor = FetchDescriptor<ChatSession>()
            let sessions = try modelContext.fetch(sessionDescriptor)
            
            for session in sessions {
                modelContext.delete(session)
            }
            
            // Clear daily cost logs
            let costLogDescriptor = FetchDescriptor<DailyCostLog>()
            let costLogs = try modelContext.fetch(costLogDescriptor)
            
            for log in costLogs {
                modelContext.delete(log)
            }
            
            try modelContext.save()
            print("Successfully cleared all chat history and cost logs")
        } catch {
            print("Error clearing data: \(error)")
        }
    }

    private func reimportModels() {
        Task {
            isReimporting = true
            defer { isReimporting = false }
            
            do {
                guard let apiKey = try? KeychainManager.shared.getAPIKey() else {
                    print("No API key available for model import")
                    return
                }
                
                let client = OpenRouterClient(apiKey: apiKey)
                let importService = ModelImportService(client: client)
                
                // Delete existing models first
                let modelDescriptor = FetchDescriptor<AIModel>()
                let existingModels = try modelContext.fetch(modelDescriptor)
                for model in existingModels {
                    modelContext.delete(model)
                }
                try modelContext.save()
                
                // Reset the import flag so it can re-import
                UserDefaults.standard.set(false, forKey: "hasCompletedInitialModelImport")
                
                // Re-import
                let newModelNames = try await importService.importModels(into: modelContext)
                
                // Mark as complete again
                UserDefaults.standard.set(true, forKey: "hasCompletedInitialModelImport")
                
                print("Re-imported \(newModelNames.count) models")
            } catch {
                print("Error re-importing models: \(error)")
            }
        }
    }
}