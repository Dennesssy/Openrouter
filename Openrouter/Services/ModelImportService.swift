//
//  ModelImportService.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation
import SwiftData

class ModelImportService {
    private let client: OpenRouterClient

    init(client: OpenRouterClient) {
        self.client = client
    }

    func importModels(into context: ModelContext) async throws -> [String] {
        print("Starting model import from OpenRouter API...")

        // Get existing model IDs
        let existingModels = try context.fetch(FetchDescriptor<AIModel>())
        let existingModelIds = Set(existingModels.map { $0.id })
        print("Found \(existingModelIds.count) existing models")

        // Fetch models from OpenRouter API
        let apiModels = try await client.fetchModels()
        print("Fetched \(apiModels.count) models from OpenRouter API")

        // Convert API models to DTOs for processing
        let dtos = apiModels.map { modelInfo in
            OpenRouterModelDTO(
                id: modelInfo.id,
                canonical_slug: modelInfo.canonical_slug,
                hugging_face_id: modelInfo.hugging_face_id,
                name: modelInfo.name,
                created: modelInfo.created,
                description: modelInfo.description ?? "",
                context_length: modelInfo.context_length ?? 4096,
                architecture: OpenRouterModelDTO.ArchitectureDTO(
                    modality: modelInfo.architecture?.modality ?? "text->text",
                    input_modalities: modelInfo.architecture?.input_modalities ?? ["text"],
                    output_modalities: modelInfo.architecture?.output_modalities ?? ["text"],
                    tokenizer: modelInfo.architecture?.tokenizer ?? "GPT",
                    instruct_type: modelInfo.architecture?.instruct_type
                ),
                pricing: OpenRouterModelDTO.PricingDTO(
                    prompt: modelInfo.pricing?.prompt ?? "0.0",
                    completion: modelInfo.pricing?.completion ?? "0.0",
                    input_cache_read: modelInfo.pricing?.input_cache_read?.description ?? "0.0"
                ),
                top_provider: OpenRouterModelDTO.ProviderDTO(
                    context_length: modelInfo.top_provider?.context_length ?? 4096,
                    max_completion_tokens: modelInfo.top_provider?.max_completion_tokens ?? 4096,
                    is_moderated: modelInfo.top_provider?.is_moderated ?? false
                ),
                per_request_limits: modelInfo.per_request_limits,
                supported_parameters: modelInfo.supported_parameters ?? [],
                default_parameters: modelInfo.default_parameters.map { params in
                    OpenRouterModelDTO.DefaultParametersDTO(
                        temperature: params.temperature,
                        top_p: params.top_p,
                        frequency_penalty: params.frequency_penalty
                    )
                },
                expiration_date: modelInfo.expiration_date
            )
        }

        var newModelNames: [String] = []

        // Transform and save models
        for dto in dtos {
            if !existingModelIds.contains(dto.id) {
                let model = try transformDTO(dto)
                context.insert(model)
                newModelNames.append(model.name)
                print("New model: \(model.name)")
            }
        }

        try context.save()
        print("Import complete. \(newModelNames.count) new models added")

        return newModelNames
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
            modelDescription: dto.description,
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