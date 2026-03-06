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
    @State private var showAPIKeySuccess = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private var userPreferences: UserPreferences? {
        preferences.first
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - API Configuration Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("OpenRouter API Key")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Required for AI chat functionality")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        SecureField("Enter your API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .autocorrectionDisabled()
#if os(iOS)
                            .textInputAutocapitalization(.never)
#endif
                            .onChange(of: apiKey) { _, newValue in
                                if newValue != loadedAPIKey {
                                    saveAPIKeyDebounced(newValue)
                                }
                            }

                        if KeychainManager.shared.hasAPIKey() {
                            Label("API key is securely stored", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Label("Add your API key to start chatting", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        
                        Link(destination: URL(string: "https://openrouter.ai/keys")!) {
                            Label("Get API Key from OpenRouter", systemImage: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Label("API Configuration", systemImage: "network")
                }

                // MARK: - Default Parameters Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        // Temperature Control
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Temperature", systemImage: "thermometer.medium")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(String(format: "%.1f", defaultTemperature))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                                    .monospacedDigit()
                            }
                            
                            Slider(value: $defaultTemperature, in: 0...2, step: 0.1)
                                .tint(.blue)
                            
                            HStack {
                                Text("0.0")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Focused")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Creative")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("2.0")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text("Controls randomness in responses. Lower values produce more focused and deterministic outputs, while higher values increase creativity and variety.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Divider()

                        // Max Tokens Control
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Max Tokens", systemImage: "text.alignleft")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(defaultMaxTokens)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                                    .monospacedDigit()
                            }
                            
                            Slider(value: Binding(
                                get: { Double(defaultMaxTokens) },
                                set: { defaultMaxTokens = Int($0) }
                            ), in: 256...8192, step: 256)
                                .tint(.blue)
                            
                            HStack {
                                Text("256")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Short")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Long")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("8192")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text("Maximum length of AI-generated responses. Higher values allow longer responses but increase cost.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Model Parameters", systemImage: "slider.horizontal.3")
                } footer: {
                    Text("These settings apply to new chat sessions by default. You can override them per-session in the chat interface.")
                        .font(.caption)
                }

                // MARK: - Cost Management Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        // Daily Budget
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Daily Budget", systemImage: "calendar")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("$\(String(format: "%.2f", dailyBudgetLimit))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                                    .monospacedDigit()
                            }
                            
                            Slider(value: $dailyBudgetLimit, in: 1...50, step: 1)
                                .tint(.green)
                            
                            Text("Maximum amount you can spend per day across all chat sessions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()

                        // Per Session Limit
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Per Session Limit", systemImage: "bubble.left.and.bubble.right")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("$\(String(format: "%.2f", costLimitPerSession))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                                    .monospacedDigit()
                            }
                            
                            Slider(value: $costLimitPerSession, in: 0.1...10, step: 0.1)
                                .tint(.green)
                            
                            Text("Maximum cost for a single chat session before warnings appear.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()

                        // Cost Warnings Toggle
                        Toggle(isOn: $showCostWarnings) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Cost Warnings", systemImage: "exclamationmark.triangle")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Show alerts when approaching budget limits")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(.green)
                        
                        Divider()

                        // Currency Picker
                        HStack {
                            Label("Currency", systemImage: "dollarsign.circle")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Picker("Currency", selection: $currencyCode) {
                                Text("USD").tag("USD")
                                Text("EUR").tag("EUR")
                                Text("GBP").tag("GBP")
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Budget & Spending", systemImage: "dollarsign.circle.fill")
                } footer: {
                    Text("Control your spending with automatic budget tracking. You'll receive warnings when approaching your limits.")
                        .font(.caption)
                }

                // MARK: - Subscription Section
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(subscriptionManager.isSubscribed ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: subscriptionManager.isSubscribed ? "checkmark.seal.fill" : "star.fill")
                                .font(.title3)
                                .foregroundStyle(subscriptionManager.isSubscribed ? .green : .blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Premium Status")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if subscriptionManager.isSubscribed {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                    Text("Active Subscription")
                                        .font(.caption)
                                }
                                .foregroundStyle(.green)
                            } else {
                                Text("Free Plan")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if !subscriptionManager.isSubscribed {
                            Button {
                                showSubscriptionView = true
                            } label: {
                                Text("Upgrade")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)

                    if subscriptionManager.isSubscribed {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Premium Features", systemImage: "sparkles")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                FeatureBullet(text: "Advanced usage analytics and insights")
                                FeatureBullet(text: "Export conversations to PDF & Markdown")
                                FeatureBullet(text: "Custom model ordering and favorites")
                                FeatureBullet(text: "Priority support")
                            }
                        }
                        .padding(.top, 8)
                    }
                } header: {
                    Label("Subscription", systemImage: "crown.fill")
                }

                // MARK: - Data Management Section
                Section {
                    // Clear Chat History
                    Button(action: clearAllData) {
                        HStack(spacing: 12) {
                            Image(systemName: "trash.fill")
                                .font(.body)
                                .foregroundStyle(.red)
                                .frame(width: 32, height: 32)
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clear All Chat History")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text("Permanently delete all conversations")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    // Re-import Models
                    Button(action: reimportModels) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                
                                if isReimporting {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.body)
                                        .foregroundStyle(.blue)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Re-import Models")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text(isReimporting ? "Fetching latest models..." : "Update model catalog from OpenRouter")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if !isReimporting {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isReimporting)
                } header: {
                    Label("Data Management", systemImage: "externaldrive.fill")
                } footer: {
                    Text("Clearing chat history will permanently delete all conversations and usage logs. This action cannot be undone.")
                        .font(.caption)
                }

                // MARK: - About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "app.badge")
                            .font(.subheadline)
                        Spacer()
                        Text("1.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("Models Available", systemImage: "cpu")
                            .font(.subheadline)
                        Spacer()
                        Text("345+")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/dennismayr/openrouter-swiftui-app")!) {
                        HStack {
                            Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Link(destination: URL(string: "https://openrouter.ai")!) {
                        HStack {
                            Label("OpenRouter API", systemImage: "network")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Label("About", systemImage: "info.circle.fill")
                } footer: {
                    Text("Built with SwiftUI, SwiftData, and the OpenRouter API")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
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
            .alert("Success", isPresented: $showAPIKeySuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your API key has been saved securely in the Keychain.")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Helper Properties
    
    @State private var loadedAPIKey = ""
    @State private var apiKeySaveTask: Task<Void, Never>?
    
    // MARK: - Helper Methods
    
    private func loadPreferences() {
        // Load API key from Keychain
        do {
            let key = try KeychainManager.shared.getAPIKey()
            apiKey = key
            loadedAPIKey = key
        } catch {
            apiKey = ""
            loadedAPIKey = ""
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
    
    private func saveAPIKeyDebounced(_ key: String) {
        apiKeySaveTask?.cancel()
        
        apiKeySaveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                do {
                    if key.isEmpty {
                        try KeychainManager.shared.deleteAPIKey()
                    } else {
                        try KeychainManager.shared.saveAPIKey(key)
                        showAPIKeySuccess = true
                        loadedAPIKey = key
                    }
                } catch {
                    errorMessage = "Failed to save API key: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
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
            errorMessage = "Failed to clear data: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func reimportModels() {
        Task {
            isReimporting = true
            defer { isReimporting = false }
            
            do {
                guard let apiKey = try? KeychainManager.shared.getAPIKey() else {
                    await MainActor.run {
                        errorMessage = "API key required for model import. Please add your API key first."
                        showErrorAlert = true
                    }
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
                await MainActor.run {
                    errorMessage = "Failed to re-import models: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct FeatureBullet: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}