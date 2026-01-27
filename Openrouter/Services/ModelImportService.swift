//
//  ModelImportService.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation
import SwiftData

class ModelImportService {
    private let jsonURL = URL(fileURLWithPath: "/Users/denn/Kaggle/openrouter_models.json")

    func importModels(into context: ModelContext) async throws {
        // Check if models are already imported
        let existingCount = try context.fetchCount(FetchDescriptor<AIModel>())
        if existingCount > 0 {
            print("Models already imported (\(existingCount) models)")
            return
        }

        print("Starting model import...")

        // Read JSON data
        let jsonData = try Data(contentsOf: jsonURL)

        // Parse JSON
        let decoder = JSONDecoder()
        let dtos = try decoder.decode([OpenRouterModelDTO].self, from: jsonData)

        print("Found \(dtos.count) models in JSON")

        // Transform and save models
        for dto in dtos {
            let model = try transformDTO(dto)
            context.insert(model)
        }

        try context.save()
        print("Successfully imported \(dtos.count) models")
    }

    private func transformDTO(_ dto: OpenRouterModelDTO) throws -> AIModel {
        // Transform pricing
        let pricing = ModelPricing(
            prompt: Double(dto.pricing.prompt) ?? 0.0,
            completion: Double(dto.pricing.completion) ?? 0.0,
            inputCacheRead: Double(dto.pricing.input_cache_read ?? "0")
        )

        // Transform provider
        let provider = ModelProvider(
            contextLength: dto.top_provider.context_length,
            maxCompletionTokens: dto.top_provider.max_completion_tokens,
            isModerated: dto.top_provider.is_moderated
        )

        // Transform architecture
        let architecture = ModelArchitecture(
            modality: dto.architecture.modality,
            inputModalities: dto.architecture.input_modalities,
            outputModalities: dto.architecture.output_modalities,
            tokenizer: dto.architecture.tokenizer,
            instructType: dto.architecture.instruct_type
        )

        // Transform parameters
        let parameters = ModelParameters(
            temperature: dto.default_parameters?.temperature,
            topP: dto.default_parameters?.top_p,
            frequencyPenalty: dto.default_parameters?.frequency_penalty
        )

        // Convert timestamp
        let createdDate = dto.created.map { Date(timeIntervalSince1970: TimeInterval($0)) }

        // Convert expiration date
        let expirationDate = dto.expiration_date.flatMap { dateString -> Date? in
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: dateString)
        }

        // Create main model
        let model = AIModel(
            id: dto.id,
            canonicalSlug: dto.canonical_slug,
            huggingFaceId: dto.hugging_face_id,
            name: dto.name,
            created: createdDate,
            description: dto.description,
            contextLength: dto.context_length,
            perRequestLimits: dto.per_request_limits,
            supportedParameters: dto.supported_parameters,
            expirationDate: expirationDate
        )

        // Set relationships
        model.pricing = pricing
        model.provider = provider
        model.architecture = architecture
        model.parameters = parameters

        return model
    }
}