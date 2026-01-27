//
//  ModelArchitecture.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation
import SwiftData

@Model
final class ModelArchitecture {
    var modality: String
    var inputModalities: [String]
    var outputModalities: [String]
    var tokenizer: String
    var instructType: String?

    // Inverse relationship
    @Relationship(inverse: \AIModel.architecture) var model: AIModel?

    init(
        modality: String,
        inputModalities: [String],
        outputModalities: [String],
        tokenizer: String,
        instructType: String? = nil
    ) {
        self.modality = modality
        self.inputModalities = inputModalities
        self.outputModalities = outputModalities
        self.tokenizer = tokenizer
        self.instructType = instructType
    }
}