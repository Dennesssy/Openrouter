//
//  ChatListView.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import SwiftUI
import SwiftData

struct ChatListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var chatSessions: [ChatSession]

    var body: some View {
        NavigationStack {
            if chatSessions.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "message")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    Text("No chats yet")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text("Start a conversation with an AI model")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    NavigationLink(destination: ModelBrowserView()) {
                        Text("Browse Models")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding()
            } else {
                List(chatSessions) { session in
                    NavigationLink(destination: ChatView(session: session)) {
                        ChatSessionRowView(session: session)
                    }
                }
                .listStyle(.plain)
                .navigationTitle("Chats")
                .toolbar {
                    NavigationLink(destination: ModelBrowserView()) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct ChatSessionRowView: View {
    let session: ChatSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(session.updatedAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let model = session.model {
                Text(model.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 16) {
                Label("\(session.messageCount) messages", systemImage: "message")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if session.totalCost > 0 {
                    Label(String(format: "$%.4f", session.totalCost), systemImage: "dollarsign.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}