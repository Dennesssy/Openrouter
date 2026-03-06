import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct ChatView: View {
    let session: ChatSession
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]

    @State private var messageText = ""
    @State private var isLoading = false
    @State private var estimatedCost = 0.0
    @State private var showBudgetAlert = false
    @State private var budgetAlertMessage = ""
    @State private var showErrorAlert = false
    @State private var errorAlertMessage = ""

    private var userPreferences: UserPreferences? {
        preferences.first
    }

    // Cached sorted messages - only re-sorts when message count changes
    private var sortedMessages: [ChatMessage] {
        session.messages.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Chat Header with improved design
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        if let model = session.model {
                            HStack(spacing: 6) {
                                Image(systemName: "cpu.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(model.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "$%.4f", session.totalCost))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "number.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text("\(session.totalPromptTokens + session.totalCompletionTokens)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                            Text("tokens")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
#if os(iOS)
            .background(Color(.systemBackground))
#else
            .background(Color(NSColor.controlBackgroundColor))
#endif

            Divider()

            // Messages List with improved layout
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedMessages) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                        
                        // Typing indicator when loading
                        if isLoading {
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
#if os(iOS)
                                        .fill(Color.green.gradient)
#else
                                        .fill(Color.green)
#endif
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .frame(width: 36, height: 36)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("AI Assistant")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.green)
                                    
                                    HStack(spacing: 6) {
                                        ForEach(0..<3) { index in
                                            Circle()
                                                .fill(Color.secondary)
                                                .frame(width: 8, height: 8)
                                                .opacity(0.6)
                                                .animation(
                                                    Animation.easeInOut(duration: 0.6)
                                                        .repeatForever()
                                                        .delay(Double(index) * 0.2),
                                                    value: isLoading
                                                )
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                            .padding(16)
#if os(iOS)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemGray6))
                            )
#else
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.15))
                            )
#endif
                            .id("loading")
                            .transition(.opacity)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: sortedMessages.count) {
                    if let lastMessage = sortedMessages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isLoading) {
                    if isLoading {
                        withAnimation(.easeOut(duration: 0.3)) {
                            scrollView.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Cost Estimation with improved design
            if !messageText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text("Estimated cost:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(String(format: "$%.6f", estimatedCost))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                        .monospacedDigit()
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
#if os(iOS)
                .background(Color(.systemGray6).opacity(0.5))
#else
                .background(Color.gray.opacity(0.1))
#endif
            }

            // Input Area with improved design
            HStack(alignment: .bottom, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    // Placeholder text
                    if messageText.isEmpty {
                        Text("Message")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .font(.body)
                    }

                    TextEditor(text: $messageText)
                        .frame(minHeight: 44, maxHeight: 120)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .scrollContentBackground(.hidden)
#if os(iOS)
                        .background(Color(.systemGray6))
#else
                        .background(Color(NSColor.textBackgroundColor))
#endif
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: messageText) { _, _ in
                            updateCostEstimation()
                        }
                }

                // Send button with better visual design
                Button(action: sendMessage) {
                    ZStack {
                        let isEmpty = messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        Circle()
#if os(iOS)
                            .fill(isEmpty ? Color.secondary.opacity(0.3) : Color.blue.gradient)
#else
                            .fill(isEmpty ? Color.secondary.opacity(0.3) : Color.blue)
#endif
                            .frame(width: 36, height: 36)
                        
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .accessibilityLabel("Send message")
                .accessibilityHint(messageText.isEmpty ? "Enter a message to send" : "Send your message")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
#if os(iOS)
            .background(Color(.systemBackground))
#else
            .background(Color(NSColor.controlBackgroundColor))
#endif
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onAppear {
            updateCostEstimation()
        }
        .alert("Budget Alert", isPresented: $showBudgetAlert) {
            Button("OK") {}
            if budgetAlertMessage.contains("exceeds remaining") {
                Button("Settings") {
                    // User can adjust budget in Settings
                }
            }
        } message: {
            Text(budgetAlertMessage)
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
            if errorAlertMessage.contains("API key") {
                Button("Open Settings") {
                    // Navigate to settings
                }
            }
        } message: {
            Text(errorAlertMessage)
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
            errorAlertMessage = "No API key found. Please add your OpenRouter API key in Settings to start chatting."
            showErrorAlert = true
            return
        }

        guard let model = session.model else {
            errorAlertMessage = "No model selected. Please select a model for this chat session."
            showErrorAlert = true
            return
        }

        // Check budget limits before sending
        if let dailyBudget = userPreferences?.dailyBudgetLimit {
            let today = DailyCostLog.startOfDay()
            let todayLogs = try? modelContext.fetch(
                FetchDescriptor<DailyCostLog>(
                    predicate: #Predicate { $0.date == today }
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

        // Store message content before clearing
        let currentMessage = messageText
        messageText = ""
        isLoading = true

        Task {
            do {
                let client = OpenRouterClient(
                    apiKey: apiKey,
                    appReferrer: "https://github.com/dennismayr/openrouter-swiftui-app",
                    appTitle: "OpenRouter SwiftUI App"
                )

                let response = try await client.sendChat(
                    model: model.id,
                    messages: session.messages,
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

                    // Use detailed cost information from API response
                    let promptTokens = response.usage.prompt_tokens
                    let completionTokens = response.usage.completion_tokens

                    // Prefer API-provided cost over local calculation
                    if let apiCost = response.usage.cost {
                        assistantMessage.cost = apiCost
                        print("Using API-provided cost: $\(apiCost)")
                    } else if let pricing = model.pricing {
                        // Fallback to local calculation if API doesn't provide cost
                        assistantMessage.cost = pricing.calculateCost(
                            promptTokens: promptTokens,
                            completionTokens: completionTokens
                        )
                        print("Using locally calculated cost: $\(assistantMessage.cost)")
                    }

                    // Update session totals with detailed token breakdown
                    session.totalPromptTokens += promptTokens
                    session.totalCompletionTokens += completionTokens
                    session.totalCost += assistantMessage.cost

                    // Log detailed usage information
                    if let promptDetails = response.usage.prompt_tokens_details {
                        print("Prompt token breakdown - Cached: \(promptDetails.cached_tokens ?? 0), Audio: \(promptDetails.audio_tokens ?? 0), Video: \(promptDetails.video_tokens ?? 0)")
                    }
                    if let completionDetails = response.usage.completion_tokens_details {
                        print("Completion token breakdown - Reasoning: \(completionDetails.reasoning_tokens ?? 0), Images: \(completionDetails.image_tokens ?? 0)")
                    }
                    if let costDetails = response.usage.cost_details {
                        print("Cost breakdown - Input: $\(costDetails.upstream_inference_input_cost ?? 0), Output: $\(costDetails.upstream_inference_output_cost ?? 0)")
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

                    // Restore message text so user can retry
                    messageText = currentMessage

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
            let dailyLog = try modelContext.fetch(descriptor).first ?? DailyCostLog(date: today)

            dailyLog.addCost(message.cost, tokens: message.tokenCount, forModel: modelId)

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
            // Avatar with better visual design
            ZStack {
                Circle()
#if os(iOS)
                    .fill(message.role == "user" ? Color.blue.gradient : Color.green.gradient)
#else
                    .fill(message.role == "user" ? Color.blue : Color.green)
#endif
                    .frame(width: 36, height: 36)
                
                if message.role == "user" {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 36, height: 36)
            .accessibilityLabel(message.role == "user" ? "User message" : "AI response")

            VStack(alignment: .leading, spacing: 8) {
                // Role and timestamp with improved typography
                HStack(spacing: 8) {
                    Text(message.role == "user" ? "You" : "AI Assistant")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(message.role == "user" ? Color.blue : Color.green)

                    Spacer()

                    Text(message.timestamp, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Message content with improved readability
                Text(message.content)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Message: \(message.content)")

                // Token count and cost with better visual design
                if message.role == "assistant" && message.tokenCount > 0 {
                    HStack(spacing: 12) {
                        Label("\(message.tokenCount)", systemImage: "number.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(message.tokenCount) tokens")

                        Label(String(format: "$%.6f", message.cost), systemImage: "dollarsign.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Cost: \(String(format: "$%.6f", message.cost))")
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
#if os(iOS)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(message.role == "user" 
                    ? Color.blue.opacity(0.08) 
                    : Color(.systemGray6))
        )
#else
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(message.role == "user" 
                    ? Color.blue.opacity(0.08) 
                    : Color.gray.opacity(0.15))
        )
#endif
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(message.role == "user" 
                    ? Color.blue.opacity(0.2) 
                    : Color.clear, lineWidth: 1)
        )
    }
}
