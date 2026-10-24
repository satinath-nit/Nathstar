import Foundation

public enum SplitAxis: String, Codable, Hashable, Sendable {
    case horizontal
    case vertical
}

public enum SessionStatus: String, Codable, Hashable, Sendable {
    case starting
    case running
    case idle
    case waiting
    case completed
    case disconnected
    case failed
    case terminated
}

public struct TerminalSession: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var workingDirectory: String
    public var status: SessionStatus
    public var createdAt: Date
    public var lastExitCode: Int32?
    public var startupCommand: String?
    public var environment: [String: String]?

    public init(
        id: UUID = UUID(),
        title: String = "Terminal",
        workingDirectory: String,
        status: SessionStatus = .starting,
        createdAt: Date = Date(),
        lastExitCode: Int32? = nil,
        startupCommand: String? = nil,
        environment: [String: String]? = nil
    ) {
        self.id = id
        self.title = title
        self.workingDirectory = workingDirectory
        self.status = status
        self.createdAt = createdAt
        self.lastExitCode = lastExitCode
        self.startupCommand = startupCommand
        self.environment = environment
    }
}

public indirect enum PaneNode: Codable, Hashable, Sendable {
    case terminal(TerminalSession)
    case split(axis: SplitAxis, ratio: Double, first: PaneNode, second: PaneNode)

    public var terminalIDs: [UUID] {
        switch self {
        case .terminal(let session):
            return [session.id]
        case .split(_, _, let first, let second):
            return first.terminalIDs + second.terminalIDs
        }
    }

    public func session(id: UUID) -> TerminalSession? {
        switch self {
        case .terminal(let session):
            return session.id == id ? session : nil
        case .split(_, _, let first, let second):
            return first.session(id: id) ?? second.session(id: id)
        }
    }

    public func replacingSession(id: UUID, transform: (TerminalSession) -> TerminalSession) -> PaneNode {
        switch self {
        case .terminal(let session):
            return session.id == id ? .terminal(transform(session)) : self
        case .split(let axis, let ratio, let first, let second):
            return .split(
                axis: axis,
                ratio: ratio,
                first: first.replacingSession(id: id, transform: transform),
                second: second.replacingSession(id: id, transform: transform)
            )
        }
    }

    public func splitting(sessionID: UUID, axis: SplitAxis, newSession: TerminalSession) -> PaneNode {
        switch self {
        case .terminal(let session) where session.id == sessionID:
            return .split(axis: axis, ratio: 0.5, first: self, second: .terminal(newSession))
        case .terminal:
            return self
        case .split(let existingAxis, let ratio, let first, let second):
            return .split(
                axis: existingAxis,
                ratio: ratio,
                first: first.splitting(sessionID: sessionID, axis: axis, newSession: newSession),
                second: second.splitting(sessionID: sessionID, axis: axis, newSession: newSession)
            )
        }
    }

    public func removing(sessionID: UUID) -> PaneNode? {
        switch self {
        case .terminal(let session):
            return session.id == sessionID ? nil : self
        case .split(let axis, let ratio, let first, let second):
            let updatedFirst = first.removing(sessionID: sessionID)
            let updatedSecond = second.removing(sessionID: sessionID)
            switch (updatedFirst, updatedSecond) {
            case (nil, nil): return nil
            case (let survivor?, nil), (nil, let survivor?): return survivor
            case (let first?, let second?):
                return .split(axis: axis, ratio: ratio, first: first, second: second)
            }
        }
    }

    public func equalizingSplits() -> PaneNode {
        switch self {
        case .terminal:
            return self
        case .split(let axis, _, let first, let second):
            return .split(
                axis: axis,
                ratio: 0.5,
                first: first.equalizingSplits(),
                second: second.equalizingSplits()
            )
        }
    }
}

public struct TerminalTab: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var root: PaneNode
    public var focusedSessionID: UUID

    public init(id: UUID = UUID(), title: String, root: PaneNode, focusedSessionID: UUID) {
        self.id = id
        self.title = title
        self.root = root
        self.focusedSessionID = focusedSessionID
    }
}

public enum WorkspaceCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case projects
    case personal
    case others

    public var defaultTitle: String {
        switch self {
        case .projects: "Projects"
        case .personal: "Personal"
        case .others: "Others"
        }
    }

    public var iconName: String {
        switch self {
        case .projects: "folder.fill.badge.gearshape"
        case .personal: "person.crop.square.fill"
        case .others: "square.grid.2x2.fill"
        }
    }
}

public struct Workspace: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var rootDirectory: String
    public var isPinned: Bool
    public var category: WorkspaceCategory
    public var createdAt: Date
    public var lastOpenedAt: Date
    public var tabs: [TerminalTab]
    public var selectedTabID: UUID
    public var environmentVariables: [String: String]

    private enum CodingKeys: String, CodingKey {
        case id, name, rootDirectory, isPinned, category, createdAt, lastOpenedAt, tabs, selectedTabID, environmentVariables
    }

    public init(
        id: UUID = UUID(),
        name: String,
        rootDirectory: String,
        isPinned: Bool = false,
        category: WorkspaceCategory? = nil,
        createdAt: Date = Date(),
        lastOpenedAt: Date = Date(),
        tabs: [TerminalTab]? = nil,
        selectedTabID: UUID? = nil,
        environmentVariables: [String: String] = [:]
    ) {
        let initialSession = TerminalSession(
            title: name,
            workingDirectory: rootDirectory,
            environment: environmentVariables.isEmpty ? nil : environmentVariables
        )
        let initialTab = TerminalTab(
            title: "Terminal",
            root: .terminal(initialSession),
            focusedSessionID: initialSession.id
        )
        let resolvedTabs = tabs ?? [initialTab]
        self.id = id
        self.name = name
        self.rootDirectory = rootDirectory
        self.isPinned = isPinned
        self.category = category ?? Self.inferredCategory(name: name, rootDirectory: rootDirectory, isPinned: isPinned)
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
        self.tabs = resolvedTabs
        self.selectedTabID = selectedTabID ?? resolvedTabs.first?.id ?? initialTab.id
        self.environmentVariables = environmentVariables
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        rootDirectory = try container.decode(String.self, forKey: .rootDirectory)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        if let decodedCategory = try container.decodeIfPresent(WorkspaceCategory.self, forKey: .category) {
            category = decodedCategory
        } else {
            category = Self.inferredCategory(name: name, rootDirectory: rootDirectory, isPinned: isPinned)
        }
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastOpenedAt = try container.decode(Date.self, forKey: .lastOpenedAt)
        tabs = try container.decode([TerminalTab].self, forKey: .tabs)
        selectedTabID = try container.decode(UUID.self, forKey: .selectedTabID)
        environmentVariables = try container.decodeIfPresent([String: String].self, forKey: .environmentVariables) ?? [:]
    }

    public static func inferredCategory(name: String, rootDirectory: String, isPinned: Bool) -> WorkspaceCategory {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if rootDirectory == home || name.lowercased() == "home" {
            return .others
        }
        if rootDirectory.contains("/Documents/") && !rootDirectory.contains("/Copilot/") {
            return .personal
        }
        return isPinned ? .projects : .projects
    }
}

public enum AttentionKind: String, Codable, Hashable, Sendable {
    case success
    case approval
    case failure
    case disconnected
    case information
}

public struct AttentionItem: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var workspaceID: UUID
    public var sessionID: UUID?
    public var kind: AttentionKind
    public var title: String
    public var detail: String
    public var createdAt: Date
    public var isRead: Bool

    public init(
        id: UUID = UUID(),
        workspaceID: UUID,
        sessionID: UUID? = nil,
        kind: AttentionKind,
        title: String,
        detail: String,
        createdAt: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.sessionID = sessionID
        self.kind = kind
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
        self.isRead = isRead
    }
}

public enum AIProviderKind: String, Codable, CaseIterable, Hashable, Sendable {
    case ollama
    case openAI
    case anthropic
    case customOpenAICompatible

