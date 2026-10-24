import Foundation

public enum AIClientError: LocalizedError, Sendable {
    case invalidBaseURL(String)
    case missingAPIKey(String)
    case missingModel
    case httpError(statusCode: Int, message: String)
    case emptyResponse
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let raw):
            return "Invalid AI endpoint URL: '\(raw)'"
        case .missingAPIKey(let provider):
            return "Missing API key for \(provider). Configure your API key in Settings → AI."
        case .missingModel:
            return "Model name cannot be empty. Select or enter a model in Settings → AI."
        case .httpError(let statusCode, let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "AI provider returned HTTP \(statusCode)."
            }
            return "HTTP \(statusCode): \(trimmed)"
        case .emptyResponse:
            return "The AI provider returned an empty response."
        case .networkError(let reason):
            return reason
        }
    }
}

public struct AIWorkspaceContext: Sendable {
    public var workspaceName: String
    public var workingDirectory: String
    public var gitBranch: String?
    public var capsuleName: String?

    public init(
        workspaceName: String,
        workingDirectory: String,
        gitBranch: String? = nil,
        capsuleName: String? = nil
    ) {
        self.workspaceName = workspaceName
        self.workingDirectory = workingDirectory
        self.gitBranch = gitBranch
        self.capsuleName = capsuleName
    }
}

public struct AIClient: Sendable {
    public init() {}

    /// Fetches installed models from an Ollama instance via `GET /api/tags`.
    public func fetchOllamaModels(baseURL: String) async throws -> [String] {
        let normalized = Self.normalizeBaseURL(baseURL, stripSuffixes: ["/api/chat", "/api/tags", "/v1", "/api"])
        guard let url = URL(string: "\(normalized)/api/tags") else {
            throw AIClientError.invalidBaseURL(baseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIClientError.networkError("Could not connect to Ollama at \(normalized): \(error.localizedDescription)")
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIClientError.httpError(statusCode: http.statusCode, message: body)
        }

        struct OllamaTagsResponse: Decodable {
            struct ModelEntry: Decodable {
                let name: String
            }
            let models: [ModelEntry]?
        }

        let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return (decoded.models ?? []).map(\.name)
    }

    /// Sends a chat conversation to the selected AI provider and returns the assistant reply.
    public func sendChat(
        messages: [AIChatMessage],
        settings: AISettings,
        workspaceContext: AIWorkspaceContext? = nil,
        environmentVariables: [String: String] = [:]
    ) async throws -> String {
        let model = settings.activeModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            throw AIClientError.missingModel
        }

        let systemText = Self.composeSystemPrompt(settings: settings, context: workspaceContext)
        let conversation = messages.filter { !$0.isError && ($0.role == .user || $0.role == .assistant) }

        switch settings.selectedProvider {
        case .ollama:
            return try await sendOllamaChat(
                baseURL: settings.ollamaBaseURL,
                model: model,
                systemPrompt: systemText,
                conversation: conversation
            )
        case .openAI:
            let key = Self.resolveAPIKey(
                configuredKey: settings.openAIAPIKey,
                envKeys: ["OPENAI_API_KEY"],
                workspaceEnv: environmentVariables
            )
            guard !key.isEmpty else {
                throw AIClientError.missingAPIKey("OpenAI")
            }
            return try await sendOpenAICompatibleChat(
                baseURL: settings.openAIBaseURL,
                apiKey: key,
                model: model,
                systemPrompt: systemText,
                conversation: conversation
            )
        case .anthropic:
            let key = Self.resolveAPIKey(
                configuredKey: settings.anthropicAPIKey,
                envKeys: ["ANTHROPIC_API_KEY"],
                workspaceEnv: environmentVariables
            )
            guard !key.isEmpty else {
                throw AIClientError.missingAPIKey("Anthropic")
            }
            return try await sendAnthropicChat(
                baseURL: settings.anthropicBaseURL,
                apiKey: key,
                model: model,
                systemPrompt: systemText,
                conversation: conversation
            )
        case .customOpenAICompatible:
            let key = Self.resolveAPIKey(
                configuredKey: settings.customAPIKey,
                envKeys: ["OPENAI_API_KEY", "CUSTOM_AI_API_KEY"],
                workspaceEnv: environmentVariables
            )
            return try await sendOpenAICompatibleChat(
                baseURL: settings.customBaseURL,
                apiKey: key,
                model: model,
                systemPrompt: systemText,
                conversation: conversation
            )
        }
    }

