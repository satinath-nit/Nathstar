import Foundation

public enum RiskSeverity: Int, Codable, Comparable, Sendable {
    case low = 1
    case medium = 2
    case high = 3

    public static func < (lhs: RiskSeverity, rhs: RiskSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct RiskFinding: Codable, Hashable, Sendable {
    public var severity: RiskSeverity
    public var title: String
    public var explanation: String

    public init(severity: RiskSeverity, title: String, explanation: String) {
        self.severity = severity
        self.title = title
        self.explanation = explanation
    }
}

public struct CommandRiskAnalyzer: Sendable {
    public init() {}

    public func analyze(command: String, workingDirectory: String, isRemote: Bool = false) -> [RiskFinding] {
        let normalized = command
            .replacingOccurrences(of: "\\\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        var findings: [RiskFinding] = []
        let lower = normalized.lowercased()

        if matches(#"(^|[;&|]\s*)rm\s+[^\n]*(?:-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r)[^\n]*(?:/|~|\$home)(?:\s|$)"#, in: lower) {
            findings.append(.init(
                severity: .high,
                title: "Recursive deletion targets a broad path",
                explanation: "This command combines recursive forced deletion with a root or home-relative target."
            ))
        } else if matches(#"(^|[;&|]\s*)rm\s+[^\n]*-[a-z]*[rf][a-z]*"#, in: lower) {
            findings.append(.init(
                severity: .medium,
                title: "Recursive or forced deletion",
                explanation: "Review the expanded paths before deleting files recursively or without prompts."
            ))
        }

        if matches(#"\bgit\s+push\b[^\n]*(--force(?:-with-lease)?|-f)(\s|$)"#, in: lower) {
            findings.append(.init(
                severity: lower.contains("--force-with-lease") ? .medium : .high,
                title: "Force push rewrites remote history",
                explanation: "Confirm the branch and remote before replacing published commits."
            ))
        }

        if matches(#"\bgit\s+clean\b[^\n]*-[a-z]*f[a-z]*(?:d|x)"#, in: lower) {
            findings.append(.init(
                severity: .high,
                title: "Git clean can permanently remove untracked files",
                explanation: "Run a dry run with `git clean -n` and review ignored or untracked files first."
            ))
        }

        if matches(#"\bdd\b[^\n]*\bof=/dev/(?:disk|rdisk|sd|nvme)"#, in: lower) {
            findings.append(.init(
                severity: .high,
                title: "Raw disk write",
                explanation: "The output target appears to be a block device and may destroy a disk's contents."
            ))
        }

        if matches(#"\b(?:curl|wget)\b[^\n]*\|\s*(?:sudo\s+)?(?:sh|bash|zsh)\b"#, in: lower) {
            findings.append(.init(
                severity: .high,
                title: "Remote content is piped directly to a shell",
                explanation: "Download and inspect the script before executing it."
            ))
        }

        if matches(#"\b(?:chmod|chown)\b[^\n]*(?:-r|--recursive)\b[^\n]*(?:/|~)(?:\s|$)"#, in: lower) {
            findings.append(.init(
                severity: .high,
                title: "Recursive permission change on a broad path",
                explanation: "This can make large parts of the system inaccessible or insecure."
            ))
        }

        if isRemote && findings.isEmpty && (lower.contains("sudo ") || lower.hasPrefix("sudo ")) {
            findings.append(.init(
                severity: .low,
                title: "Privileged command on a remote host",
                explanation: "Confirm the connected host before elevating privileges."
            ))
        }

        if workingDirectory == "/" && (lower.contains("rm ") || lower.contains("chmod ") || lower.contains("chown ")) {
            findings.append(.init(
                severity: .high,
                title: "Destructive command from the filesystem root",
                explanation: "The current directory is `/`, so relative paths may affect system files."
            ))
        }

        return findings.sorted { $0.severity > $1.severity }
    }

    private func matches(_ pattern: String, in value: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}