    public var displayName: String {
        switch self {
        case .ollama: "Ollama (Local)"
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic (Claude)"
        case .customOpenAICompatible: "OpenAI-Compatible (LM Studio / Groq / OpenRouter)"
        }
    }

    public var shortName: String {
        switch self {
        case .ollama: "Ollama"
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .customOpenAICompatible: "Custom API"
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .ollama: "http://127.0.0.1:11434"
        case .openAI: "https://api.openai.com/v1"
        case .anthropic: "https://api.anthropic.com/v1"
        case .customOpenAICompatible: "http://127.0.0.1:1234/v1"
        }
    }

    public var defaultModel: String {
        switch self {
        case .ollama: "llama3.2"
        case .openAI: "gpt-4o-mini"
        case .anthropic: "claude-3-5-sonnet-latest"
        case .customOpenAICompatible: "local-model"
        }
    }

    public var requiresAPIKey: Bool {
        switch self {
        case .ollama: false
        case .openAI, .anthropic: true
        case .customOpenAICompatible: false
        }
    }
}

public struct AISettings: Codable, Hashable, Sendable {
    public var selectedProvider: AIProviderKind
    public var ollamaBaseURL: String
    public var ollamaModel: String
    public var openAIBaseURL: String
    public var openAIAPIKey: String
    public var openAIModel: String
    public var anthropicBaseURL: String
    public var anthropicAPIKey: String
    public var anthropicModel: String
    public var customBaseURL: String
    public var customAPIKey: String
    public var customModel: String
    public var systemPrompt: String
    public var includeWorkspaceContext: Bool

    public static let defaultSystemPrompt = """
    You are Nathstar AI, an expert terminal and software engineering assistant built into the Nathstar macOS terminal. Provide concise, accurate answers and shell commands. Wrap executable shell commands in ```zsh or ```sh code blocks so the user can run or insert them directly into their active terminal pane with one click.
    """

    public init(
        selectedProvider: AIProviderKind = .ollama,
        ollamaBaseURL: String = AIProviderKind.ollama.defaultBaseURL,
        ollamaModel: String = AIProviderKind.ollama.defaultModel,
        openAIBaseURL: String = AIProviderKind.openAI.defaultBaseURL,
        openAIAPIKey: String = "",
        openAIModel: String = AIProviderKind.openAI.defaultModel,
        anthropicBaseURL: String = AIProviderKind.anthropic.defaultBaseURL,
        anthropicAPIKey: String = "",
        anthropicModel: String = AIProviderKind.anthropic.defaultModel,
        customBaseURL: String = AIProviderKind.customOpenAICompatible.defaultBaseURL,
        customAPIKey: String = "",
        customModel: String = AIProviderKind.customOpenAICompatible.defaultModel,
        systemPrompt: String = AISettings.defaultSystemPrompt,
        includeWorkspaceContext: Bool = true
    ) {
        self.selectedProvider = selectedProvider
        self.ollamaBaseURL = ollamaBaseURL
        self.ollamaModel = ollamaModel
        self.openAIBaseURL = openAIBaseURL
        self.openAIAPIKey = openAIAPIKey
        self.openAIModel = openAIModel
        self.anthropicBaseURL = anthropicBaseURL
        self.anthropicAPIKey = anthropicAPIKey
        self.anthropicModel = anthropicModel
        self.customBaseURL = customBaseURL
        self.customAPIKey = customAPIKey
        self.customModel = customModel
        self.systemPrompt = systemPrompt
        self.includeWorkspaceContext = includeWorkspaceContext
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedProvider = try container.decodeIfPresent(AIProviderKind.self, forKey: .selectedProvider) ?? .ollama
        ollamaBaseURL = try container.decodeIfPresent(String.self, forKey: .ollamaBaseURL) ?? AIProviderKind.ollama.defaultBaseURL
        ollamaModel = try container.decodeIfPresent(String.self, forKey: .ollamaModel) ?? AIProviderKind.ollama.defaultModel
        openAIBaseURL = try container.decodeIfPresent(String.self, forKey: .openAIBaseURL) ?? AIProviderKind.openAI.defaultBaseURL
        openAIAPIKey = try container.decodeIfPresent(String.self, forKey: .openAIAPIKey) ?? ""
        openAIModel = try container.decodeIfPresent(String.self, forKey: .openAIModel) ?? AIProviderKind.openAI.defaultModel
        anthropicBaseURL = try container.decodeIfPresent(String.self, forKey: .anthropicBaseURL) ?? AIProviderKind.anthropic.defaultBaseURL
        anthropicAPIKey = try container.decodeIfPresent(String.self, forKey: .anthropicAPIKey) ?? ""
        anthropicModel = try container.decodeIfPresent(String.self, forKey: .anthropicModel) ?? AIProviderKind.anthropic.defaultModel
        customBaseURL = try container.decodeIfPresent(String.self, forKey: .customBaseURL) ?? AIProviderKind.customOpenAICompatible.defaultBaseURL
        customAPIKey = try container.decodeIfPresent(String.self, forKey: .customAPIKey) ?? ""
        customModel = try container.decodeIfPresent(String.self, forKey: .customModel) ?? AIProviderKind.customOpenAICompatible.defaultModel
        systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) ?? AISettings.defaultSystemPrompt
        includeWorkspaceContext = try container.decodeIfPresent(Bool.self, forKey: .includeWorkspaceContext) ?? true
    }

    public var activeBaseURL: String {
        get {
            switch selectedProvider {
            case .ollama: ollamaBaseURL
            case .openAI: openAIBaseURL
            case .anthropic: anthropicBaseURL
            case .customOpenAICompatible: customBaseURL
            }
        }
        set {
            switch selectedProvider {
            case .ollama: ollamaBaseURL = newValue
            case .openAI: openAIBaseURL = newValue
            case .anthropic: anthropicBaseURL = newValue
            case .customOpenAICompatible: customBaseURL = newValue
            }
        }
    }

    public var activeModel: String {
        get {
            switch selectedProvider {
            case .ollama: ollamaModel
            case .openAI: openAIModel
            case .anthropic: anthropicModel
            case .customOpenAICompatible: customModel
            }
        }
        set {
            switch selectedProvider {
            case .ollama: ollamaModel = newValue
            case .openAI: openAIModel = newValue
            case .anthropic: anthropicModel = newValue
            case .customOpenAICompatible: customModel = newValue
            }
        }
    }

    public var activeAPIKey: String {
        get {
            switch selectedProvider {
            case .ollama: ""
            case .openAI: openAIAPIKey
            case .anthropic: anthropicAPIKey
            case .customOpenAICompatible: customAPIKey
            }
        }
        set {
            switch selectedProvider {
            case .ollama: break
            case .openAI: openAIAPIKey = newValue
            case .anthropic: anthropicAPIKey = newValue
            case .customOpenAICompatible: customAPIKey = newValue
            }
        }
    }
}

public enum AIChatRole: String, Codable, Hashable, Sendable {
    case system
    case user
    case assistant
}

public struct AIChatMessage: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var role: AIChatRole
    public var content: String
    public var createdAt: Date
    public var modelName: String?
    public var providerName: String?
    public var isError: Bool

    public init(
        id: UUID = UUID(),
        role: AIChatRole,
        content: String,
        createdAt: Date = Date(),
        modelName: String? = nil,
        providerName: String? = nil,
        isError: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.modelName = modelName
        self.providerName = providerName
        self.isError = isError
    }
}

// MARK: - Themes & Cursor Styles

public struct RGBColor: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(hex: UInt32) {
        self.red = Double((hex >> 16) & 0xFF) / 255.0
        self.green = Double((hex >> 8) & 0xFF) / 255.0
        self.blue = Double(hex & 0xFF) / 255.0
    }
}

public struct ThemePalette: Hashable, Sendable {
    public var background: RGBColor
    public var chromeBackground: RGBColor
    public var foreground: RGBColor
    public var caret: RGBColor
    public var selection: RGBColor
    public var ansiColors: [RGBColor] // 16 standard ANSI colors

