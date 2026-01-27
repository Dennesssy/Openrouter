//
//  ModelProvider.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation
import SwiftData

@Model
final class ModelProvider {
    var contextLength: Int
    var maxCompletionTokens: Int
    var isModerated: Bool

    // Inverse relationship
    @Relationship(inverse: \AIModel.provider) var model: AIModel?

    init(contextLength: Int, maxCompletionTokens: Int, isModerated: Bool) {
        self.contextLength = contextLength
        self.maxCompletionTokens = maxCompletionTokens
        self.isModerated = isModerated
    }
}