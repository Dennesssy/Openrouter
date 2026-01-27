//
//  ChatSession.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation
import SwiftData

@Model
final class ChatSession {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var totalPromptTokens: Int
    var totalCompletionTokens: Int
    var totalCost: Double

    // Relationships
    @Relationship var model: AIModel?
    @Relationship(deleteRule: .cascade) var messages: [ChatMessage]

    init(
        id: UUID = UUID(),
        title: String,
        model: AIModel? = nil,
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.totalPromptTokens = 0
        self.totalCompletionTokens = 0
        self.totalCost = 0.0
        self.model = model
        self.messages = messages
    }

    // Computed properties
    var messageCount: Int {
        messages.count
    }

    var lastMessageDate: Date? {
        messages.last?.timestamp
    }

    // Methods to update session stats
    func addMessage(_ message: ChatMessage) {
        messages.append(message)
        updatedAt = Date()
        updateTokenCounts()
        updateTotalCost()
    }

    private func updateTokenCounts() {
        totalPromptTokens = messages.filter { $0.role == "user" }.reduce(0) { $0 + $1.tokenCount }
        totalCompletionTokens = messages.filter { $0.role == "assistant" }.reduce(0) { $0 + $1.tokenCount }
    }

    private func updateTotalCost() {
        guard let pricing = model?.pricing else {
            totalCost = 0.0
            return
        }

        totalCost = pricing.calculateCost(
            promptTokens: totalPromptTokens,
            completionTokens: totalCompletionTokens
        )
    }
}