    public init(
        background: RGBColor,
        chromeBackground: RGBColor,
        foreground: RGBColor,
        caret: RGBColor,
        selection: RGBColor,
        ansiColors: [RGBColor]
    ) {
        self.background = background
        self.chromeBackground = chromeBackground
        self.foreground = foreground
        self.caret = caret
        self.selection = selection
        self.ansiColors = ansiColors
    }
}

public enum TerminalThemePreset: String, Codable, CaseIterable, Hashable, Sendable {
    case nathstarMidnight
    case catppuccinMocha
    case tokyoNight
    case dracula
    case rosePine
    case solarizedDark
    case githubDark
    case nord

    public var displayName: String {
        switch self {
        case .nathstarMidnight: "Nathstar Midnight"
        case .catppuccinMocha: "Catppuccin Mocha"
        case .tokyoNight: "Tokyo Night"
        case .dracula: "Dracula"
        case .rosePine: "Rosé Pine"
        case .solarizedDark: "Solarized Dark"
        case .githubDark: "GitHub Dark"
        case .nord: "Nord"
        }
    }

    public var palette: ThemePalette {
        switch self {
        case .nathstarMidnight:
            return ThemePalette(
                background: RGBColor(hex: 0x090E13),
                chromeBackground: RGBColor(hex: 0x0B1017),
                foreground: RGBColor(hex: 0xE2E8F0),
                caret: RGBColor(hex: 0x22D3EE),
                selection: RGBColor(hex: 0x155E75),
                ansiColors: [
                    0x1E293B, 0xF87171, 0x4ADE80, 0xFACC15, 0x38BDF8, 0xC084FC, 0x22D3EE, 0xE2E8F0,
                    0x475569, 0xFCA5A5, 0x86EFAC, 0xFDE047, 0x7DD3FC, 0xD8B4FE, 0x67E8F9, 0xF8FAFC
                ].map(RGBColor.init(hex:))
            )
        case .catppuccinMocha:
            return ThemePalette(
                background: RGBColor(hex: 0x1E1E2E),
                chromeBackground: RGBColor(hex: 0x181825),
                foreground: RGBColor(hex: 0xCDD6F4),
                caret: RGBColor(hex: 0xF5E0DC),
                selection: RGBColor(hex: 0x45475A),
                ansiColors: [
                    0x45475A, 0xF38BA8, 0xA6E3A1, 0xF9E2AF, 0x89B4FA, 0xF5C2E7, 0x94E2D5, 0xBAC2DE,
                    0x585B70, 0xF38BA8, 0xA6E3A1, 0xF9E2AF, 0x89B4FA, 0xF5C2E7, 0x94E2D5, 0xA6ADC8
                ].map(RGBColor.init(hex:))
            )
        case .tokyoNight:
            return ThemePalette(
                background: RGBColor(hex: 0x1A1B26),
                chromeBackground: RGBColor(hex: 0x16161E),
                foreground: RGBColor(hex: 0xC0CAF5),
                caret: RGBColor(hex: 0x7AA2F7),
                selection: RGBColor(hex: 0x283457),
                ansiColors: [
                    0x15161E, 0xF7768E, 0x9ECE6A, 0xE0AF68, 0x7AA2F7, 0xBB9AF7, 0x7DCFFF, 0xA9B1D6,
                    0x414868, 0xF7768E, 0x9ECE6A, 0xE0AF68, 0x7AA2F7, 0xBB9AF7, 0x7DCFFF, 0xC0CAF5
                ].map(RGBColor.init(hex:))
            )
        case .dracula:
            return ThemePalette(
                background: RGBColor(hex: 0x282A36),
                chromeBackground: RGBColor(hex: 0x21222C),
                foreground: RGBColor(hex: 0xF8F8F2),
                caret: RGBColor(hex: 0xFF79C6),
                selection: RGBColor(hex: 0x44475A),
                ansiColors: [
                    0x21222C, 0xFF5555, 0x50FA7B, 0xF1FA8C, 0xBD93F9, 0xFF79C6, 0x8BE9FD, 0xF8F8F2,
                    0x6272A4, 0xFF6E6E, 0x69FF94, 0xFFFFA5, 0xD6ACFF, 0xFF92DF, 0xA4FFFF, 0xFFFFFF
                ].map(RGBColor.init(hex:))
            )
        case .rosePine:
            return ThemePalette(
                background: RGBColor(hex: 0x191724),
                chromeBackground: RGBColor(hex: 0x1F1D2E),
                foreground: RGBColor(hex: 0xE0DEF4),
                caret: RGBColor(hex: 0xEBBCBA),
                selection: RGBColor(hex: 0x403D52),
                ansiColors: [
                    0x26233A, 0xEB6F92, 0x31748F, 0xF6C177, 0x9CCFD8, 0xC4A7E7, 0xEBBCBA, 0xE0DEF4,
                    0x6E6A86, 0xEB6F92, 0x31748F, 0xF6C177, 0x9CCFD8, 0xC4A7E7, 0xEBBCBA, 0xE0DEF4
                ].map(RGBColor.init(hex:))
            )
        case .solarizedDark:
            return ThemePalette(
                background: RGBColor(hex: 0x002B36),
                chromeBackground: RGBColor(hex: 0x073642),
                foreground: RGBColor(hex: 0x93A1A1),
                caret: RGBColor(hex: 0x2AA198),
                selection: RGBColor(hex: 0x073642),
                ansiColors: [
                    0x073642, 0xDC322F, 0x859900, 0xB58900, 0x268BD2, 0xD33682, 0x2AA198, 0xEEE8D5,
                    0x002B36, 0xCB4B16, 0x586E75, 0x657B83, 0x839496, 0x6C71C4, 0x93A1A1, 0xFDF6E3
                ].map(RGBColor.init(hex:))
            )
        case .githubDark:
            return ThemePalette(
                background: RGBColor(hex: 0x0D1117),
                chromeBackground: RGBColor(hex: 0x161B22),
                foreground: RGBColor(hex: 0xC9D1D9),
                caret: RGBColor(hex: 0x58A6FF),
                selection: RGBColor(hex: 0x1F6FEB),
                ansiColors: [
                    0x484F58, 0xFF7B72, 0x3FB950, 0xD29922, 0x58A6FF, 0xBC8CFF, 0x39C5CF, 0xB1BAC4,
                    0x6E7681, 0xFFA198, 0x56D364, 0xE3B341, 0x79C0FF, 0xD2A8FF, 0x56D4DD, 0xF0F6FC
                ].map(RGBColor.init(hex:))
            )
        case .nord:
            return ThemePalette(
                background: RGBColor(hex: 0x2E3440),
                chromeBackground: RGBColor(hex: 0x242933),
                foreground: RGBColor(hex: 0xD8DEE9),
                caret: RGBColor(hex: 0x88C0D0),
                selection: RGBColor(hex: 0x434C5E),
                ansiColors: [
                    0x3B4252, 0xBF616A, 0xA3BE8C, 0xEBCB8B, 0x81A1C1, 0xB48EAD, 0x88C0D0, 0xE5E9F0,
                    0x4C566A, 0xBF616A, 0xA3BE8C, 0xEBCB8B, 0x81A1C1, 0xB48EAD, 0x8FBCBB, 0xECEFF4
                ].map(RGBColor.init(hex:))
            )
        }
    }
}

public enum TerminalCursorStyle: String, Codable, CaseIterable, Hashable, Sendable {
    case blinkBlock
    case steadyBlock
    case blinkBar
    case steadyBar
    case blinkUnderline
    case steadyUnderline

    public var displayName: String {
        switch self {
        case .blinkBlock: "Blinking Block (█)"
        case .steadyBlock: "Steady Block (█)"
        case .blinkBar: "Blinking Beam (▏)"
        case .steadyBar: "Steady Beam (▏)"
        case .blinkUnderline: "Blinking Underline (▁)"
        case .steadyUnderline: "Steady Underline (▁)"
        }
    }
}

