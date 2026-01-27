import Foundation

class OpenRouterClient {
    private let apiKey: String
    private let baseURL: URL
    private let networkManager: NetworkManager

    init(apiKey: String, region: String = "auto") {
        self.apiKey = apiKey
        self.networkManager = NetworkManager.shared

        // Determine base URL based on region
        switch region {
        case "us-east":
            self.baseURL = URL(string: "https://us-east.openrouter.ai/api/v1")!
        case "us-west":
            self.baseURL = URL(string: "https://us-west.openrouter.ai/api/v1")!
        case "eu-west":
            self.baseURL = URL(string: "https://eu-west.openrouter.ai/api/v1")!
        case "ap-south":
            self.baseURL = URL(string: "https://ap-south.openrouter.ai/api/v1")!
        default: // "auto" or unknown
            self.baseURL = URL(string: "https://openrouter.ai/api/v1")!
        }
    }

    // MARK: - Chat Completion

    struct ChatRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let max_tokens: Int?
        let temperature: Double?
        let top_p: Double?
        let frequency_penalty: Double?

        struct ChatMessage: Codable {
            let role: String
            let content: String
        }
    }

    struct ChatResponse: Codable {
        let id: String
        let choices: [Choice]
        let usage: Usage

        struct Choice: Codable {
            let message: Message
            let finish_reason: String?
        }

        struct Message: Codable {
            let role: String
            let content: String
        }

        struct Usage: Codable {
            let prompt_tokens: Int
            let completion_tokens: Int
            let total_tokens: Int
        }
    }

    func sendChat(
        model: String,
        messages: [ChatMessage],
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        frequencyPenalty: Double? = nil
    ) async throws -> ChatResponse {
        let endpoint = baseURL.appendingPathComponent("chat/completions")

        let requestMessages = messages.map { message in
            ChatRequest.ChatMessage(role: message.role, content: message.content)
        }

        let requestBody = ChatRequest(
            model: model,
            messages: requestMessages,
            max_tokens: maxTokens,
            temperature: temperature,
            top_p: topP,
            frequency_penalty: frequencyPenalty
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData

        let (data, _) = try await networkManager.performRequest(request)

        let decoder = JSONDecoder()
        return try decoder.decode(ChatResponse.self, from: data)
    }

    // MARK: - Models

    struct ModelsResponse: Codable {
        let data: [ModelInfo]

        struct ModelInfo: Codable {
            let id: String
            let name: String
            let description: String?
            let pricing: ModelPricing?
            let context_length: Int?
            let supported_parameters: [String]?

            struct ModelPricing: Codable {
                let prompt: String?
                let completion: String?
                let image: String?
                let request: String?
            }
        }
    }

    func fetchModels() async throws -> [ModelsResponse.ModelInfo] {
        let endpoint = baseURL.appendingPathComponent("models")

        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await networkManager.performRequest(request)

        let decoder = JSONDecoder()
        let response = try decoder.decode(ModelsResponse.self, from: data)
        return response.data
    }
}
