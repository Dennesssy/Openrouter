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
    @Attribute(.unique) var id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
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

    init(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        isSubscribedToPremium: Bool = false,
        currencyCode: String = "USD",
        dailyBudgetLimit: Double? = nil,
        preferredModels: [String] = [],
        excludeModels: [String] = [],
        defaultTemperature: Double = 0.7,
        defaultMaxTokens: Int = 2048,
        costLimitPerSession: Double = 1.0,
        showCostWarnings: Bool = true,
        favoriteModelIds: [String] = []
    ) {
        self.id = id
        self.isSubscribedToPremium = isSubscribedToPremium
        self.currencyCode = currencyCode
        self.dailyBudgetLimit = dailyBudgetLimit
        self.preferredModels = preferredModels
        self.excludeModels = excludeModels
        self.defaultTemperature = defaultTemperature
        self.defaultMaxTokens = defaultMaxTokens
        self.costLimitPerSession = costLimitPerSession
        self.showCostWarnings = showCostWarnings
        self.favoriteModelIds = favoriteModelIds
    }

    // Computed properties
    var isFavoriteModel: (_ modelId: String) -> Bool {
        { favoriteModelIds.contains($0) }
    }

    var isPreferredModel: (_ modelId: String) -> Bool {
        { preferredModels.contains($0) }
    }

    var isExcludedModel: (_ modelId: String) -> Bool {
        { excludeModels.contains($0) }
    }

    var monthlyBudgetLimit: Double? {
        // Convert daily budget to monthly (30 days)
        guard let daily = dailyBudgetLimit else { return nil }
        return daily * 30.0
    }

    // Methods to manage favorites
    mutating func addFavorite(_ modelId: String) {
        if !favoriteModelIds.contains(modelId) {
            favoriteModelIds.append(modelId)
        }
    }

    mutating func removeFavorite(_ modelId: String) {
        favoriteModelIds.removeAll { $0 == modelId }
    }

    mutating func toggleFavorite(_ modelId: String) {
        if isFavoriteModel(modelId) {
            removeFavorite(modelId)
        } else {
            addFavorite(modelId)
        }
    }

    // Methods to manage preferred models
    mutating func addPreferred(_ modelId: String) {
        if !preferredModels.contains(modelId) {
            preferredModels.append(modelId)
        }
    }

    mutating func removePreferred(_ modelId: String) {
        preferredModels.removeAll { $0 == modelId }
    }

    // Methods to manage excluded models
    mutating func addExcluded(_ modelId: String) {
        if !excludeModels.contains(modelId) {
            excludeModels.append(modelId)
        }
    }

    mutating func removeExcluded(_ modelId: String) {
        excludeModels.removeAll { $0 == modelId }
    }
}