// MARK: - Workflows & Parameterized Snippets

public struct CommandSnippet: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var command: String
    public var category: String
    public var description: String

    public init(
        id: UUID = UUID(),
        title: String,
        command: String,
        category: String = "General",
        description: String = ""
    ) {
        self.id = id
        self.title = title
        self.command = command
        self.category = category
        self.description = description
    }

    /// Returns any `{{parameter}}` placeholders found in `command`.
    public var placeholders: [String] {
        guard let regex = try? NSRegularExpression(pattern: "\\{\\{([a-zA-Z0-9_\\-]+)\\}\\}") else {
            return []
        }
        let nsRange = NSRange(command.startIndex..<command.endIndex, in: command)
        var seen = Set<String>()
        var result: [String] = []
        for match in regex.matches(in: command, range: nsRange) {
            if let range = Range(match.range(at: 1), in: command) {
                let name = String(command[range])
                if seen.insert(name).inserted {
                    result.append(name)
                }
            }
        }
        return result
    }

    public static let defaultSnippets: [CommandSnippet] = [
        CommandSnippet(
            title: "Git Status & Compact Graph",
            command: "git status -sb && git log --oneline --graph --decorate -n 12",
            category: "Git",
            description: "Show working tree status and recent branch topology"
        ),
        CommandSnippet(
            title: "Kill Process on Port",
            command: "lsof -ti tcp:{{port}} | xargs kill -9",
            category: "Networking",
            description: "Find and terminate any process listening on a TCP port"
        ),
        CommandSnippet(
            title: "Inspect Listening TCP Ports",
            command: "lsof -iTCP -sTCP:LISTEN -P -n",
            category: "Networking",
            description: "List all active local servers and their PIDs"
        ),
        CommandSnippet(
            title: "Largest Files in Directory",
            command: "du -sh * .[^.]* 2>/dev/null | sort -hr | head -n 20",
            category: "System",
            description: "Rank top 20 largest files and folders in current directory"
        ),
        CommandSnippet(
            title: "Docker Interactive Shell",
            command: "docker exec -it {{container}} /bin/sh",
            category: "Docker",
            description: "Open an interactive shell inside a running container"
        ),
        CommandSnippet(
            title: "Create & Switch Git Branch",
            command: "git checkout -b {{branch_name}}",
            category: "Git",
            description: "Create a new feature branch and switch to it"
        )
    ]
}

// MARK: - SSH Host Manager & Config Parser

public struct SSHHostEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var alias: String
    public var hostname: String
    public var user: String?
    public var port: Int?
    public var identityFile: String?
    public var isFromSSHConfig: Bool

    public init(
        id: UUID = UUID(),
        alias: String,
        hostname: String,
        user: String? = nil,
        port: Int? = nil,
        identityFile: String? = nil,
        isFromSSHConfig: Bool = false
    ) {
        self.id = id
        self.alias = alias
        self.hostname = hostname
        self.user = user
        self.port = port
        self.identityFile = identityFile
        self.isFromSSHConfig = isFromSSHConfig
    }

    public var sshCommand: String {
        if isFromSSHConfig {
            return "ssh \(alias)"
        }
        var parts = ["ssh"]
        if let port, port != 22 {
            parts.append("-p \(port)")
        }
        if let identityFile, !identityFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("-i \(identityFile)")
        }
        let target: String
        if let user, !user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            target = "\(user)@\(hostname)"
        } else {
            target = hostname
        }
        parts.append(target)
        return parts.joined(separator: " ")
    }

    public var sftpCommand: String {
        if isFromSSHConfig {
            return "sftp \(alias)"
        }
        var parts = ["sftp"]
        if let port, port != 22 {
            parts.append("-P \(port)")
        }
        if let user, !user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("\(user)@\(hostname)")
        } else {
            parts.append(hostname)
        }
        return parts.joined(separator: " ")
    }

    public var displaySubtitle: String {
        var text = hostname
        if let user, !user.isEmpty {
            text = "\(user)@\(text)"
        }
        if let port, port != 22 {
            text += ":\(port)"
        }
        return text
    }
}

public enum SSHConfigParser {
    public static func parseDefaultSSHConfig() -> [SSHHostEntry] {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh", isDirectory: true)
            .appendingPathComponent("config", isDirectory: false)
        guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else {
            return []
        }
        return parse(contents: contents)
    }

    public static func parse(contents: String) -> [SSHHostEntry] {
        var entries: [SSHHostEntry] = []
        var currentAliases: [String] = []
        var currentHostname: String?
        var currentUser: String?
        var currentPort: Int?
        var currentIdentity: String?

        func flushCurrent() {
            for alias in currentAliases where !alias.contains("*") && !alias.contains("?") {
                entries.append(
                    SSHHostEntry(
                        alias: alias,
                        hostname: currentHostname ?? alias,
                        user: currentUser,
                        port: currentPort,
                        identityFile: currentIdentity,
                        isFromSSHConfig: true
                    )
                )
            }
            currentAliases = []
            currentHostname = nil
            currentUser = nil
            currentPort = nil
            currentIdentity = nil
        }

        for rawLine in contents.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" || $0 == "=" })
            guard parts.count == 2 else { continue }
            let key = parts[0].lowercased()
            let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            switch key {
            case "host":
                flushCurrent()
                currentAliases = value.split(whereSeparator: \.isWhitespace).map(String.init)
            case "hostname":
                currentHostname = value
            case "user":
                currentUser = value
            case "port":
                currentPort = Int(value)
            case "identityfile":
                currentIdentity = value
            default:
                break
            }
        }
        flushCurrent()
        return entries
    }
}

// MARK: - Terminal Buffer Search & Quick Link/Path Detection

public enum DetectedItemKind: String, Codable, Hashable, Sendable {
    case url
    case filePath
    case endpoint
}

public struct DetectedTerminalItem: Identifiable, Hashable, Sendable {
    public var id: String { "\(kind.rawValue):\(value):\(line ?? 0)" }
    public var kind: DetectedItemKind
    public var displayText: String
    public var value: String
    public var line: Int?
    public var column: Int?

    public init(kind: DetectedItemKind, displayText: String, value: String, line: Int? = nil, column: Int? = nil) {
        self.kind = kind
        self.displayText = displayText
        self.value = value
        self.line = line
        self.column = column
    }
}

public struct TerminalSearchMatch: Identifiable, Hashable, Sendable {
    public var id: String { "\(lineNumber):\(lineText)" }
    public var lineNumber: Int
    public var lineText: String
    public var matchedSubstring: String

    public init(lineNumber: Int, lineText: String, matchedSubstring: String) {
        self.lineNumber = lineNumber
        self.lineText = lineText
        self.matchedSubstring = matchedSubstring
    }
}

public struct FailedCommandEvent: Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var sessionID: UUID
    public var command: String
    public var exitCode: Int32
    public var durationMs: Int
    public var timestamp: Date

    public init(
        sessionID: UUID,
        command: String,
        exitCode: Int32,
        durationMs: Int = 0,
        timestamp: Date = Date()
    ) {
        self.sessionID = sessionID
        self.command = command
        self.exitCode = exitCode
        self.durationMs = durationMs
        self.timestamp = timestamp
    }
}

// MARK: - Command Blocks & Autocomplete Engine

public struct CommandBlock: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var sessionID: UUID
    public var workspaceID: UUID
    public var command: String
    public var workingDirectory: String
    public var exitCode: Int32
    public var durationMs: Int
    public var outputSnippet: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        workspaceID: UUID,
        command: String,
        workingDirectory: String,
        exitCode: Int32,
        durationMs: Int,
        outputSnippet: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.workspaceID = workspaceID
        self.command = command
        self.workingDirectory = workingDirectory
        self.exitCode = exitCode
        self.durationMs = durationMs
        self.outputSnippet = outputSnippet
        self.createdAt = createdAt
    }

    public var isSuccess: Bool {
        exitCode == 0
    }

    public var formattedDuration: String {
        if durationMs < 1000 {
            return "\(max(1, durationMs))ms"
        }
        let seconds = Double(durationMs) / 1000.0
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        }
        let mins = Int(seconds) / 60
        let remSecs = Int(seconds) % 60
        return "\(mins)m \(remSecs)s"
    }
}

