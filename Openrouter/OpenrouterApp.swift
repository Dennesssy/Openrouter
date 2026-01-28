//  OpenrouterApp.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import SwiftUI
import SwiftData

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
            let importService = ModelImportService()
            let newModelNames = try await importService.importModels(into: sharedModelContainer.mainContext)

            // Show notification for new models
            if !newModelNames.isEmpty {
                appState.handleNewModels(newModelNames)
            }
        } catch {
            // Propagate error to UI via AppState
            appState.importError = error.localizedDescription
        }
        appState.isImportingModels = false
    }
}
