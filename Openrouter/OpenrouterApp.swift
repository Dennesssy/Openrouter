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

    /// Imports the bundled model catalog only once. Subsequent launches skip the import.
    private func importModelsIfNeeded() async {
        // Check UserDefaults flag to avoid duplicate imports
        let hasImported = UserDefaults.standard.bool(forKey: "hasImportedModels")
        guard !hasImported else { return }

        appState.isImportingModels = true
        do {
            let importService = ModelImportService()
            try await importService.importModels(into: sharedModelContainer.mainContext)

            // Mark import as completed
            UserDefaults.standard.set(true, forKey: "hasImportedModels")
        } catch {
            // Propagate error to UI via AppState
            appState.importError = error.localizedDescription
        }
        appState.isImportingModels = false
    }
}
