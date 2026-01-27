//
//  OpenRouterModelDTO.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation

// DTO (Data Transfer Object) for parsing the JSON structure
struct OpenRouterModelDTO: Codable {
    let id: String
    let canonical_slug: String?
    let hugging_face_id: String?
    let name: String
    let created: Int? // Unix timestamp
    let description: String
    let context_length: Int
    let architecture: ArchitectureDTO
    let pricing: PricingDTO
    let top_provider: ProviderDTO
    let per_request_limits: String?
    let supported_parameters: [String]
    let default_parameters: DefaultParametersDTO?
    let expiration_date: String?

    struct ArchitectureDTO: Codable {
        let modality: String
        let input_modalities: [String]
        let output_modalities: [String]
        let tokenizer: String
        let instruct_type: String?
    }

    struct PricingDTO: Codable {
        let prompt: String
        let completion: String
        let input_cache_read: String?
    }

    struct ProviderDTO: Codable {
        let context_length: Int
        let max_completion_tokens: Int
        let is_moderated: Bool
    }

    struct DefaultParametersDTO: Codable {
        let temperature: Double?
        let top_p: Double?
        let frequency_penalty: Double?
    }
}