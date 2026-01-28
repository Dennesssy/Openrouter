//
//  UserPreferences.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//
import Foundation
import SwiftData

@Model
final class UserPreferences {
    @Attribute(.unique) var id: UUID = UUID()
    var isSubscribedToPremium: Bool = false
    var currencyCode: String = "USD"
    var dailyBudgetLimit: Double?
    var preferredModels: [String] = []
    var excludeModels: [String] = []
    var defaultTemperature: Double = 0.7
    var defaultMaxTokens: Int = 2048
    var costLimitPerSession: Double = 1.0
    var showCostWarnings: Bool = true
    var favoriteModelIds: [String] = []

    init() {
        // Single init leverages property defaults
    }

    // Instance methods (simpler, no closures/captures)
    func isFavoriteModel(_ modelId: String) -> Bool {
        favoriteModelIds.contains(modelId)
    }

    func isPreferredModel(_ modelId: String) -> Bool {
        preferredModels.contains(modelId)
    }

    func isExcludedModel(_ modelId: String) -> Bool {
        excludeModels.contains(modelId)
    }

    var monthlyBudgetLimit: Double? {
        // Convert daily budget to monthly (30 days)
        guard let daily = dailyBudgetLimit else { return nil }
        return daily * 30.0
    }

    // Methods to manage favorites
    func addFavorite(_ modelId: String) {
        if !favoriteModelIds.contains(modelId) {
            favoriteModelIds.append(modelId)
        }
    }

    func removeFavorite(_ modelId: String) {
        favoriteModelIds.removeAll { $0 == modelId }
    }

    func toggleFavorite(_ modelId: String) {
        if isFavoriteModel(modelId) {
            removeFavorite(modelId)
        } else {
            addFavorite(modelId)
        }
    }

    // Methods to manage preferred models
    func addPreferred(_ modelId: String) {
        if !preferredModels.contains(modelId) {
            preferredModels.append(modelId)
        }
    }

    func removePreferred(_ modelId: String) {
        preferredModels.removeAll { $0 == modelId }
    }

    // Methods to manage excluded models
    func addExcluded(_ modelId: String) {
        if !excludeModels.contains(modelId) {
            excludeModels.append(modelId)
        }
    }

    func removeExcluded(_ modelId: String) {
        excludeModels.removeAll { $0 == modelId }
    }
}