    /// Sends a chat conversation with live token-by-token streaming via `onChunk`, returning the final full reply.
    public func sendStreamingChat(
        messages: [AIChatMessage],
        settings: AISettings,
        workspaceContext: AIWorkspaceContext? = nil,
        environmentVariables: [String: String] = [:],
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        let model = settings.activeModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            throw AIClientError.missingModel
        }

        let systemText = Self.composeSystemPrompt(settings: settings, context: workspaceContext)
        let conversation = messages.filter { !$0.isError && ($0.role == .user || $0.role == .assistant) }

        switch settings.selectedProvider {
        case .ollama:
            return try await streamOllamaChat(
                baseURL: settings.ollamaBaseURL,
                model: model,
                systemPrompt: systemText,
                conversation: conversation,
                onChunk: onChunk
            )
        case .openAI:
            let key = Self.resolveAPIKey(
                configuredKey: settings.openAIAPIKey,
                envKeys: ["OPENAI_API_KEY"],
                workspaceEnv: environmentVariables
            )
            guard !key.isEmpty else {
                throw AIClientError.missingAPIKey("OpenAI")
            }
            return try await streamOpenAICompatibleChat(
                baseURL: settings.openAIBaseURL,
                apiKey: key,
                model: model,
                systemPrompt: systemText,
                conversation: conversation,
                onChunk: onChunk
            )
        case .anthropic:
            let key = Self.resolveAPIKey(
                configuredKey: settings.anthropicAPIKey,
                envKeys: ["ANTHROPIC_API_KEY"],
                workspaceEnv: environmentVariables
            )
            guard !key.isEmpty else {
                throw AIClientError.missingAPIKey("Anthropic")
            }
            return try await streamAnthropicChat(
                baseURL: settings.anthropicBaseURL,
                apiKey: key,
                model: model,
                systemPrompt: systemText,
                conversation: conversation,
                onChunk: onChunk
            )
        case .customOpenAICompatible:
            let key = Self.resolveAPIKey(
                configuredKey: settings.customAPIKey,
                envKeys: ["OPENAI_API_KEY", "CUSTOM_AI_API_KEY"],
                workspaceEnv: environmentVariables
            )
            return try await streamOpenAICompatibleChat(
                baseURL: settings.customBaseURL,
                apiKey: key,
                model: model,
                systemPrompt: systemText,
                conversation: conversation,
                onChunk: onChunk
            )
        }
    }

    /// Translates a natural-language description into a single executable zsh command.
    public func translateNaturalLanguageToCommand(
        prompt: String,
        settings: AISettings,
        workspaceContext: AIWorkspaceContext? = nil,
        environmentVariables: [String: String] = [:]
    ) async throws -> String {
        var inlineSettings = settings
        inlineSettings.systemPrompt = """
        You are an expert macOS zsh shell command generator. Convert the user's natural language request into a single executable zsh command. Output ONLY the raw shell command on a single line (or chained with && / |) with no explanation, no prose, and no markdown fences.
        """
        let msg = AIChatMessage(role: .user, content: prompt)
        let raw = try await sendChat(
            messages: [msg],
            settings: inlineSettings,
            workspaceContext: workspaceContext,
            environmentVariables: environmentVariables
        )
        return Self.extractCleanCommand(from: raw)
    }

    public static func extractCleanCommand(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let regex = try? NSRegularExpression(pattern: "```(?:[a-zA-Z0-9_\\-]+)?\\n([\\s\\S]*?)```"),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)),
           let range = Range(match.range(at: 1), in: trimmed) {
            return String(trimmed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
            .trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Provider Implementations

    private func sendOllamaChat(
        baseURL: String,
        model: String,
        systemPrompt: String,
        conversation: [AIChatMessage]
    ) async throws -> String {
        let normalized = Self.normalizeBaseURL(baseURL, stripSuffixes: ["/api/chat", "/api/tags", "/v1", "/api"])
        guard let url = URL(string: "\(normalized)/api/chat") else {
            throw AIClientError.invalidBaseURL(baseURL)
        }

        struct OllamaMessage: Encodable {
            let role: String
            let content: String
        }
        struct OllamaChatRequest: Encodable {
            let model: String
            let messages: [OllamaMessage]
            let stream: Bool
        }
        struct OllamaChatResponse: Decodable {
            struct Message: Decodable {
                let role: String?
                let content: String?
            }
            let message: Message?
            let error: String?
        }

        var payloadMessages: [OllamaMessage] = []
        if !systemPrompt.isEmpty {
            payloadMessages.append(OllamaMessage(role: "system", content: systemPrompt))
        }
        for msg in conversation {
            payloadMessages.append(OllamaMessage(role: msg.role.rawValue, content: msg.content))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            OllamaChatRequest(model: model, messages: payloadMessages, stream: false)
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIClientError.networkError(
                "Could not connect to Ollama at \(normalized). Make sure Ollama is running (`ollama serve`) and model '\(model)' is pulled (`ollama pull \(model)`)."
            )
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let decodedErr = (try? JSONDecoder().decode(OllamaChatResponse.self, from: data))?.error
            let fallback = String(data: data, encoding: .utf8) ?? ""
            throw AIClientError.httpError(statusCode: http.statusCode, message: decodedErr ?? fallback)
        }

        let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        if let err = decoded.error, !err.isEmpty {
            throw AIClientError.httpError(statusCode: 400, message: err)
        }
        let reply = (decoded.message?.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else {
            throw AIClientError.emptyResponse
        }
        return reply
    }

    private func sendOpenAICompatibleChat(
        baseURL: String,
        apiKey: String,
        model: String,
        systemPrompt: String,
        conversation: [AIChatMessage]
    ) async throws -> String {
        let endpoint = Self.resolveOpenAIChatEndpoint(baseURL)
        guard let url = URL(string: endpoint) else {
            throw AIClientError.invalidBaseURL(baseURL)
        }

        struct OpenAIMessage: Encodable {
            let role: String
            let content: String
        }
        struct OpenAIRequest: Encodable {
            let model: String
            let messages: [OpenAIMessage]
            let stream: Bool
        }
        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String?
                }
                let message: Message?
            }
            struct APIError: Decodable {
                let message: String?
            }
            let choices: [Choice]?
            let error: APIError?
        }

        var payloadMessages: [OpenAIMessage] = []
        if !systemPrompt.isEmpty {
            payloadMessages.append(OpenAIMessage(role: "system", content: systemPrompt))
        }
        for msg in conversation {
            payloadMessages.append(OpenAIMessage(role: msg.role.rawValue, content: msg.content))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(
            OpenAIRequest(model: model, messages: payloadMessages, stream: false)
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIClientError.networkError("Could not reach AI endpoint (\(endpoint)): \(error.localizedDescription)")
        }

        let decoded = try? JSONDecoder().decode(OpenAIResponse.self, from: data)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let apiMsg = decoded?.error?.message ?? String(data: data, encoding: .utf8) ?? ""
            throw AIClientError.httpError(statusCode: http.statusCode, message: apiMsg)
        }

        if let apiError = decoded?.error?.message, !apiError.isEmpty {
            throw AIClientError.httpError(statusCode: 400, message: apiError)
        }

        let reply = (decoded?.choices?.first?.message?.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else {
            throw AIClientError.emptyResponse
        }
        return reply
    }

    private func sendAnthropicChat(
        baseURL: String,
        apiKey: String,
        model: String,
        systemPrompt: String,
        conversation: [AIChatMessage]
    ) async throws -> String {
        let normalized = Self.normalizeBaseURL(baseURL, stripSuffixes: ["/v1/messages", "/messages", "/v1"])
        let endpoint = "\(normalized)/v1/messages"
        guard let url = URL(string: endpoint) else {
            throw AIClientError.invalidBaseURL(baseURL)
        }

        struct AnthropicMessage: Encodable {
            let role: String
            let content: String
        }
        struct AnthropicRequest: Encodable {
            let model: String
            let max_tokens: Int
            let system: String?
            let messages: [AnthropicMessage]
        }
        struct AnthropicResponse: Decodable {
            struct ContentBlock: Decodable {
                let type: String?
                let text: String?
            }
            struct APIError: Decodable {
                let message: String?
            }
            let content: [ContentBlock]?
            let error: APIError?
        }

        let payloadMessages = conversation.map {
            AnthropicMessage(role: $0.role == .assistant ? "assistant" : "user", content: $0.content)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(
            AnthropicRequest(
                model: model,
                max_tokens: 4096,
                system: systemPrompt.isEmpty ? nil : systemPrompt,
                messages: payloadMessages
            )
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIClientError.networkError("Could not reach Anthropic endpoint (\(endpoint)): \(error.localizedDescription)")
        }

        let decoded = try? JSONDecoder().decode(AnthropicResponse.self, from: data)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let apiMsg = decoded?.error?.message ?? String(data: data, encoding: .utf8) ?? ""
            throw AIClientError.httpError(statusCode: http.statusCode, message: apiMsg)
        }

        let reply = (decoded?.content?.compactMap(\.text).joined(separator: "\n") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else {
            throw AIClientError.emptyResponse
        }
        return reply
    }

    // MARK: - Streaming Provider Implementations

    private func streamOllamaChat(
        baseURL: String,
        model: String,
        systemPrompt: String,
        conversation: [AIChatMessage],
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        let normalized = Self.normalizeBaseURL(baseURL, stripSuffixes: ["/api/chat", "/api/tags", "/v1", "/api"])
        guard let url = URL(string: "\(normalized)/api/chat") else {
            throw AIClientError.invalidBaseURL(baseURL)
        }

        struct OllamaMessage: Encodable {
            let role: String
            let content: String
        }
        struct OllamaChatRequest: Encodable {
            let model: String
            let messages: [OllamaMessage]
            let stream: Bool
        }
        struct OllamaStreamChunk: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message?
            let error: String?
        }

        var payloadMessages: [OllamaMessage] = []
        if !systemPrompt.isEmpty {
            payloadMessages.append(OllamaMessage(role: "system", content: systemPrompt))
        }
        for msg in conversation {
            payloadMessages.append(OllamaMessage(role: msg.role.rawValue, content: msg.content))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            OllamaChatRequest(model: model, messages: payloadMessages, stream: true)
        )

        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            return try await sendOllamaChat(
                baseURL: baseURL,
                model: model,
                systemPrompt: systemPrompt,
                conversation: conversation
            )
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return try await sendOllamaChat(
                baseURL: baseURL,
                model: model,
                systemPrompt: systemPrompt,
                conversation: conversation
            )
        }

        var accumulated = ""
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(OllamaStreamChunk.self, from: data) else {
                continue
            }
            if let err = chunk.error, !err.isEmpty {
                throw AIClientError.httpError(statusCode: 400, message: err)
            }
            if let piece = chunk.message?.content, !piece.isEmpty {
                accumulated += piece
                await onChunk(accumulated)
            }
        }

        let finalReply = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalReply.isEmpty {
            return try await sendOllamaChat(
                baseURL: baseURL,
                model: model,
                systemPrompt: systemPrompt,
                conversation: conversation
            )
        }
        return finalReply
    }

    private func streamOpenAICompatibleChat(
        baseURL: String,
        apiKey: String,
        model: String,
        systemPrompt: String,
        conversation: [AIChatMessage],
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        let endpoint = Self.resolveOpenAIChatEndpoint(baseURL)
        guard let url = URL(string: endpoint) else {
            throw AIClientError.invalidBaseURL(baseURL)
        }

        struct OpenAIMessage: Encodable {
            let role: String
            let content: String
        }
        struct OpenAIRequest: Encodable {
            let model: String
            let messages: [OpenAIMessage]
            let stream: Bool
        }
        struct OpenAIStreamChunk: Decodable {
            struct Choice: Decodable {
                struct Delta: Decodable {
                    let content: String?
                }
                let delta: Delta?
            }
            let choices: [Choice]?
        }

        var payloadMessages: [OpenAIMessage] = []
        if !systemPrompt.isEmpty {
            payloadMessages.append(OpenAIMessage(role: "system", content: systemPrompt))
        }
        for msg in conversation {
            payloadMessages.append(OpenAIMessage(role: msg.role.rawValue, content: msg.content))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(
            OpenAIRequest(model: model, messages: payloadMessages, stream: true)
        )

        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            return try await sendOpenAICompatibleChat(
                baseURL: baseURL,
                apiKey: apiKey,
                model: model,
                systemPrompt: systemPrompt,
                conversation: conversation
            )
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return try await sendOpenAICompatibleChat(
                baseURL: baseURL,
                apiKey: apiKey,
                model: model,
                systemPrompt: systemPrompt,
                conversation: conversation
            )
        }

        var accumulated = ""
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data:") else { continue }
            let jsonText = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if jsonText == "[DONE]" { break }
            guard let data = jsonText.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: data),
                  let piece = chunk.choices?.first?.delta?.content,
                  !piece.isEmpty else {
                continue
            }
            accumulated += piece
            await onChunk(accumulated)
        }

        let finalReply = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalReply.isEmpty {
            return try await sendOpenAICompatibleChat(
                baseURL: baseURL,
                apiKey: apiKey,
                model: model,
                systemPrompt: systemPrompt,
                conversation: conversation
            )
        }
        return finalReply
    }

    private func streamAnthropicChat(
        baseURL: String,
        apiKey: String,
        model: String,
        systemPrompt: String,
        conversation: [AIChatMessage],
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        let normalized = Self.normalizeBaseURL(baseURL, stripSuffixes: ["/v1/messages", "/messages", "/v1"])
        let endpoint = "\(normalized)/v1/messages"
        guard let url = URL(string: endpoint) else {
            throw AIClientError.invalidBaseURL(baseURL)
        }

        struct AnthropicMessage: Encodable {
            let role: String
            let content: String
        }
        struct AnthropicStreamRequest: Encodable {
            let model: String
            let max_tokens: Int
            let system: String?
            let messages: [AnthropicMessage]
            let stream: Bool
        }
        struct AnthropicStreamEvent: Decodable {
            struct Delta: Decodable {
                let text: String?
            }
            let type: String?
            let delta: Delta?
        }

        let payloadMessages = conversation.map {
            AnthropicMessage(role: $0.role == .assistant ? "assistant" : "user", content: $0.content)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(
            AnthropicStreamRequest(
                model: model,
                max_tokens: 4096,
                system: systemPrompt.isEmpty ? nil : systemPrompt,
                messages: payloadMessages,
                stream: true
            )
        )

        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            return try await sendAnthropicChat(
                baseURL: baseURL,
                apiKey: apiKey,
                model: model,
                systemPrompt: systemPrompt,
                conversation: conversation
            )
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return try await sendAnthropicChat(
                baseURL: baseURL,
                apiKey: apiKey,
                model: model,
                systemPrompt: systemPrompt,
                conversation: conversation
            )
        }

        var accumulated = ""
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data:") else { continue }
            let jsonText = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            guard let data = jsonText.data(using: .utf8),
                  let event = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: data),
                  let piece = event.delta?.text,
                  !piece.isEmpty else {
                continue
            }
            accumulated += piece
            await onChunk(accumulated)
        }

        let finalReply = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalReply.isEmpty {
            return try await sendAnthropicChat(
                baseURL: baseURL,
                apiKey: apiKey,
                model: model,
                systemPrompt: systemPrompt,
                conversation: conversation
            )
        }
        return finalReply
    }

    // MARK: - Helpers

    public static func normalizeBaseURL(_ raw: String, stripSuffixes: [String] = []) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasSuffix("/") {
            cleaned.removeLast()
        }
        for suffix in stripSuffixes {
            if cleaned.lowercased().hasSuffix(suffix.lowercased()) {
                cleaned = String(cleaned.dropLast(suffix.count))
                while cleaned.hasSuffix("/") {
                    cleaned.removeLast()
                }
            }
        }
        return cleaned
    }

    public static func resolveOpenAIChatEndpoint(_ rawBaseURL: String) -> String {
        let cleaned = normalizeBaseURL(rawBaseURL)
        if cleaned.lowercased().hasSuffix("/chat/completions") {
            return cleaned
        }
        if cleaned.lowercased().hasSuffix("/v1") {
            return "\(cleaned)/chat/completions"
        }
        return "\(cleaned)/v1/chat/completions"
    }

    private static func resolveAPIKey(
        configuredKey: String,
        envKeys: [String],
        workspaceEnv: [String: String]
    ) -> String {
        let trimmed = configuredKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        for key in envKeys {
            if let wsVal = workspaceEnv[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !wsVal.isEmpty {
                return wsVal
            }
            if let procVal = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !procVal.isEmpty {
                return procVal
            }
        }
        return ""
    }

    private static func composeSystemPrompt(settings: AISettings, context: AIWorkspaceContext?) -> String {
        let base = settings.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard settings.includeWorkspaceContext, let context else {
            return base
        }
        var contextLines = [
            "Active Workspace: \(context.workspaceName)",
            "Working Directory: \(context.workingDirectory)"
        ]
        if let branch = context.gitBranch {
            contextLines.append("Git Branch: \(branch)")
        }
        if let capsule = context.capsuleName {
            contextLines.append("Project Manifest: \(capsule)")
        }
        let contextBlock = contextLines.joined(separator: "\n")
        return base.isEmpty ? contextBlock : "\(base)\n\nCurrent Terminal Context:\n\(contextBlock)"
    }
}
