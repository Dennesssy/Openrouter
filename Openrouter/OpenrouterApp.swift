//
//  OpenrouterApp.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import SwiftUI
import SwiftData

@main
struct OpenrouterApp: App {
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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Import models on first launch
                    do {
                        let importService = ModelImportService()
                        try await importService.importModels(into: sharedModelContainer.mainContext)
                    } catch {
                        print("Failed to import models: \(error)")
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
