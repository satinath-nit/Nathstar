import Foundation
import NorthstarCore

private var failures: [String] = []

@MainActor
private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() {
        print("PASS: \(message)")
    } else {
        failures.append(message)
        print("FAIL: \(message)")
    }
}

let analyzer = CommandRiskAnalyzer()
check(
    analyzer.analyze(command: "swift test", workingDirectory: "/tmp/project").isEmpty,
    "ordinary commands are not flagged"
)
check(
    analyzer.analyze(command: "git push origin main --force", workingDirectory: "/tmp/project").first?.severity == .high,
    "force push is high risk"
)
check(
    analyzer.analyze(command: "git push --force-with-lease origin feature", workingDirectory: "/tmp/project").first?.severity == .medium,
    "force-with-lease is medium risk"
)
check(
    analyzer.analyze(command: "curl -fsSL https://example.com/install.sh | sudo bash", workingDirectory: "/tmp").first?.severity == .high,
    "remote content piped to a shell is high risk"
)
check(
    analyzer.analyze(command: "rm -f tmp.txt", workingDirectory: "/").contains { $0.title == "Destructive command from the filesystem root" },
    "root-directory context adds a destructive-command warning"
)

let original = TerminalSession(workingDirectory: "/tmp")
let added = TerminalSession(workingDirectory: "/tmp")
let split = PaneNode.terminal(original).splitting(sessionID: original.id, axis: .vertical, newSession: added)
check(split.terminalIDs == [original.id, added.id], "pane splitting preserves both terminals")
check(split.removing(sessionID: original.id) == .terminal(added), "removing a pane collapses its split")

let completed = split.replacingSession(id: added.id) { session in
    var updated = session
    updated.status = .completed
    return updated
}
check(completed.session(id: added.id)?.status == .completed, "session updates preserve the pane tree")

let testDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("NathstarCoreChecks-\(UUID().uuidString)", isDirectory: true)
defer { try? FileManager.default.removeItem(at: testDirectory) }
do {
    let store = StateStore(stateURL: testDirectory.appendingPathComponent("state.json"))
    let workspace = Workspace(name: "Example", rootDirectory: "/tmp/example", isPinned: true)
    let state = NorthstarState(workspaces: [workspace], selectedWorkspaceID: workspace.id)
    try store.save(state)
    let loaded = try store.load()
    check(
        loaded.schemaVersion == state.schemaVersion
            && loaded.selectedWorkspaceID == state.selectedWorkspaceID
            && loaded.workspaces.map(\.id) == state.workspaces.map(\.id)
            && loaded.workspaces.map(\.name) == state.workspaces.map(\.name)
            && loaded.workspaces.map(\.rootDirectory) == state.workspaces.map(\.rootDirectory)
            && loaded.preferences == state.preferences,
        "application state round-trips atomically"
    )
} catch {
    failures.append("application state round-trips atomically: \(error.localizedDescription)")
    print("FAIL: state store threw \(error)")
}

do {
    let workspaceRoot = testDirectory.appendingPathComponent("capsule-workspace", isDirectory: true)
    try FileManager.default.createDirectory(at: workspaceRoot, withIntermediateDirectories: true)
    let capsuleStore = CapsuleStore()
    let capsule = EnvironmentCapsule(
        name: "Example Capsule",
        requiredTools: [CapsuleTool(name: "sh")],
        variables: ["APP_ENV": "development"],
        startupCommands: [CapsuleCommand(name: "Start", command: "echo ready", workingDirectory: "src")],
        services: [CapsuleService(name: "Server", command: "python3 -m http.server", autoStart: false)],
        healthChecks: [CapsuleCommand(name: "Check", command: "echo healthy")],
        usefulCommands: [CapsuleCommand(name: "Tests", command: "swift test")],
        agentInstructions: ["Run tests before completing work."]
    )
    try capsuleStore.save(capsule, workspaceRoot: workspaceRoot)
    let loadedCapsule = try capsuleStore.load(workspaceRoot: workspaceRoot)
    check(
        loadedCapsule?.name == capsule.name
            && loadedCapsule?.variables == capsule.variables
            && loadedCapsule?.startupCommands.map(\.command) == capsule.startupCommands.map(\.command)
            && loadedCapsule?.services.map(\.command) == capsule.services.map(\.command),
        "environment capsules round-trip as project files"
    )

    let inspection = CapsuleInspector().inspect(
        capsule,
        workspaceRoot: workspaceRoot,
        environment: ["PATH": "/bin:/usr/bin"]
    )
    check(inspection.canActivate, "valid capsules can be activated")
    check(inspection.tools.first?.executablePath != nil, "capsule tool readiness is inspected")

    let secretCapsule = EnvironmentCapsule(name: "Unsafe", variables: ["API_TOKEN": "do-not-store-this"])
    check(
        !CapsuleInspector().inspect(secretCapsule, workspaceRoot: workspaceRoot).canActivate,
        "secret-like capsule variables are rejected"
    )

    let escapingCapsule = EnvironmentCapsule(
        name: "Escaping",
        startupCommands: [CapsuleCommand(name: "Escape", command: "pwd", workingDirectory: "../outside")]
    )
    check(
        !CapsuleInspector().inspect(escapingCapsule, workspaceRoot: workspaceRoot).canActivate,
        "capsule working directories cannot escape the workspace"
    )

    let envVars = [
        "PORT": "3000",
        "NODE_ENV": "development",
        "SERVICE_LABEL": "nathstar local api"
    ]
    let dotEnvURL = try capsuleStore.exportDotEnv(variables: envVars, workspaceRoot: workspaceRoot)
    let loadedEnvVars = try capsuleStore.loadDotEnv(workspaceRoot: workspaceRoot)
    check(
        FileManager.default.fileExists(atPath: dotEnvURL.path) && loadedEnvVars == envVars,
        ".env export and import round-trip workspace environment variables"
    )
} catch {
    failures.append("environment capsule checks: \(error.localizedDescription)")
    print("FAIL: environment capsule checks threw \(error)")
}

