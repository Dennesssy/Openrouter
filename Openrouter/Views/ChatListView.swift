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
                // Improved empty state
                VStack(spacing: 24) {
                    Spacer()
                    
                    ZStack {
                        Circle()
#if os(iOS)
                            .fill(Color.blue.gradient.opacity(0.1))
#else
                            .fill(Color.blue.opacity(0.1))
#endif
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .symbolRenderingMode(.hierarchical)
                    }

                    VStack(spacing: 8) {
                        Text("No Conversations Yet")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Start chatting with AI models from OpenRouter")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    NavigationLink(destination: ModelBrowserView()) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.body)
                            Text("Start New Chat")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
#if os(iOS)
                        .background(Color.blue.gradient)
#else
                        .background(Color.blue)
#endif
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start new chat")
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
#if os(iOS)
                .background(Color(.systemGroupedBackground))
#else
                .background(Color(NSColor.controlBackgroundColor))
#endif
            } else {
                List(chatSessions) { session in
                    NavigationLink(destination: ChatView(session: session)) {
                        ChatSessionRowView(session: session)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .navigationTitle("Chats")
#if os(iOS)
                .navigationBarTitleDisplayMode(.large)
#endif
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink(destination: ModelBrowserView()) {
                            Label("New Chat", systemImage: "plus.circle.fill")
                                .labelStyle(.iconOnly)
                        }
                        .accessibilityLabel("Start new chat")
                    }
                }
            }
        }
    }
}

struct ChatSessionRowView: View {
    let session: ChatSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title and timestamp
            HStack(alignment: .top, spacing: 8) {
                Text(session.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Text(session.updatedAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize()
            }

            // Model name with icon
            if let model = session.model {
                HStack(spacing: 6) {
                    Image(systemName: "cpu.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(model.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            // Last message preview
            if let lastMessage = session.messages.sorted(by: { $0.timestamp > $1.timestamp }).first {
                Text(lastMessage.content)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            // Metadata (messages and cost)
            HStack(spacing: 12) {
                Label {
                    Text("\(session.messageCount)")
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.caption2)
                }
                .font(.caption)
                .foregroundStyle(.tertiary)

                if session.totalCost > 0 {
                    Label {
                        Text(String(format: "$%.4f", session.totalCost))
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.caption2)
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
                
                if session.totalPromptTokens + session.totalCompletionTokens > 0 {
                    Label {
                        Text("\(session.totalPromptTokens + session.totalCompletionTokens)")
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "number.circle.fill")
                            .font(.caption2)
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
#if os(iOS)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
#else
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
#endif
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}