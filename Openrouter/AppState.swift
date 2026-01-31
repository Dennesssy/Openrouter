//
//  AppState.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation
import SwiftData
import Combine
import UserNotifications

class AppState: ObservableObject {
    @Published var isImportingModels = false
    @Published var importProgress: Double = 0.0
    @Published var importError: String?
    @Published var newModelsNotificationShown = false

    // App attribution for OpenRouter API
    let appReferrer: String = "https://github.com/dennismayr/openrouter-swiftui-app"
    let appTitle: String = "OpenRouter SwiftUI App"

    private var modelContainer: ModelContainer?
    private var notificationService = NotificationService.shared

    // Keep reference to background task for cancellation
    private var backgroundRefreshTask: Task<Void, Never>?

    init() {
        // Request notification authorization when app launches
        Task {
            _ = await notificationService.requestAuthorization()
            notificationService.clearBadge()
        }
    }

    func setModelContainer(_ container: ModelContainer) {
        self.modelContainer = container

        // Start background model refresh
        startBackgroundModelRefresh()
    }

    func stopBackgroundRefresh() {
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = nil
    }

    // MARK: - Background Model Refresh

    private func startBackgroundModelRefresh() {
        backgroundRefreshTask = Task {
            // Initial delay to avoid immediate refresh on app launch
            try? await Task.sleep(nanoseconds: 30 * 1_000_000_000) // 30 seconds

            while !Task.isCancelled {
                await performBackgroundModelRefresh()

                // Wait 24 hours before next refresh
                try? await Task.sleep(nanoseconds: 24 * 60 * 60 * 1_000_000_000) // 24 hours
            }
        }
    }

    private func performBackgroundModelRefresh() async {
        guard let container = modelContainer else { return }

        // Get API key
        guard let apiKey = try? KeychainManager.shared.getAPIKey() else {
            print("No API key available for background refresh")
            return
        }

        do {
            let client = OpenRouterClient(
                apiKey: apiKey,
                appReferrer: appReferrer,
                appTitle: appTitle
            )
            let importService = ModelImportService(client: client)
            let newModelNames = try await importService.importModels(into: container.mainContext)

            if !newModelNames.isEmpty {
                print("Background refresh found \(newModelNames.count) new models: \(newModelNames.joined(separator: ", "))")
                // Could show a notification here if desired
            } else {
                print("Background refresh completed - no new models found")
            }
        } catch {
            print("Background model refresh failed: \(error.localizedDescription)")
            // Don't show user error for background refresh failures
        }
    }

    func handleNewModels(_ newModelNames: [String]) {
        guard !newModelNames.isEmpty else { return }

        // Show notification
        notificationService.scheduleNewModelNotification(modelNames: newModelNames)

        // Mark as shown
        newModelsNotificationShown = true
    }
}