public enum AutocompleteSuggestionKind: String, Codable, Hashable, Sendable {
    case history
    case filePath
    case gitBranch
    case snippet

    public var iconName: String {
        switch self {
        case .history: "clock.arrow.circlepath"
        case .filePath: "folder.fill"
        case .gitBranch: "arrow.triangle.branch"
        case .snippet: "text.book.closed.fill"
        }
    }

    public var badgeTitle: String {
        switch self {
        case .history: "history"
        case .filePath: "path"
        case .gitBranch: "branch"
        case .snippet: "snippet"
        }
    }
}

public struct AutocompleteSuggestion: Identifiable, Hashable, Sendable {
    public var id: String { "\(kind.rawValue):\(replacementCommand)" }
    public var kind: AutocompleteSuggestionKind
    public var displayLabel: String
    public var subtitle: String
    public var replacementCommand: String

    public init(
        kind: AutocompleteSuggestionKind,
        displayLabel: String,
        subtitle: String,
        replacementCommand: String
    ) {
        self.kind = kind
        self.displayLabel = displayLabel
        self.subtitle = subtitle
        self.replacementCommand = replacementCommand
    }
}

public enum AutocompleteEngine {
    public static func suggest(
        for input: String,
        workingDirectory: String,
        commandBlocks: [CommandBlock],
        snippets: [CommandSnippet],
        shellHistory: [String] = [],
        maxResults: Int = 6
    ) -> [AutocompleteSuggestion] {
        let trimmedLeading = input.drop(while: \.isWhitespace)
        guard !trimmedLeading.isEmpty else { return [] }
        let rawInput = String(trimmedLeading)
        let lowerInput = rawInput.lowercased()

        var results: [AutocompleteSuggestion] = []
        var seenCommands = Set<String>()

        func appendUnique(_ suggestion: AutocompleteSuggestion) {
            guard suggestion.replacementCommand.lowercased() != lowerInput else { return }
            if seenCommands.insert(suggestion.replacementCommand).inserted {
                results.append(suggestion)
            }
        }

        // 1. Git branch completion when typing git checkout / switch / merge / rebase
        let gitBranchPrefixes = [
            "git checkout ", "git switch ", "git merge ", "git rebase ",
            "git branch -d ", "git branch -D ", "git push origin ", "git pull origin "
        ]
        if let matchedPrefix = gitBranchPrefixes.first(where: { lowerInput.hasPrefix($0.lowercased()) }) {
            let prefixText = String(rawInput.prefix(matchedPrefix.count))
            let partialBranch = String(rawInput.dropFirst(matchedPrefix.count)).trimmingCharacters(in: .whitespaces)
            let branches = listGitBranches(at: workingDirectory)
            for branch in branches where partialBranch.isEmpty || branch.localizedCaseInsensitiveContains(partialBranch) {
                appendUnique(
                    AutocompleteSuggestion(
                        kind: .gitBranch,
                        displayLabel: branch,
                        subtitle: "Git branch",
                        replacementCommand: prefixText + branch
                    )
                )
            }
        }

        // 2. Recent Command Blocks history
        for block in commandBlocks {
            let cmd = block.command.trimmingCharacters(in: .whitespacesAndNewlines)
            if cmd.lowercased().hasPrefix(lowerInput) || cmd.localizedCaseInsensitiveContains(rawInput) {
                appendUnique(
                    AutocompleteSuggestion(
                        kind: .history,
                        displayLabel: cmd,
                        subtitle: "\(block.formattedDuration) · exit \(block.exitCode)",
                        replacementCommand: cmd
                    )
                )
            }
            if results.count >= maxResults { break }
        }

        // 3. Snippets
        for snippet in snippets {
            if snippet.command.lowercased().hasPrefix(lowerInput)
                || snippet.title.localizedCaseInsensitiveContains(rawInput) {
                appendUnique(
                    AutocompleteSuggestion(
                        kind: .snippet,
                        displayLabel: snippet.command,
                        subtitle: snippet.title,
                        replacementCommand: snippet.command
                    )
                )
            }
        }

        // 4. Shell history (~/.zsh_history)
        for histCmd in shellHistory {
            if histCmd.lowercased().hasPrefix(lowerInput) {
                appendUnique(
                    AutocompleteSuggestion(
                        kind: .history,
                        displayLabel: histCmd,
                        subtitle: "zsh history",
                        replacementCommand: histCmd
                    )
                )
            }
            if results.count >= maxResults { break }
        }

        // 5. File / directory path completion for the active trailing token
        if let pathSuggestions = completeTrailingPathToken(rawInput: rawInput, workingDirectory: workingDirectory) {
            for item in pathSuggestions {
                appendUnique(item)
            }
        }

        return Array(results.prefix(maxResults))
    }

