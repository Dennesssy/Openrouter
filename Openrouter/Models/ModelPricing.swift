//
//  ModelPricing.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation
import SwiftData

@Model
final class ModelPricing {
    var prompt: Double
    var completion: Double
    var inputCacheRead: Double?

    // Inverse relationship
    @Relationship(inverse: \AIModel.pricing) var model: AIModel?

    init(prompt: Double, completion: Double, inputCacheRead: Double? = nil) {
        self.prompt = prompt
        self.completion = completion
        self.inputCacheRead = inputCacheRead
    }

    // Computed properties for cost calculations
    var promptCostPerToken: Double {
        prompt
    }

    var completionCostPerToken: Double {
        completion
    }

    var cacheReadCostPerToken: Double {
        inputCacheRead ?? 0.0
    }

    // Calculate cost for given token counts
    func calculateCost(promptTokens: Int, completionTokens: Int, cachedTokens: Int = 0) -> Double {
        let promptCost = Double(promptTokens) * promptCostPerToken
        let completionCost = Double(completionTokens) * completionCostPerToken
        let cacheCost = Double(cachedTokens) * cacheReadCostPerToken
        return promptCost + completionCost + cacheCost
    }
}