//  OpenrouterApp.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import SwiftUI
import SwiftData

// Import services
import OSLog

// Import error types
import Foundation

@main
struct OpenrouterApp: App {
    // Shared model container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AIModel.self,
            ModelPricing.self,
            ModelProvider.self,
            ModelArchitecture.self,
            ModelParameters.self,
            ChatSession.self,
            ChatMessage.self,
            UserPreferences.self,
            DailyCostLog.self,
        ])

        // Configure for CloudKit sync
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // Global app state
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)               // Inject AppState into the environment
                .task {
                    // Provide the model container to AppState (if needed later)
                    appState.setModelContainer(sharedModelContainer)

                    // Perform a one‑time model import
                    await importModelsIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - Model Import Helper

    /// Imports the bundled model catalog. Detects and notifies about new models.
    private func importModelsIfNeeded() async {
        appState.isImportingModels = true
        do {
            // Get API key for model import
            guard let apiKey = try? KeychainManager.shared.getAPIKey() else {
                print("No API key available for model import - skipping")
                appState.importError = "No API key configured. Please set up your API key in Settings."
                appState.isImportingModels = false
                return
            }

            let client = OpenRouterClient(
                apiKey: apiKey,
                appReferrer: appState.appReferrer,
                appTitle: appState.appTitle
            )
            let importService = ModelImportService(client: client)
            let newModelNames = try await importService.importModels(into: sharedModelContainer.mainContext)

            // Show notification for new models
            if !newModelNames.isEmpty {
                appState.handleNewModels(newModelNames)
            }
        } catch let error as OpenRouterError {
            // Handle specific OpenRouter errors with user-friendly messages
            print("Model import failed: \(error)")
            var errorMessage = error.localizedDescription

            if let recoverySuggestion = error.recoverySuggestion {
                errorMessage += "\n\n\(recoverySuggestion)"
            }

            appState.importError = errorMessage
        } catch {
            // Fallback for other errors
            print("Model import failed: \(error)")
            appState.importError = "Failed to import models: \(error.localizedDescription)"
        }
        appState.isImportingModels = false
    }
}
