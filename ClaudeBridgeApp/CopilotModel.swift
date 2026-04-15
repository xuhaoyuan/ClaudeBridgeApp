import Foundation

struct CopilotModel: Identifiable, Hashable, Codable {
    let id: String
    let ownedBy: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case ownedBy = "owned_by"
        case displayName = "display_name"
    }

    /// Filter out embedding models and internal router models — keep only chat-capable models
    static func filterChatModels(_ models: [CopilotModel]) -> [CopilotModel] {
        models.filter { model in
            !model.id.contains("embedding")
            && !model.id.hasPrefix("accounts/")
        }
    }

    /// Hardcoded fallback when server isn't running yet
    static let defaults: [CopilotModel] = [
        .init(id: "claude-sonnet-4.6", ownedBy: "Anthropic", displayName: "Claude Sonnet 4.6"),
        .init(id: "claude-opus-4.6", ownedBy: "Anthropic", displayName: "Claude Opus 4.6"),
        .init(id: "gpt-5.4", ownedBy: "OpenAI", displayName: "GPT-5.4"),
        .init(id: "gpt-5.3-codex", ownedBy: "OpenAI", displayName: "GPT-5.3-Codex"),
        .init(id: "gpt-4.1", ownedBy: "Azure OpenAI", displayName: "GPT-4.1"),
        .init(id: "gpt-4o", ownedBy: "Azure OpenAI", displayName: "GPT-4o"),
    ]
}

/// JSON wrapper for the /v1/models API response
struct ModelsResponse: Codable {
    let data: [CopilotModel]
}

