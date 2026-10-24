import Foundation

public struct EnvironmentCapsule: Codable, Hashable, Sendable {
    public var version: Int
    public var name: String
    public var description: String
    public var requiredTools: [CapsuleTool]
    public var variables: [String: String]
    public var startupCommands: [CapsuleCommand]
    public var services: [CapsuleService]
    public var healthChecks: [CapsuleCommand]
    public var usefulCommands: [CapsuleCommand]
    public var agentInstructions: [String]
    public var layout: CapsuleLayout

    public init(
        version: Int = 1,
        name: String,
        description: String = "",
        requiredTools: [CapsuleTool] = [],
        variables: [String: String] = [:],
        startupCommands: [CapsuleCommand] = [],
        services: [CapsuleService] = [],
        healthChecks: [CapsuleCommand] = [],
        usefulCommands: [CapsuleCommand] = [],
        agentInstructions: [String] = [],
        layout: CapsuleLayout = .grid
    ) {
        self.version = version
        self.name = name
        self.description = description
        self.requiredTools = requiredTools
        self.variables = variables
        self.startupCommands = startupCommands
        self.services = services
        self.healthChecks = healthChecks
        self.usefulCommands = usefulCommands
        self.agentInstructions = agentInstructions
        self.layout = layout
    }

    private enum CodingKeys: String, CodingKey {
        case version, name, description, requiredTools, variables, startupCommands
        case services, healthChecks, usefulCommands, agentInstructions, layout
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        requiredTools = try container.decodeIfPresent([CapsuleTool].self, forKey: .requiredTools) ?? []
        variables = try container.decodeIfPresent([String: String].self, forKey: .variables) ?? [:]
        startupCommands = try container.decodeIfPresent([CapsuleCommand].self, forKey: .startupCommands) ?? []
        services = try container.decodeIfPresent([CapsuleService].self, forKey: .services) ?? []
        healthChecks = try container.decodeIfPresent([CapsuleCommand].self, forKey: .healthChecks) ?? []
        usefulCommands = try container.decodeIfPresent([CapsuleCommand].self, forKey: .usefulCommands) ?? []
        agentInstructions = try container.decodeIfPresent([String].self, forKey: .agentInstructions) ?? []
        layout = try container.decodeIfPresent(CapsuleLayout.self, forKey: .layout) ?? .grid
    }
}

public enum CapsuleLayout: String, Codable, Hashable, Sendable, CaseIterable {
    case grid
    case horizontal
    case vertical
}

public struct CapsuleTool: Codable, Identifiable, Hashable, Sendable {
    public var name: String
    public var versionCommand: String?

    public var id: String { name }

    public init(name: String, versionCommand: String? = nil) {
        self.name = name
        self.versionCommand = versionCommand
    }
}

public struct CapsuleCommand: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var command: String
    public var workingDirectory: String?

    public init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String? = nil
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
    }

    private enum CodingKeys: String, CodingKey {
        case name, command, workingDirectory
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        name = try container.decode(String.self, forKey: .name)
        command = try container.decode(String.self, forKey: .command)
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(command, forKey: .command)
        try container.encodeIfPresent(workingDirectory, forKey: .workingDirectory)
    }
}

public struct CapsuleService: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var command: String
    public var workingDirectory: String?
    public var healthCheck: String?
    public var autoStart: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String? = nil,
        healthCheck: String? = nil,
        autoStart: Bool = true
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.healthCheck = healthCheck
        self.autoStart = autoStart
    }

    private enum CodingKeys: String, CodingKey {
        case name, command, workingDirectory, healthCheck, autoStart
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        name = try container.decode(String.self, forKey: .name)
        command = try container.decode(String.self, forKey: .command)
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        healthCheck = try container.decodeIfPresent(String.self, forKey: .healthCheck)
        autoStart = try container.decodeIfPresent(Bool.self, forKey: .autoStart) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(command, forKey: .command)
        try container.encodeIfPresent(workingDirectory, forKey: .workingDirectory)
        try container.encodeIfPresent(healthCheck, forKey: .healthCheck)
        try container.encode(autoStart, forKey: .autoStart)
    }
}

public enum CapsuleIssueSeverity: String, Codable, Hashable, Sendable {
    case warning
    case error
}

public struct CapsuleIssue: Identifiable, Hashable, Sendable {
    public var id: String { "\(severity.rawValue):\(message)" }
    public var severity: CapsuleIssueSeverity
    public var message: String

    public init(severity: CapsuleIssueSeverity, message: String) {
        self.severity = severity
        self.message = message
    }
}

