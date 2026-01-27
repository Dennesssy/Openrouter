//
//  AppState.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation
import SwiftData
import Combine

class AppState: ObservableObject {
    @Published var isImportingModels = false
    @Published var importProgress: Double = 0.0
    @Published var importError: String?

    private var modelContainer: ModelContainer?

    init() {
        // Model container will be set by the app
    }

    func setModelContainer(_ container: ModelContainer) {
        self.modelContainer = container
    }
}