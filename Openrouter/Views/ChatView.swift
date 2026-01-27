//
//  ChatView.swift
//  Openrouter
//
//  Created by Dennis Stewart Jr. on 1/26/26.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    let session: ChatSession
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]

    @State private var messageText = ""
    @State private var isLoading = false
    @State private var estimatedCost = 0.0
    @State private var showBudgetAlert = false
    @State private var budgetAlertMessage = ""

    private var userPreferences: UserPreferences? {
        preferences.first
    }

    private var sortedMessages: [ChatMessage] {
        session.messages.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Chat Header
            HStack {
                VStack(alignment: .leading) {
                    Text(session.title)
                        .font(.headline)

                    if let model = session.model {
                        Text(model.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(String(format: "$%.4f", session.totalCost))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(session.totalPromptTokens + session.totalCompletionTokens) tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            // Messages List
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(sortedMessages) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: sortedMessages.count) { _ in
                    if let lastMessage = sortedMessages.last {
                        withAnimation {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Cost Estimation
            if !messageText.isEmpty {
                HStack {
                    Text("Estimated cost: \(String(format: "$%.6f", estimatedCost))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            // Input Area
            HStack(alignment: .bottom, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    if messageText.isEmpty {
                        Text("Type your message...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    }

                    TextEditor(text: $messageText)
                        .frame(minHeight: 40, maxHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .onChange(of: messageText) { _ in
                            updateCostEstimation()
                        }
                }

                Button(action: sendMessage) {
                    ZStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                        }
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .frame(width: 32, height: 32)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updateCostEstimation()
        }
        .alert("Budget Alert", isPresented: $showBudgetAlert) {
            Button("OK") {}
            if budgetAlertMessage.contains("exceeds remaining") {
                Button("Use Cheaper Model") {
                    // TODO: Suggest cheaper model
                }
            }
        } message: {
            Text(budgetAlertMessage)
        }
    }

    private func updateCostEstimation() {
        guard let pricing = session.model?.pricing else {
            estimatedCost = 0.0
            return
        }

        // Rough estimation: assume 4 characters per token
        let estimatedTokens = Double(messageText.count) / 4.0
        estimatedCost = pricing.calculateCost(
            promptTokens: Int(estimatedTokens),
            completionTokens: 100 // Rough estimate for response
        )
    }

    private func sendMessage() {
        // Get API key from Keychain
        guard let apiKey = try? KeychainManager.shared.getAPIKey() else {
            // TODO: Show error - no API key, prompt to enter one
            return
        }

        guard let model = session.model else {
            // TODO: Show error - no model selected
            return
        }

        // Check budget limits before sending
        if let dailyBudget = userPreferences?.dailyBudgetLimit {
            let todayLogs = try? modelContext.fetch(
                FetchDescriptor<DailyCostLog>(
                    predicate: #Predicate { $0.date == DailyCostLog.startOfDay() }
                )
            )
            let todaySpent = todayLogs?.first?.totalSpent ?? 0

            if todaySpent >= dailyBudget {
                budgetAlertMessage = "Daily budget exceeded ($\(String(format: "%.2f", todaySpent)) / $\(String(format: "%.2f", dailyBudget))). Please adjust your budget in settings or try again tomorrow."
                showBudgetAlert = true
                return
            }

            // Check if approaching limit
            let remainingBudget = dailyBudget - todaySpent
            if remainingBudget < estimatedCost {
                budgetAlertMessage = "Estimated cost ($\(String(format: "%.4f", estimatedCost))) exceeds remaining daily budget ($\(String(format: "%.2f", remainingBudget))). Consider using a cheaper model."
                showBudgetAlert = true
                return
            }
        }

        let userMessage = ChatMessage.userMessage(messageText)
        session.addMessage(userMessage)

        let messageToSend = messageText
        messageText = ""
        isLoading = true

        Task {
            do {
                let client = OpenRouterClient(apiKey: apiKey)

                // Convert session messages to API format
                let apiMessages = session.messages.map { message in
                    OpenRouterClient.ChatRequest.ChatMessage(
                        role: message.role,
                        content: message.content
                    )
                }

                let response = try await client.sendChat(
                    model: model.id,
                    messages: apiMessages,
                    maxTokens: userPreferences?.defaultMaxTokens,
                    temperature: userPreferences?.defaultTemperature
                )

                // Process the response
                if let choice = response.choices.first {
                    let assistantMessage = ChatMessage(
                        role: "assistant",
                        content: choice.message.content,
                        tokenCount: response.usage.completion_tokens
                    )

                    // Calculate actual cost using API response tokens
                    if let pricing = model.pricing {
                        // Use the actual tokens from the response
                        let promptTokens = response.usage.prompt_tokens
                        let completionTokens = response.usage.completion_tokens

                        assistantMessage.cost = pricing.calculateCost(
                            promptTokens: promptTokens,
                            completionTokens: completionTokens
                        )

                        // Update session totals
                        session.totalPromptTokens += promptTokens
                        session.totalCompletionTokens += completionTokens
                        session.totalCost += assistantMessage.cost
                    }

                    await MainActor.run {
                        session.addMessage(assistantMessage)

                        // Update daily cost log
                        updateDailyCostLog(with: assistantMessage, modelId: model.id)

                        isLoading = false
                        updateCostEstimation()

                        // Check for budget warnings
                        checkBudgetAlerts()
                    }
                }
            } catch {
                await MainActor.run {
                    // TODO: Show error to user
                    print("Error sending message: \(error)")
                    isLoading = false

                    // Add error message to chat
                    let errorMessage = ChatMessage.assistantMessage(
                        "Sorry, I encountered an error: \(error.localizedDescription)",
                        tokenCount: 0,
                        cost: 0.0
                    )
                    session.addMessage(errorMessage)
                }
            }
        }
    }

    private func updateDailyCostLog(with message: ChatMessage, modelId: String) {
        let today = DailyCostLog.startOfDay()

        // Try to fetch existing log for today
        let descriptor = FetchDescriptor<DailyCostLog>(
            predicate: #Predicate { $0.date == today }
        )

        do {
            var dailyLog = try modelContext.fetch(descriptor).first ?? DailyCostLog(date: today)

            dailyLog.addCost(message.cost, forModel: modelId)

            if dailyLog.messageCount == 1 {
                // New log, insert it
                modelContext.insert(dailyLog)
            }

            try modelContext.save()
        } catch {
            print("Error updating daily cost log: \(error)")
        }
    }

    private func checkBudgetAlerts() {
        guard let preferences = userPreferences,
              preferences.showCostWarnings,
              let dailyBudget = preferences.dailyBudgetLimit else {
            return
        }

        let today = DailyCostLog.startOfDay()
        let descriptor = FetchDescriptor<DailyCostLog>(
            predicate: #Predicate { $0.date == today }
        )

        do {
            let todayLog = try modelContext.fetch(descriptor).first
            let todaySpent = todayLog?.totalSpent ?? 0
            let percentage = (todaySpent / dailyBudget) * 100

            if percentage >= 100 {
                budgetAlertMessage = "Daily budget limit reached ($\(String(format: "%.2f", dailyBudget))). Chat disabled until tomorrow or budget adjustment."
                showBudgetAlert = true
            } else if percentage >= 90 {
                let remaining = dailyBudget - todaySpent
                budgetAlertMessage = "Budget warning: \(String(format: "%.1f", percentage))% used. $\(String(format: "%.2f", remaining)) remaining today."
                showBudgetAlert = true
            }
        } catch {
            print("Error checking budget: \(error)")
        }
    }
}

struct MessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            ZStack {
                if message.role == "user" {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "cpu")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                // Role and timestamp
                HStack {
                    Text(message.role.capitalized)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text(message.timestamp, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Message content
                Text(message.content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                // Token count and cost (for assistant messages)
                if message.role == "assistant" && message.tokenCount > 0 {
                    HStack(spacing: 16) {
                        Text("\(message.tokenCount) tokens")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(String(format: "$%.6f", message.cost))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(message.role == "user" ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
    }
}