    public static func loadRecentZshHistory(maxCount: Int = 250) -> [String] {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zsh_history")
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return []
        }
        var seen = Set<String>()
        var commands: [String] = []
        for rawLine in content.components(separatedBy: .newlines).reversed() {
            var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            // Strip zsh extended_history prefix `: 1700000000:0;cmd`
            if line.hasPrefix(": "), let semiIndex = line.firstIndex(of: ";") {
                line = String(line[line.index(after: semiIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard line.count >= 3, !line.hasPrefix("#") else { continue }
            if seen.insert(line).inserted {
                commands.append(line)
                if commands.count >= maxCount { break }
            }
        }
        return commands
    }

    private static func listGitBranches(at workingDirectory: String) -> [String] {
        let headsURL = URL(fileURLWithPath: workingDirectory)
            .appendingPathComponent(".git/refs/heads", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: headsURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var branches: [String] = []
        let basePrefix = headsURL.standardizedFileURL.path + "/"
        for case let fileURL as URL in enumerator {
            let stdPath = fileURL.standardizedFileURL.path
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: stdPath, isDirectory: &isDir), !isDir.boolValue {
                if stdPath.hasPrefix(basePrefix) {
                    branches.append(String(stdPath.dropFirst(basePrefix.count)))
                }
            }
        }
        return branches.sorted()
    }

    private static func completeTrailingPathToken(
        rawInput: String,
        workingDirectory: String
    ) -> [AutocompleteSuggestion]? {
        let hasTrailingSpace = rawInput.last?.isWhitespace == true
        let parts = rawInput.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let firstWord = parts.first?.lowercased() else { return nil }

        let pathCommands: Set<String> = [
            "cd", "ls", "cat", "less", "head", "tail", "open", "code", "vim", "nvim", "nano",
            "rm", "cp", "mv", "mkdir", "touch", "chmod", "chown", "stat", "file", "du",
            "swift", "python", "python3", "node", "bun", "deno", "sh", "zsh", "bash", "source", "git"
        ]

        let token: String
        let prefixBeforeToken: String
        if hasTrailingSpace {
            guard pathCommands.contains(firstWord) else { return nil }
            token = ""
            prefixBeforeToken = rawInput
        } else if parts.count >= 2 {
            let lastToken = parts.last!
            let looksLikePath = lastToken.contains("/") || lastToken.hasPrefix(".") || lastToken.hasPrefix("~") || pathCommands.contains(firstWord)
            guard looksLikePath else { return nil }
            token = lastToken
            prefixBeforeToken = String(rawInput.dropLast(lastToken.count))
        } else if rawInput.hasPrefix("./") || rawInput.hasPrefix("../") || rawInput.hasPrefix("/") || rawInput.hasPrefix("~/") {
            token = rawInput
            prefixBeforeToken = ""
        } else {
            return nil
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let expandedToken: String
        if token.hasPrefix("~/") {
            expandedToken = home + String(token.dropFirst(1))
        } else {
            expandedToken = token
        }

        let searchDirURL: URL
        let typedDirectoryPrefix: String
        let partialName: String

        if expandedToken.hasSuffix("/") {
            searchDirURL = expandedToken.hasPrefix("/")
                ? URL(fileURLWithPath: expandedToken, isDirectory: true)
                : URL(fileURLWithPath: workingDirectory, isDirectory: true).appendingPathComponent(expandedToken, isDirectory: true)
            typedDirectoryPrefix = token
            partialName = ""
        } else if let slashIdx = token.lastIndex(of: "/") {
            let dirPart = String(token[...slashIdx])
            let expandedDirPart = dirPart.hasPrefix("~/")
                ? home + String(dirPart.dropFirst(1))
                : dirPart
            searchDirURL = expandedDirPart.hasPrefix("/")
                ? URL(fileURLWithPath: expandedDirPart, isDirectory: true)
                : URL(fileURLWithPath: workingDirectory, isDirectory: true).appendingPathComponent(expandedDirPart, isDirectory: true)
            typedDirectoryPrefix = dirPart
            partialName = String(token[token.index(after: slashIdx)...])
        } else {
            searchDirURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
            typedDirectoryPrefix = ""
            partialName = token
        }

        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: searchDirURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: partialName.hasPrefix(".") ? [] : [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var suggestions: [AutocompleteSuggestion] = []
        for entry in entries.sorted(by: { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }) {
            let name = entry.lastPathComponent
            guard partialName.isEmpty || name.lowercased().hasPrefix(partialName.lowercased()) else { continue }
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let escapedName = name.replacingOccurrences(of: " ", with: "\\ ")
            let completedToken = typedDirectoryPrefix + escapedName + (isDir ? "/" : "")
            let fullCommand = prefixBeforeToken + completedToken
            suggestions.append(
                AutocompleteSuggestion(
                    kind: .filePath,
                    displayLabel: name + (isDir ? "/" : ""),
                    subtitle: isDir ? "Folder" : "File",
                    replacementCommand: fullCommand
                )
            )
            if suggestions.count >= 5 { break }
        }
        return suggestions
    }
}

public enum TerminalBufferScanner {
    public static func search(
        bufferText: String,
        query: String,
        caseSensitive: Bool = false,
        useRegex: Bool = false
    ) -> [TerminalSearchMatch] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lines = bufferText.components(separatedBy: .newlines)
        var results: [TerminalSearchMatch] = []

        if useRegex {
            var options: NSRegularExpression.Options = []
            if !caseSensitive {
                options.insert(.caseInsensitive)
            }
            guard let regex = try? NSRegularExpression(pattern: trimmed, options: options) else {
                return []
            }
            for (index, line) in lines.enumerated() {
                let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                if let match = regex.firstMatch(in: line, range: nsRange),
                   let swiftRange = Range(match.range, in: line) {
                    results.append(
                        TerminalSearchMatch(
                            lineNumber: index + 1,
                            lineText: line.trimmingCharacters(in: .whitespaces),
                            matchedSubstring: String(line[swiftRange])
                        )
                    )
                }
            }
        } else {
            let compareOptions: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
            for (index, line) in lines.enumerated() {
                if let range = line.range(of: trimmed, options: compareOptions) {
                    results.append(
                        TerminalSearchMatch(
                            lineNumber: index + 1,
                            lineText: line.trimmingCharacters(in: .whitespaces),
                            matchedSubstring: String(line[range])
                        )
                    )
                }
            }
        }
        return results
    }

    public static func detectItems(in bufferText: String, workingDirectory: String) -> [DetectedTerminalItem] {
        var items: [DetectedTerminalItem] = []
        var seen = Set<String>()

        // 1. URLs (http/https)
        if let urlRegex = try? NSRegularExpression(pattern: "https?://[^\\s\"'<>\\)\\]]+") {
            let nsRange = NSRange(bufferText.startIndex..<bufferText.endIndex, in: bufferText)
            for match in urlRegex.matches(in: bufferText, range: nsRange).reversed() {
                guard let range = Range(match.range, in: bufferText) else { continue }
                var rawURL = String(bufferText[range])
                while let last = rawURL.last, ".,;:!)".contains(last) {
                    rawURL.removeLast()
                }
                if seen.insert("url:\(rawURL)").inserted {
                    items.append(DetectedTerminalItem(kind: .url, displayText: rawURL, value: rawURL))
                }
            }
        }

        // 2. Localhost / IP:port endpoints
        if let endpointRegex = try? NSRegularExpression(pattern: "\\b(?:localhost|127\\.0\\.0\\.1|0\\.0\\.0\\.0):(\\d{2,5})\\b") {
            let nsRange = NSRange(bufferText.startIndex..<bufferText.endIndex, in: bufferText)
            for match in endpointRegex.matches(in: bufferText, range: nsRange).reversed() {
                guard let range = Range(match.range, in: bufferText) else { continue }
                let hostPort = String(bufferText[range])
                let fullURL = "http://\(hostPort)"
                if seen.insert("url:\(fullURL)").inserted {
                    items.append(DetectedTerminalItem(kind: .endpoint, displayText: hostPort, value: fullURL))
                }
            }
        }

        // 3. File paths with optional :line(:col)
        if let pathRegex = try? NSRegularExpression(pattern: "(?:~|/|\\./|[A-Za-z0-9_\\-]+/)[A-Za-z0-9_\\-./]+\\.[A-Za-z0-9]{1,8}(?::(\\d+))?(?::(\\d+))?") {
            let nsRange = NSRange(bufferText.startIndex..<bufferText.endIndex, in: bufferText)
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            for match in pathRegex.matches(in: bufferText, range: nsRange).reversed() {
                guard let fullRange = Range(match.range, in: bufferText) else { continue }
                let token = String(bufferText[fullRange])
                guard !token.hasPrefix("http://") && !token.hasPrefix("https://") && !token.hasPrefix("//") else { continue }

                let parts = token.split(separator: ":")
                guard let rawPathPart = parts.first.map(String.init) else { continue }
                let lineNum = parts.count > 1 ? Int(parts[1]) : nil
                let colNum = parts.count > 2 ? Int(parts[2]) : nil

                let resolvedPath: String
                if rawPathPart.hasPrefix("~/") {
                    resolvedPath = home + String(rawPathPart.dropFirst(1))
                } else if rawPathPart.hasPrefix("/") {
                    resolvedPath = rawPathPart
                } else {
                    resolvedPath = URL(fileURLWithPath: workingDirectory)
                        .appendingPathComponent(rawPathPart)
                        .standardizedFileURL.path
                }

                if FileManager.default.fileExists(atPath: resolvedPath),
                   seen.insert("file:\(resolvedPath):\(lineNum ?? 0)").inserted {
                    items.append(
                        DetectedTerminalItem(
                            kind: .filePath,
                            displayText: token,
                            value: resolvedPath,
                            line: lineNum,
                            column: colNum
                        )
                    )
                }
            }
        }

        return Array(items.prefix(30))
    }
}

// MARK: - Live Port & Process Scanner

public struct TerminalShellSessionInfo: Hashable, Sendable {
    public var sessionID: UUID
    public var sessionTitle: String
    public var workspaceID: UUID
    public var workspaceName: String
    public var shellPID: Int32

    public init(
        sessionID: UUID,
        sessionTitle: String,
        workspaceID: UUID,
        workspaceName: String,
        shellPID: Int32
    ) {
        self.sessionID = sessionID
        self.sessionTitle = sessionTitle
        self.workspaceID = workspaceID
        self.workspaceName = workspaceName
        self.shellPID = shellPID
    }
}

public struct LivePortProcess: Identifiable, Hashable, Sendable {
    public var id: String { "\(pid):\(port ?? 0)" }
    public var pid: Int32
    public var ppid: Int32
    public var processName: String
    public var commandLine: String
    public var port: Int?
    public var bindAddress: String?
    public var sessionID: UUID?
    public var sessionTitle: String?
    public var workspaceID: UUID?
    public var workspaceName: String?

    public init(
        pid: Int32,
        ppid: Int32 = 0,
        processName: String,
        commandLine: String,
        port: Int? = nil,
        bindAddress: String? = nil,
        sessionID: UUID? = nil,
        sessionTitle: String? = nil,
        workspaceID: UUID? = nil,
        workspaceName: String? = nil
    ) {
        self.pid = pid
        self.ppid = ppid
        self.processName = processName
        self.commandLine = commandLine
        self.port = port
        self.bindAddress = bindAddress
        self.sessionID = sessionID
        self.sessionTitle = sessionTitle
        self.workspaceID = workspaceID
        self.workspaceName = workspaceName
    }

    public var isFromNathstarTerminal: Bool {
        sessionID != nil
    }

    public var browserURL: URL? {
        guard let port else { return nil }
        return URL(string: "http://localhost:\(port)")
    }
}

public enum LivePortScanner {
    public struct ProcessRecord: Sendable {
        public var pid: Int32
        public var ppid: Int32
        public var comm: String
        public var args: String
    }

    public struct LsofPortRecord: Sendable, Equatable {
        public var pid: Int32
        public var command: String
        public var address: String
        public var port: Int
    }

    /// Parses output of `ps -axo pid=,ppid=,comm=,args=`
    public static func parsePSOutput(_ output: String) -> [Int32: ProcessRecord] {
        var map: [Int32: ProcessRecord] = [:]
        for rawLine in output.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(maxSplits: 3, whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 3,
                  let pid = Int32(parts[0]),
                  let ppid = Int32(parts[1]) else { continue }
            let commPath = parts[2]
            let commName = URL(fileURLWithPath: commPath).lastPathComponent
            let args = parts.count >= 4 ? parts[3] : commName
            map[pid] = ProcessRecord(
                pid: pid,
                ppid: ppid,
                comm: commName.isEmpty ? commPath : commName,
                args: args
            )
        }
        return map
    }

    /// Parses output of `lsof -iTCP -sTCP:LISTEN -P -n -F pcn`
    public static func parseLsofMachineOutput(_ output: String) -> [LsofPortRecord] {
        var results: [LsofPortRecord] = []
        var seen = Set<String>()
        var currentPID: Int32?
        var currentCommand = ""

        for rawLine in output.components(separatedBy: .newlines) {
            guard let prefix = rawLine.first else { continue }
            let value = String(rawLine.dropFirst())
            switch prefix {
            case "p":
                currentPID = Int32(value)
            case "c":
                currentCommand = value
            case "n":
                guard let pid = currentPID,
                      let colonIndex = value.lastIndex(of: ":") else { continue }
                let addrPart = String(value[..<colonIndex])
                let portPart = String(value[value.index(after: colonIndex)...])
                guard let port = Int(portPart), port > 0 else { continue }
                let key = "\(pid):\(port)"
                if seen.insert(key).inserted {
                    results.append(
                        LsofPortRecord(
                            pid: pid,
                            command: currentCommand.isEmpty ? "process" : currentCommand,
                            address: addrPart,
                            port: port
                        )
                    )
                }
            default:
                break
            }
        }
        return results
    }

    public static func resolveOwningSession(
        for pid: Int32,
        processMap: [Int32: ProcessRecord],
        shellByPID: [Int32: TerminalShellSessionInfo]
    ) -> TerminalShellSessionInfo? {
        var current = pid
        var visited = Set<Int32>()
        while current > 1 && visited.insert(current).inserted {
            if let match = shellByPID[current] {
                return match
            }
            guard let record = processMap[current], record.ppid != current else {
                break
            }
            current = record.ppid
        }
        return nil
    }

    public static func combine(
        psMap: [Int32: ProcessRecord],
        lsofRecords: [LsofPortRecord],
        sessions: [TerminalShellSessionInfo]
    ) -> [LivePortProcess] {
        let shellByPID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.shellPID, $0) })
        let shellPIDs = Set(shellByPID.keys)
        let ownAppPID = ProcessInfo.processInfo.processIdentifier

        var items: [LivePortProcess] = []
        var pidsWithPorts = Set<Int32>()

        // 1. Add all listening TCP ports
        for portRec in lsofRecords where portRec.pid != ownAppPID {
            pidsWithPorts.insert(portRec.pid)
            let psInfo = psMap[portRec.pid]
            let owner = resolveOwningSession(for: portRec.pid, processMap: psMap, shellByPID: shellByPID)
            let procName = psInfo?.comm ?? portRec.command
            let cmdLine = psInfo?.args ?? portRec.command
            items.append(
                LivePortProcess(
                    pid: portRec.pid,
                    ppid: psInfo?.ppid ?? 0,
                    processName: procName,
                    commandLine: cmdLine,
                    port: portRec.port,
                    bindAddress: portRec.address,
                    sessionID: owner?.sessionID,
                    sessionTitle: owner?.sessionTitle,
                    workspaceID: owner?.workspaceID,
                    workspaceName: owner?.workspaceName
                )
            )
        }

        // 2. Add any active child processes running inside Nathstar terminals that aren't already listed with a port
        let ignoredChildNames: Set<String> = ["zsh", "-zsh", "bash", "-bash", "sh", "login", "ps", "lsof"]
        for (pid, proc) in psMap where !pidsWithPorts.contains(pid) && !shellPIDs.contains(pid) && pid != ownAppPID {
            guard !ignoredChildNames.contains(proc.comm.lowercased()) else { continue }
            guard let owner = resolveOwningSession(for: pid, processMap: psMap, shellByPID: shellByPID) else {
                continue
            }
            items.append(
                LivePortProcess(
                    pid: pid,
                    ppid: proc.ppid,
                    processName: proc.comm,
                    commandLine: proc.args,
                    port: nil,
                    bindAddress: nil,
                    sessionID: owner.sessionID,
                    sessionTitle: owner.sessionTitle,
                    workspaceID: owner.workspaceID,
                    workspaceName: owner.workspaceName
                )
            )
        }

        return items.sorted { lhs, rhs in
            // Sort Nathstar-owned items first, then listening ports before plain processes, then by port/PID
            if lhs.isFromNathstarTerminal != rhs.isFromNathstarTerminal {
                return lhs.isFromNathstarTerminal
            }
            switch (lhs.port, rhs.port) {
            case (let lp?, let rp?):
                return lp != rp ? lp < rp : lhs.pid < rhs.pid
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.pid > rhs.pid
            }
        }
    }

    public static func scanLivePortsAndProcesses(sessions: [TerminalShellSessionInfo]) -> [LivePortProcess] {
        let uid = String(getuid())
        let psOutput = runCommand(executable: "/bin/ps", arguments: ["-axo", "pid=,ppid=,comm=,args="])
        let lsofOutput = runCommand(
            executable: "/usr/sbin/lsof",
            arguments: ["-a", "-u", uid, "-iTCP", "-sTCP:LISTEN", "-P", "-n", "-F", "pcn"]
        )
        let psMap = parsePSOutput(psOutput)
        let lsofRecords = parseLsofMachineOutput(lsofOutput)
        return combine(psMap: psMap, lsofRecords: lsofRecords, sessions: sessions)
    }

    private static func runCommand(executable: String, arguments: [String]) -> String {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return "" }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

public struct AppPreferences: Codable, Hashable, Sendable {
    public var fontName: String
    public var fontSize: Double
    public var useMetalRenderer: Bool
    public var showAttentionCenter: Bool
    public var showAIChat: Bool
    public var warnBeforeRiskyCommands: Bool
    public var longRunningCommandThreshold: Double
    public var isSidebarPinned: Bool
    public var enableDoubleTapControlHotkey: Bool
    public var enableQuakeVisorMode: Bool
    public var showCommandBlocksBar: Bool
    public var enableComposerAutocomplete: Bool
    public var restoreScrollbackOnLaunch: Bool
    public var enablePersistentTmuxSessions: Bool
    public var theme: TerminalThemePreset
    public var cursorStyle: TerminalCursorStyle
    public var backgroundOpacity: Double
    public var scrollbackLines: Int
    public var collapsedSidebarCategories: [WorkspaceCategory]
    public var customSidebarCategoryTitles: [WorkspaceCategory: String]
    public var aiSettings: AISettings

    public init(
        fontName: String = "SF Mono",
        fontSize: Double = 13,
        useMetalRenderer: Bool = false,
        showAttentionCenter: Bool = false,
        showAIChat: Bool = false,
        warnBeforeRiskyCommands: Bool = true,
        longRunningCommandThreshold: Double = 10,
        isSidebarPinned: Bool = true,
        enableDoubleTapControlHotkey: Bool = true,
        enableQuakeVisorMode: Bool = false,
        showCommandBlocksBar: Bool = true,
        enableComposerAutocomplete: Bool = true,
        restoreScrollbackOnLaunch: Bool = true,
        enablePersistentTmuxSessions: Bool = false,
        theme: TerminalThemePreset = .nathstarMidnight,
        cursorStyle: TerminalCursorStyle = .blinkBlock,
        backgroundOpacity: Double = 1.0,
        scrollbackLines: Int = 5000,
        collapsedSidebarCategories: [WorkspaceCategory] = [],
        customSidebarCategoryTitles: [WorkspaceCategory: String] = [:],
        aiSettings: AISettings = AISettings()
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.useMetalRenderer = useMetalRenderer
        self.showAttentionCenter = showAttentionCenter
        self.showAIChat = showAIChat
        self.warnBeforeRiskyCommands = warnBeforeRiskyCommands
        self.longRunningCommandThreshold = longRunningCommandThreshold
        self.isSidebarPinned = isSidebarPinned
        self.enableDoubleTapControlHotkey = enableDoubleTapControlHotkey
        self.enableQuakeVisorMode = enableQuakeVisorMode
        self.showCommandBlocksBar = showCommandBlocksBar
        self.enableComposerAutocomplete = enableComposerAutocomplete
        self.restoreScrollbackOnLaunch = restoreScrollbackOnLaunch
        self.enablePersistentTmuxSessions = enablePersistentTmuxSessions
        self.theme = theme
        self.cursorStyle = cursorStyle
        self.backgroundOpacity = backgroundOpacity
        self.scrollbackLines = scrollbackLines
        self.collapsedSidebarCategories = collapsedSidebarCategories
        self.customSidebarCategoryTitles = customSidebarCategoryTitles
        self.aiSettings = aiSettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontName = try container.decode(String.self, forKey: .fontName)
        fontSize = try container.decode(Double.self, forKey: .fontSize)
        useMetalRenderer = try container.decode(Bool.self, forKey: .useMetalRenderer)
        showAttentionCenter = try container.decode(Bool.self, forKey: .showAttentionCenter)
        showAIChat = try container.decodeIfPresent(Bool.self, forKey: .showAIChat) ?? false
        warnBeforeRiskyCommands = try container.decode(Bool.self, forKey: .warnBeforeRiskyCommands)
        longRunningCommandThreshold = try container.decode(Double.self, forKey: .longRunningCommandThreshold)
        isSidebarPinned = try container.decodeIfPresent(Bool.self, forKey: .isSidebarPinned) ?? true
        enableDoubleTapControlHotkey = try container.decodeIfPresent(Bool.self, forKey: .enableDoubleTapControlHotkey) ?? true
        enableQuakeVisorMode = try container.decodeIfPresent(Bool.self, forKey: .enableQuakeVisorMode) ?? false
        showCommandBlocksBar = try container.decodeIfPresent(Bool.self, forKey: .showCommandBlocksBar) ?? true
        enableComposerAutocomplete = try container.decodeIfPresent(Bool.self, forKey: .enableComposerAutocomplete) ?? true
        restoreScrollbackOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .restoreScrollbackOnLaunch) ?? true
        enablePersistentTmuxSessions = try container.decodeIfPresent(Bool.self, forKey: .enablePersistentTmuxSessions) ?? false
        theme = try container.decodeIfPresent(TerminalThemePreset.self, forKey: .theme) ?? .nathstarMidnight
        cursorStyle = try container.decodeIfPresent(TerminalCursorStyle.self, forKey: .cursorStyle) ?? .blinkBlock
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? 1.0
        scrollbackLines = try container.decodeIfPresent(Int.self, forKey: .scrollbackLines) ?? 5000
        collapsedSidebarCategories = try container.decodeIfPresent([WorkspaceCategory].self, forKey: .collapsedSidebarCategories) ?? []
        customSidebarCategoryTitles = try container.decodeIfPresent([WorkspaceCategory: String].self, forKey: .customSidebarCategoryTitles) ?? [:]
        aiSettings = try container.decodeIfPresent(AISettings.self, forKey: .aiSettings) ?? AISettings()
    }

    public func title(for category: WorkspaceCategory) -> String {
        let custom = customSidebarCategoryTitles[category]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return custom.isEmpty ? category.defaultTitle : custom
    }

    public func isCategoryCollapsed(_ category: WorkspaceCategory) -> Bool {
        collapsedSidebarCategories.contains(category)
    }
}

public struct NorthstarState: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var workspaces: [Workspace]
    public var selectedWorkspaceID: UUID?
    public var attentionItems: [AttentionItem]
    public var chatMessages: [AIChatMessage]
    public var snippets: [CommandSnippet]
    public var sshHosts: [SSHHostEntry]
    public var commandBlocks: [CommandBlock]
    public var sessionScrollbackSnapshots: [UUID: String]
    public var preferences: AppPreferences

