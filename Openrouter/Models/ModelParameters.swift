//
//  ModelParameters.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation
import SwiftData

@Model
final class ModelParameters {
    var temperature: Double?
    var topP: Double?
    var frequencyPenalty: Double?

    // Inverse relationship
    @Relationship(inverse: \AIModel.parameters) var model: AIModel?

    init(temperature: Double? = nil, topP: Double? = nil, frequencyPenalty: Double? = nil) {
        self.temperature = temperature
        self.topP = topP
        self.frequencyPenalty = frequencyPenalty
    }
}