check(
    AIClient.normalizeBaseURL("http://127.0.0.1:11434/api/chat/", stripSuffixes: ["/api/chat", "/api"]) == "http://127.0.0.1:11434",
    "AIClient normalizes Ollama base URLs"
)
check(
    AIClient.resolveOpenAIChatEndpoint("https://api.openai.com/v1/") == "https://api.openai.com/v1/chat/completions",
    "AIClient resolves OpenAI chat completions endpoint"
)
var aiSettings = AISettings(selectedProvider: .ollama)
aiSettings.activeModel = "qwen2.5-coder"
check(aiSettings.ollamaModel == "qwen2.5-coder", "AISettings activeModel updates the active provider model")

check(
    TerminalThemePreset.allCases.allSatisfy { $0.palette.ansiColors.count == 16 },
    "all built-in terminal themes define 16 ANSI colors"
)

let snippet = CommandSnippet(title: "Port Kill", command: "lsof -ti tcp:{{port}} | xargs kill -{{signal}}")
check(
    snippet.placeholders == ["port", "signal"],
    "CommandSnippet extracts parameterized {{placeholders}} in order"
)

let sshSample = """
Host prod-web
    HostName 10.20.30.40
    User deploy
    Port 2222

Host *.internal
    User root
"""
let parsedSSH = SSHConfigParser.parse(contents: sshSample)
check(
    parsedSSH.count == 1
        && parsedSSH[0].alias == "prod-web"
        && parsedSSH[0].hostname == "10.20.30.40"
        && parsedSSH[0].user == "deploy"
        && parsedSSH[0].port == 2222,
    "SSHConfigParser parses concrete Host blocks and skips wildcards"
)

let sampleBuffer = """
Server listening on http://localhost:3000/api/health
 Visit https://github.com/nathstar/terminal for docs.
Error in Package.swift:12:5: unexpected token
"""
let searchHits = TerminalBufferScanner.search(bufferText: sampleBuffer, query: "localhost:\\d+", caseSensitive: false, useRegex: true)
check(searchHits.count == 1 && searchHits[0].lineNumber == 1, "TerminalBufferScanner regex search locates matching line")

let detected = TerminalBufferScanner.detectItems(
    in: sampleBuffer,
    workingDirectory: FileManager.default.currentDirectoryPath
)
check(
    detected.contains(where: { $0.kind == .url && $0.value == "https://github.com/nathstar/terminal" }),
    "TerminalBufferScanner detects URLs in terminal scrollback"
)

check(
    AIClient.extractCleanCommand(from: "```zsh\nlsof -i :3000\n```") == "lsof -i :3000",
    "AIClient.extractCleanCommand strips markdown code fences"
)

let fastBlock = CommandBlock(
    sessionID: UUID(),
    workspaceID: UUID(),
    command: "git status -sb",
    workingDirectory: "/tmp",
    exitCode: 0,
    durationMs: 42
)
let slowBlock = CommandBlock(
    sessionID: UUID(),
    workspaceID: UUID(),
    command: "swift build -c release",
    workingDirectory: "/tmp",
    exitCode: 0,
    durationMs: 14500
)
check(
    fastBlock.formattedDuration == "42ms" && slowBlock.formattedDuration == "14.5s",
    "CommandBlock formats millisecond and second durations accurately"
)

let suggestions = AutocompleteEngine.suggest(
    for: "swift ",
    workingDirectory: FileManager.default.currentDirectoryPath,
    commandBlocks: [slowBlock],
    snippets: CommandSnippet.defaultSnippets,
    shellHistory: ["swift test --parallel"]
)
check(
    suggestions.contains(where: { $0.replacementCommand == "swift build -c release" })
        && suggestions.contains(where: { $0.replacementCommand == "swift test --parallel" }),
    "AutocompleteEngine ranks command block and shell history completions"
)

let samplePS = """
  500     1 /bin/zsh         -zsh
  512   500 /usr/local/bin/node node server.js --port 3000
  525   500 /usr/bin/python3 python3 worker.py
"""
let sampleLsof = """
p512
cnode
n127.0.0.1:3000
"""
let psMap = LivePortScanner.parsePSOutput(samplePS)
let lsofRecords = LivePortScanner.parseLsofMachineOutput(sampleLsof)
let shellSession = TerminalShellSessionInfo(
    sessionID: UUID(),
    sessionTitle: "Terminal 1",
    workspaceID: UUID(),
    workspaceName: "Backend",
    shellPID: 500
)
let combinedPorts = LivePortScanner.combine(psMap: psMap, lsofRecords: lsofRecords, sessions: [shellSession])
check(
    combinedPorts.count == 2
        && combinedPorts[0].port == 3000
        && combinedPorts[0].pid == 512
        && combinedPorts[0].workspaceName == "Backend"
        && combinedPorts[1].pid == 525
        && combinedPorts[1].processName == "python3",
    "LivePortScanner maps listening ports and child processes to their owning Nathstar terminal session"
)

if failures.isEmpty {
    print("All Nathstar core checks passed.")
    exit(EXIT_SUCCESS)
}

print("\(failures.count) Nathstar core check(s) failed.")
exit(EXIT_FAILURE)