    public init(
        schemaVersion: Int = 1,
        workspaces: [Workspace] = [],
        selectedWorkspaceID: UUID? = nil,
        attentionItems: [AttentionItem] = [],
        chatMessages: [AIChatMessage] = [],
        snippets: [CommandSnippet] = CommandSnippet.defaultSnippets,
        sshHosts: [SSHHostEntry] = [],
        commandBlocks: [CommandBlock] = [],
        sessionScrollbackSnapshots: [UUID: String] = [:],
        preferences: AppPreferences = AppPreferences()
    ) {
        self.schemaVersion = schemaVersion
        self.workspaces = workspaces
        self.selectedWorkspaceID = selectedWorkspaceID
        self.attentionItems = attentionItems
        self.chatMessages = chatMessages
        self.snippets = snippets
        self.sshHosts = sshHosts
        self.commandBlocks = commandBlocks
        self.sessionScrollbackSnapshots = sessionScrollbackSnapshots
        self.preferences = preferences
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        workspaces = try container.decodeIfPresent([Workspace].self, forKey: .workspaces) ?? []
        selectedWorkspaceID = try container.decodeIfPresent(UUID.self, forKey: .selectedWorkspaceID)
        attentionItems = try container.decodeIfPresent([AttentionItem].self, forKey: .attentionItems) ?? []
        chatMessages = try container.decodeIfPresent([AIChatMessage].self, forKey: .chatMessages) ?? []
        let decodedSnippets = try container.decodeIfPresent([CommandSnippet].self, forKey: .snippets)
        snippets = (decodedSnippets?.isEmpty == false) ? decodedSnippets! : CommandSnippet.defaultSnippets
        sshHosts = try container.decodeIfPresent([SSHHostEntry].self, forKey: .sshHosts) ?? []
        commandBlocks = try container.decodeIfPresent([CommandBlock].self, forKey: .commandBlocks) ?? []
        sessionScrollbackSnapshots = try container.decodeIfPresent([UUID: String].self, forKey: .sessionScrollbackSnapshots) ?? [:]
        preferences = try container.decodeIfPresent(AppPreferences.self, forKey: .preferences) ?? AppPreferences()
    }
}
