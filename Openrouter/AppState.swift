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

    private var modelContainer: ModelContainer?
    private let notificationService = NotificationService.shared

    init() {
        // Request notification authorization when app launches
        Task {
            _ = await notificationService.requestAuthorization()
            notificationService.clearBadge()
        }
    }

    func setModelContainer(_ container: ModelContainer) {
        self.modelContainer = container
    }

    func handleNewModels(_ newModelNames: [String]) {
        guard !newModelNames.isEmpty else { return }

        // Show notification
        notificationService.scheduleNewModelNotification(modelNames: newModelNames)

        // Mark as shown
        newModelsNotificationShown = true
    }
}