public struct CapsuleToolStatus: Identifiable, Hashable, Sendable {
    public var id: String { tool.name }
    public var tool: CapsuleTool
    public var executablePath: String?

    public init(tool: CapsuleTool, executablePath: String?) {
        self.tool = tool
        self.executablePath = executablePath
    }
}

public struct CapsuleInspection: Hashable, Sendable {
    public var issues: [CapsuleIssue]
    public var tools: [CapsuleToolStatus]

    public var canActivate: Bool {
        !issues.contains { $0.severity == .error }
    }

    public init(issues: [CapsuleIssue], tools: [CapsuleToolStatus]) {
        self.issues = issues
        self.tools = tools
    }
}

public struct CapsuleStore: Sendable {
    public static let relativePath = ".nathstar/manifest.json"
    public static let legacyCapsuleRelativePath = ".nathstar/capsule.json"
    public static let legacyRelativePath = ".northstar/capsule.json"
    public static let dotEnvRelativePath = ".env"

    public init() {}

    public func capsuleURL(workspaceRoot: URL) -> URL {
        workspaceRoot.appendingPathComponent(Self.relativePath)
    }

    public func dotEnvURL(workspaceRoot: URL) -> URL {
        workspaceRoot.appendingPathComponent(Self.dotEnvRelativePath)
    }

    public func existingCapsuleURL(workspaceRoot: URL) -> URL? {
        let preferred = capsuleURL(workspaceRoot: workspaceRoot)
        if FileManager.default.fileExists(atPath: preferred.path) { return preferred }
        let legacyNathstar = workspaceRoot.appendingPathComponent(Self.legacyCapsuleRelativePath)
        if FileManager.default.fileExists(atPath: legacyNathstar.path) { return legacyNathstar }
        let legacy = workspaceRoot.appendingPathComponent(Self.legacyRelativePath)
        return FileManager.default.fileExists(atPath: legacy.path) ? legacy : nil
    }

    public func load(workspaceRoot: URL) throws -> EnvironmentCapsule? {
        guard let url = existingCapsuleURL(workspaceRoot: workspaceRoot) else { return nil }
        let decoder = JSONDecoder()
        return try decoder.decode(EnvironmentCapsule.self, from: Data(contentsOf: url))
    }

    @discardableResult
    public func createTemplate(workspaceRoot: URL, workspaceName: String, initialVariables: [String: String] = [:]) throws -> URL {
        let url = existingCapsuleURL(workspaceRoot: workspaceRoot) ?? capsuleURL(workspaceRoot: workspaceRoot)
        guard !FileManager.default.fileExists(atPath: url.path) else { return url }
        let safeVars = initialVariables.filter { key, _ in
            CapsuleInspector.validVariableName(key) && !CapsuleInspector.appearsSecret(key: key)
        }
        let capsule = EnvironmentCapsule(
            name: workspaceName,
            description: "A portable Nathstar project manifest.",
            requiredTools: [CapsuleTool(name: "git")],
            variables: safeVars,
            startupCommands: [
                CapsuleCommand(name: "Git status", command: "git status --short --branch")
            ],
            healthChecks: [
                CapsuleCommand(name: "Repository", command: "git rev-parse --is-inside-work-tree")
            ],
            usefulCommands: [
                CapsuleCommand(name: "Recent commits", command: "git log --oneline -10")
            ],
            agentInstructions: [
                "Read the repository guidance before changing files.",
                "Run the relevant checks before presenting completed work."
            ]
        )
        try save(capsule, workspaceRoot: workspaceRoot)
        return url
    }

    public func save(_ capsule: EnvironmentCapsule, workspaceRoot: URL) throws {
        let url = existingCapsuleURL(workspaceRoot: workspaceRoot) ?? capsuleURL(workspaceRoot: workspaceRoot)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(capsule)
        try data.write(to: url, options: .atomic)
    }

