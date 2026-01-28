import Foundation

// MARK: - Error Types

enum OpenRouterError: LocalizedError {
    case networkError(Error)
    case invalidResponse
    case apiError(code: Int, message: String, metadata: [String: Any]?)
    case decodingError(Error)
    case authenticationError
    case rateLimitError(retryAfter: TimeInterval?)
    case insufficientCredits

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let code, let message, _):
            return "API Error (\(code)): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .authenticationError:
            return "Authentication failed. Please check your API key."
        case .rateLimitError(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limit exceeded. Try again in \(Int(retryAfter)) seconds."
            } else {
                return "Rate limit exceeded. Please try again later."
            }
        case .insufficientCredits:
            return "Insufficient credits. Please add more credits to your account."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .authenticationError:
            return "Go to Settings to update your API key"
        case .insufficientCredits:
            return "Visit https://openrouter.ai/credits to add credits"
        case .rateLimitError:
            return "Wait a moment before retrying, or upgrade your plan"
        default:
            return "Please try again or contact support if the problem persists"
        }
    }
}

class OpenRouterClient {
    private let apiKey: String
    private let baseURL: URL
    private let networkManager: NetworkManager
    private let appReferrer: String?
    private let appTitle: String?

    init(apiKey: String, region: String = "auto", appReferrer: String? = nil, appTitle: String? = nil) {
        self.apiKey = apiKey
        self.appReferrer = appReferrer
        self.appTitle = appTitle
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

    /// Configure a URLRequest with authentication and app attribution headers
    private func configureRequest(_ request: inout URLRequest) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Add app attribution headers for discoverability
        if let referrer = appReferrer {
            request.setValue(referrer, forHTTPHeaderField: "HTTP-Referer")
        }
        if let title = appTitle {
            request.setValue(title, forHTTPHeaderField: "X-Title")
        }
    }

    /// Parse API error response into OpenRouterError
    private func parseAPIError(data: Data, response: URLResponse?) -> OpenRouterError {
        guard let httpResponse = response as? HTTPURLResponse else {
            return .invalidResponse
        }

        // Try to decode the error response
        do {
            let errorResponse = try JSONDecoder().decode(APIErrorResponse.self, from: data)
            return .apiError(
                code: errorResponse.error.code,
                message: errorResponse.error.message,
                metadata: errorResponse.error.metadata
            )
        } catch {
            // Fallback to HTTP status code based errors
            switch httpResponse.statusCode {
            case 401:
                return .authenticationError
            case 402:
                return .insufficientCredits
            case 429:
                return .rateLimitError(retryAfter: nil)
            default:
                return .apiError(
                    code: httpResponse.statusCode,
                    message: "HTTP \(httpResponse.statusCode)",
                    metadata: nil
                )
            }
        }
    }

    // MARK: - API Error Response Structure
    private struct APIErrorResponse: Codable {
        let error: APIError

        struct APIError: Codable {
            let code: Int
            let message: String
            let metadata: [String: String]? // Simplified to string dictionary for common use cases
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

            // OpenRouter-specific detailed usage
            let prompt_tokens_details: PromptTokensDetails?
            let completion_tokens_details: CompletionTokensDetails?
            let cost: Double?
            let is_byok: Bool?
            let cost_details: CostDetails?

            struct PromptTokensDetails: Codable {
                let cached_tokens: Int?
                let cache_write_tokens: Int?
                let audio_tokens: Int?
                let video_tokens: Int?
            }

            struct CompletionTokensDetails: Codable {
                let reasoning_tokens: Int?
                let image_tokens: Int?
            }

            struct CostDetails: Codable {
                let upstream_inference_cost: Double?
                let upstream_inference_input_cost: Double?
                let upstream_inference_output_cost: Double?
            }
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
            let canonical_slug: String?
            let hugging_face_id: String?
            let name: String
            let created: Int?
            let description: String?
            let pricing: ModelPricing?
            let context_length: Int?
            let architecture: ModelArchitecture?
            let top_provider: TopProvider?
            let per_request_limits: String?
            let supported_parameters: [String]?
            let default_parameters: DefaultParameters?
            let expiration_date: String?

            struct ModelPricing: Codable {
                let prompt: String?
                let completion: String?
                let image: String?
                let request: String?
                let input_cache_read: String?
            }

            struct ModelArchitecture: Codable {
                let modality: String?
                let input_modalities: [String]?
                let output_modalities: [String]?
                let tokenizer: String?
                let instruct_type: String?
            }

            struct TopProvider: Codable {
                let context_length: Int?
                let max_completion_tokens: Int?
                let is_moderated: Bool?
            }

            struct DefaultParameters: Codable {
                let temperature: Double?
                let top_p: Double?
                let frequency_penalty: Double?
            }
        }
    }

    func fetchModels() async throws -> [ModelsResponse.ModelInfo] {
        let endpoint = baseURL.appendingPathComponent("models")

        var request = URLRequest(url: endpoint)
        configureRequest(&request)

        do {
            let (data, response) = try await networkManager.performRequest(request)

            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(ModelsResponse.self, from: data)
            return apiResponse.data
        } catch let error as URLError {
            throw OpenRouterError.networkError(error)
        } catch let error as DecodingError {
            throw OpenRouterError.decodingError(error)
        } catch {
            // If it's already an OpenRouterError, rethrow it
            if let openRouterError = error as? OpenRouterError {
                throw openRouterError
            }
            // Otherwise, wrap in network error
            throw OpenRouterError.networkError(error)
        }
    }
}
