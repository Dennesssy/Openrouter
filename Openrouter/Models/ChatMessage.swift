//
//  ChatMessage.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import Foundation
import SwiftData

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var role: String // "user", "assistant", "system"
    var content: String
    var timestamp: Date
    var tokenCount: Int
    var cost: Double

    // Inverse relationship
    @Relationship(inverse: \ChatSession.messages) var session: ChatSession?

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        tokenCount: Int = 0,
        cost: Double = 0.0
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.tokenCount = tokenCount
        self.cost = cost
    }

    // Convenience initializers
    static func userMessage(_ content: String) -> ChatMessage {
        ChatMessage(role: "user", content: content)
    }

    static func assistantMessage(_ content: String, tokenCount: Int = 0, cost: Double = 0.0) -> ChatMessage {
        ChatMessage(role: "assistant", content: content, tokenCount: tokenCount, cost: cost)
    }

    static func systemMessage(_ content: String) -> ChatMessage {
        ChatMessage(role: "system", content: content)
    }
}