    public static func formatDotEnvContent(variables: [String: String], workspaceName: String) -> String {
        let sortedKeys = variables.keys.sorted()
        var lines: [String] = [
            "# Generated by Nathstar Manifest",
            "# Workspace: \(workspaceName)"
        ]
        for key in sortedKeys {
            guard CapsuleInspector.validVariableName(key) else { continue }
            let rawValue = variables[key] ?? ""
            let escaped = rawValue
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            let needsQuotes = rawValue.contains(" ") || rawValue.contains("#") || rawValue.contains("\"") || rawValue.contains("'") || rawValue.isEmpty
            lines.append(needsQuotes ? "\(key)=\"\(escaped)\"" : "\(key)=\(rawValue)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    @discardableResult
    public func exportDotEnv(variables: [String: String], workspaceRoot: URL) throws -> URL {
        let url = dotEnvURL(workspaceRoot: workspaceRoot)
        let payload = Self.formatDotEnvContent(variables: variables, workspaceName: workspaceRoot.lastPathComponent)
        guard let data = payload.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    public func loadDotEnv(workspaceRoot: URL) throws -> [String: String] {
        let url = dotEnvURL(workspaceRoot: workspaceRoot)
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let content = try String(contentsOf: url, encoding: .utf8)
        var parsed: [String: String] = [:]
        for rawLine in content.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasPrefix("export ") {
                line = String(line.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces)
            }
            guard let eqIndex = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eqIndex]).trimmingCharacters(in: .whitespaces)
            guard CapsuleInspector.validVariableName(key) else { continue }
            var value = String(line[line.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")),
               value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            parsed[key] = value
        }
        return parsed
    }

    public static func shellExportCommand(for variables: [String: String]) -> String? {
        let validPairs = variables
            .filter { CapsuleInspector.validVariableName($0.key) }
            .sorted { $0.key < $1.key }
        guard !validPairs.isEmpty else { return nil }
        let exports = validPairs.map { key, value in
            let singleQuoteEscaped = value.replacingOccurrences(of: "'", with: "'\\''")
            return "export \(key)='\(singleQuoteEscaped)'"
        }
        return exports.joined(separator: " && ")
    }
}

public struct CapsuleInspector: Sendable {
    public init() {}

    public func inspect(
        _ capsule: EnvironmentCapsule,
        workspaceRoot: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> CapsuleInspection {
        var issues: [CapsuleIssue] = []
        let trimmedName = capsule.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if capsule.version != 1 {
            issues.append(.init(severity: .error, message: "Manifest version \(capsule.version) is not supported."))
        }
        if trimmedName.isEmpty {
            issues.append(.init(severity: .error, message: "The manifest needs a name."))
        }

        for (key, value) in capsule.variables {
            if !Self.validVariableName(key) {
                issues.append(.init(severity: .error, message: "\(key) is not a valid environment variable name."))
            }
            if Self.appearsSecret(key: key) {
                issues.append(.init(
                    severity: .error,
                    message: "\(key) looks secret. Store secrets in workspace local env or macOS Keychain, not manifest.json."
                ))
            }
            if value.contains("\n") || value.contains("\0") {
                issues.append(.init(severity: .error, message: "\(key) contains an unsupported control character."))
            }
        }

        let commands = capsule.startupCommands
            + capsule.healthChecks
            + capsule.usefulCommands
            + capsule.services.map {
                CapsuleCommand(name: $0.name, command: $0.command, workingDirectory: $0.workingDirectory)
            }
        for command in commands {
            if command.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || command.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(severity: .error, message: "Every manifest command needs a name and command."))
            }
            if let directory = command.workingDirectory,
               Self.resolve(directory: directory, workspaceRoot: workspaceRoot) == nil {
                issues.append(.init(
                    severity: .error,
                    message: "\(command.name) uses a working directory outside the workspace."
                ))
            }
        }

        let path = environment["PATH"] ?? "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        let tools = capsule.requiredTools.map { tool in
            CapsuleToolStatus(tool: tool, executablePath: Self.findExecutable(tool.name, path: path))
        }
        for status in tools where status.executablePath == nil {
            issues.append(.init(severity: .warning, message: "Required tool '\(status.tool.name)' was not found in PATH."))
        }
        return CapsuleInspection(issues: issues, tools: tools)
    }

    public static func resolve(directory: String?, workspaceRoot: URL) -> URL? {
        guard let directory, !directory.isEmpty, directory != "." else { return workspaceRoot.standardizedFileURL }
        guard !directory.hasPrefix("/") else { return nil }
        let root = workspaceRoot.standardizedFileURL
        let resolved = root.appendingPathComponent(directory).standardizedFileURL
        guard resolved.path == root.path || resolved.path.hasPrefix(root.path + "/") else { return nil }
        return resolved
    }

    public static func validVariableName(_ name: String) -> Bool {
        name.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil
    }

    public static func appearsSecret(key: String) -> Bool {
        let normalized = key.uppercased()
        return ["SECRET", "TOKEN", "PASSWORD", "PASSWD", "PRIVATE_KEY", "CREDENTIAL", "API_KEY"]
            .contains { normalized.contains($0) }
    }

    private static func findExecutable(_ name: String, path: String) -> String? {
        guard !name.contains("/") else {
            return FileManager.default.isExecutableFile(atPath: name) ? name : nil
        }
        for directory in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }
}
