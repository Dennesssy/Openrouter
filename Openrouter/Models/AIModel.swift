//
//  AIModel.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation
import SwiftData

@Model
final class AIModel {
    @Attribute(.unique) var id: String
    var canonicalSlug: String?
    var huggingFaceId: String?
    var name: String
    var created: Date?
    var modelDescription: String  // Renamed from `description`
    var contextLength: Int
    var perRequestLimits: String?
    var supportedParameters: [String]
    var expirationDate: Date?

    // Relationships
    @Relationship var pricing: ModelPricing?
    @Relationship var provider: ModelProvider?
    @Relationship var architecture: ModelArchitecture?
    @Relationship var parameters: ModelParameters?

    init(
        id: String,
        canonicalSlug: String? = nil,
        huggingFaceId: String? = nil,
        name: String,
        created: Date? = nil,
        modelDescription: String,  // Renamed parameter
        contextLength: Int,
        perRequestLimits: String? = nil,
        supportedParameters: [String] = [],
        expirationDate: Date? = nil
    ) {
        self.id = id
        self.canonicalSlug = canonicalSlug
        self.huggingFaceId = huggingFaceId
        self.name = name
        self.created = created
        self.modelDescription = modelDescription  // Renamed assignment
        self.contextLength = contextLength
        self.perRequestLimits = perRequestLimits
        self.supportedParameters = supportedParameters
        self.expirationDate = expirationDate
    }
}
