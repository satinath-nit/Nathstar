import AppKit
import Combine
import Darwin
import Foundation
import NorthstarCore

enum RightPanelTab: String, CaseIterable {
    case attention = "Attention"
    case manifest = "Manifest"
    case ports = "Ports"
}

struct WorkspaceTelemetry: Equatable, Sendable {
    var gitBranch: String?
    var addedOrUntrackedCount: Int = 0
    var modifiedCount: Int = 0
    var listeningPort: Int?
    var listeningProcess: String?
    var capsuleHealthyCount: Int = 0
    var capsuleTotalChecks: Int = 0
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: NorthstarState
    @Published var lastPersistenceError: String?
    @Published var isCommandPalettePresented = false
    @Published var isCapsulePresented = false
    @Published var rightPanelTab: RightPanelTab = .attention
    @Published var zoomedSessionID: UUID?
    @Published var envStatusMessage: String?
    @Published private(set) var workspaceTelemetry: [UUID: WorkspaceTelemetry] = [:]
    @Published private(set) var capsule: EnvironmentCapsule?
    @Published private(set) var capsuleInspection: CapsuleInspection?
    @Published private(set) var capsuleError: String?
    @Published var isGeneratingAIResponse = false
    @Published var ollamaModels: [String] = []
    @Published var aiStatusMessage: String?

    // In-Terminal Search (⌘F) & Quick Links/Hints (⇧⌘L)
    @Published var isTerminalSearchPresented = false
    @Published var terminalSearchQuery = ""
    @Published var terminalSearchCaseSensitive = false
    @Published var terminalSearchRegex = false
    @Published private(set) var terminalSearchMatches: [TerminalSearchMatch] = []
    @Published var selectedSearchMatchIndex = 0
    @Published var isQuickLinksPresented = false
    @Published private(set) var detectedItems: [DetectedTerminalItem] = []

    // One-Click Fix Failed Command & Inline AI Bar (⌘I)
    @Published private(set) var failedCommandsBySession: [UUID: FailedCommandEvent] = [:]
    @Published var isInlineAIBarPresented = false
    @Published var isGeneratingInlineCommand = false
    @Published var inlineAIError: String?
    @Published var composerPrefillText: String?

    // SSH Hosts discovered from ~/.ssh/config
    @Published private(set) var discoveredSSHHosts: [SSHHostEntry] = []
    @Published private(set) var cachedZshHistory: [String] = []

    // Live Ports & Processes across all terminals
    @Published private(set) var livePortProcesses: [LivePortProcess] = []
    @Published var isScanningPorts = false
    @Published var portsStatusMessage: String?

    private let store: StateStore?
    private let capsuleStore = CapsuleStore()
    private let aiClient = AIClient()
    private var saveTask: Task<Void, Never>?
    private var aiGenerationTask: Task<Void, Never>?
    private var inlineAITask: Task<Void, Never>?
    private var portScanTask: Task<Void, Never>?

    init() {
        let resolvedStore: StateStore?
        let resolvedState: NorthstarState
        let persistenceError: String?
        do {
            let candidateStore = try StateStore.defaultStore()
            var loaded = try candidateStore.load()
            loaded.workspaces = loaded.workspaces.map { workspace in
                var workspace = workspace
                workspace.tabs = workspace.tabs.enumerated().map { index, tab in
                    var tab = tab
                    if tab.title.contains("(workspace.tabs.count") {
                        tab.title = "Terminal \(index + 1)"
                    }
                    tab.root = resetSessionStates(in: tab.root, workspaceRoot: workspace.rootDirectory)
                    return tab
                }
                return workspace
            }
            if loaded.workspaces.isEmpty {
                loaded = Self.initialState()
            }
            resolvedStore = candidateStore
            resolvedState = loaded
            persistenceError = nil
        } catch {
            resolvedStore = nil
            resolvedState = Self.initialState()
            persistenceError = error.localizedDescription
        }
        self.store = resolvedStore
        self.state = resolvedState
        self.lastPersistenceError = persistenceError
        self.capsule = nil
        self.capsuleInspection = nil
        self.capsuleError = nil
        self.discoveredSSHHosts = SSHConfigParser.parseDefaultSSHConfig()
        self.cachedZshHistory = AutocompleteEngine.loadRecentZshHistory(maxCount: 250)
        reloadCapsule()
        refreshTelemetry()
        Task { [weak self] in
            await self?.refreshOllamaModels()
        }
    }

    var selectedWorkspace: Workspace? {
        guard let id = state.selectedWorkspaceID else { return nil }
        return state.workspaces.first { $0.id == id }
    }

    var selectedTab: TerminalTab? {
        guard let workspace = selectedWorkspace else { return nil }
        return workspace.tabs.first { $0.id == workspace.selectedTabID }
    }

    var unreadAttentionCount: Int {
        state.attentionItems.lazy.filter { !$0.isRead }.count
    }

    func selectWorkspace(_ id: UUID) {
        guard state.selectedWorkspaceID != id else { return }
        state.selectedWorkspaceID = id
        updateWorkspace(id: id) { workspace in
            workspace.lastOpenedAt = Date()
        }
        zoomedSessionID = nil
        save()
        reloadCapsule()
        refreshTelemetry()
    }

    func addWorkspace(url: URL, category: WorkspaceCategory? = nil) {
        let standardized = url.standardizedFileURL.path
        if let existing = state.workspaces.first(where: { $0.rootDirectory == standardized }) {
            if let category {
                setWorkspaceCategory(workspaceID: existing.id, category: category)
            }
            selectWorkspace(existing.id)
            return
        }
        let name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        let workspace = Workspace(
            name: name,
            rootDirectory: standardized,
            isPinned: true,
            category: category
        )
        state.workspaces.insert(workspace, at: 0)
        state.selectedWorkspaceID = workspace.id
        zoomedSessionID = nil
        save()
        reloadCapsule()
        refreshTelemetry()
    }

    func togglePinned(workspaceID: UUID) {
        updateWorkspace(id: workspaceID) { $0.isPinned.toggle() }
        save()
    }

    func setWorkspaceCategory(workspaceID: UUID, category: WorkspaceCategory) {
        updateWorkspace(id: workspaceID) { $0.category = category }
        save()
    }

    func toggleSidebarCategoryCollapsed(_ category: WorkspaceCategory) {
        updatePreferences { prefs in
            if let index = prefs.collapsedSidebarCategories.firstIndex(of: category) {
                prefs.collapsedSidebarCategories.remove(at: index)
            } else {
                prefs.collapsedSidebarCategories.append(category)
            }
        }
    }

    func renameSidebarCategory(_ category: WorkspaceCategory, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        updatePreferences { prefs in
            if trimmed.isEmpty || trimmed == category.defaultTitle {
                prefs.customSidebarCategoryTitles.removeValue(forKey: category)
            } else {
                prefs.customSidebarCategoryTitles[category] = trimmed
            }
        }
    }

    func removeWorkspace(workspaceID: UUID) {
        guard state.workspaces.count > 1 else { return }
        state.workspaces.removeAll { $0.id == workspaceID }
        if state.selectedWorkspaceID == workspaceID {
            state.selectedWorkspaceID = state.workspaces.first?.id
        }
        state.attentionItems.removeAll { $0.workspaceID == workspaceID }
        save()
    }

    func addTab() {
        guard let workspaceID = state.selectedWorkspaceID else { return }
        let mergedEnv = effectiveEnvironmentVariables
        updateWorkspace(id: workspaceID) { workspace in
            let session = TerminalSession(
                title: "Terminal",
                workingDirectory: workspace.rootDirectory,
                environment: mergedEnv.isEmpty ? nil : mergedEnv
            )
            let tab = TerminalTab(
                title: "Terminal \(workspace.tabs.count + 1)",
                root: .terminal(session),
                focusedSessionID: session.id
            )
            workspace.tabs.append(tab)
            workspace.selectedTabID = tab.id
        }
        zoomedSessionID = nil
        save()
    }

    func selectTab(_ tabID: UUID) {
        guard let workspaceID = state.selectedWorkspaceID else { return }
        updateWorkspace(id: workspaceID) { $0.selectedTabID = tabID }
        zoomedSessionID = nil
        save()
    }

    func toggleZoomFocusedPane() {
        guard let tab = selectedTab else { return }
        guard tab.root.terminalIDs.count > 1 else {
            zoomedSessionID = nil
            return
        }
        if zoomedSessionID == tab.focusedSessionID {
            zoomedSessionID = nil
        } else {
            zoomedSessionID = tab.focusedSessionID
        }
    }

    func closeTab(_ tabID: UUID) {
        guard let workspaceID = state.selectedWorkspaceID else { return }
        updateWorkspace(id: workspaceID) { workspace in
            guard workspace.tabs.count > 1,
                  let index = workspace.tabs.firstIndex(where: { $0.id == tabID }) else { return }
            let sessionIDs = workspace.tabs[index].root.terminalIDs
            sessionIDs.forEach { TerminalRegistry.shared.terminate(sessionID: $0) }
            workspace.tabs.remove(at: index)
            if workspace.selectedTabID == tabID {
                workspace.selectedTabID = workspace.tabs[min(index, workspace.tabs.count - 1)].id
            }
        }
        save()
    }

    func focusSession(_ sessionID: UUID) {
        guard let workspaceID = state.selectedWorkspaceID,
              let wsIndex = state.workspaces.firstIndex(where: { $0.id == workspaceID }),
              let tabIndex = state.workspaces[wsIndex].tabs.firstIndex(where: { $0.id == state.workspaces[wsIndex].selectedTabID }),
              state.workspaces[wsIndex].tabs[tabIndex].focusedSessionID != sessionID else { return }
        state.workspaces[wsIndex].tabs[tabIndex].focusedSessionID = sessionID
    }

    func splitFocused(axis: SplitAxis) {
        guard let workspaceID = state.selectedWorkspaceID else { return }
        let mergedEnv = effectiveEnvironmentVariables
        updateWorkspace(id: workspaceID) { workspace in
            guard let index = workspace.tabs.firstIndex(where: { $0.id == workspace.selectedTabID }) else { return }
            let focusedID = workspace.tabs[index].focusedSessionID
            let directory = workspace.tabs[index].root.session(id: focusedID)?.workingDirectory ?? workspace.rootDirectory
            let newSession = TerminalSession(
                title: "Terminal",
                workingDirectory: directory,
                environment: mergedEnv.isEmpty ? nil : mergedEnv
            )
            workspace.tabs[index].root = workspace.tabs[index].root.splitting(
                sessionID: focusedID,
                axis: axis,
                newSession: newSession
            )
            workspace.tabs[index].focusedSessionID = newSession.id
        }
        save()
    }

    func closeFocusedPane() {
        guard let workspaceID = state.selectedWorkspaceID else { return }
        updateWorkspace(id: workspaceID) { workspace in
            guard let index = workspace.tabs.firstIndex(where: { $0.id == workspace.selectedTabID }) else { return }
            let tab = workspace.tabs[index]
            guard tab.root.terminalIDs.count > 1 else { return }
            TerminalRegistry.shared.terminate(sessionID: tab.focusedSessionID)
            guard let updatedRoot = tab.root.removing(sessionID: tab.focusedSessionID) else { return }
            workspace.tabs[index].root = updatedRoot
            workspace.tabs[index].focusedSessionID = updatedRoot.terminalIDs[0]
        }
        save()
    }

    func updateSession(_ sessionID: UUID, persist: Bool = true, transform: (inout TerminalSession) -> Void) {
        var didChange = false
        for wsIndex in state.workspaces.indices {
            for tabIndex in state.workspaces[wsIndex].tabs.indices where state.workspaces[wsIndex].tabs[tabIndex].root.terminalIDs.contains(sessionID) {
                guard let existing = state.workspaces[wsIndex].tabs[tabIndex].root.session(id: sessionID) else { continue }
                var candidate = existing
                transform(&candidate)
                guard candidate != existing else { continue }
                didChange = true
                state.workspaces[wsIndex].tabs[tabIndex].root = state.workspaces[wsIndex].tabs[tabIndex].root.replacingSession(id: sessionID) { _ in
                    candidate
                }
            }
        }
        if didChange && persist {
            save()
        }
    }

    func terminalDidStart(sessionID: UUID) {
        updateSession(sessionID, persist: false) { $0.status = .running }
    }

    func terminalDidChangeTitle(sessionID: UUID, title: String) {
        let cleanTitle = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !cleanTitle.isEmpty else { return }
        updateSession(sessionID, persist: false) { $0.title = cleanTitle }
    }

    func terminalDidChangeDirectory(sessionID: UUID, directory: String?) {
        guard let directory,
              let url = URL(string: directory),
              url.isFileURL else { return }
        let newPath = url.path
        updateSession(sessionID, persist: true) { $0.workingDirectory = newPath }
    }

    func terminalDidTerminate(sessionID: UUID, exitCode: Int32?) {
        let owningWorkspaceID = state.workspaces.first { ws in
            ws.tabs.contains { $0.root.terminalIDs.contains(sessionID) }
        }?.id ?? state.selectedWorkspaceID
        guard let workspaceID = owningWorkspaceID else { return }
        updateSession(sessionID) { session in
            session.status = exitCode == 0 ? .completed : .failed
            session.lastExitCode = exitCode
        }
        let succeeded = exitCode == 0
        state.attentionItems.insert(
            AttentionItem(
                workspaceID: workspaceID,
                sessionID: sessionID,
                kind: succeeded ? .success : .failure,
                title: succeeded ? "Session completed" : "Session exited",
                detail: exitCode.map { "Exit code \($0)" } ?? "The process ended unexpectedly."
            ),
            at: 0
        )
        save()
    }

    func focusAttentionItem(_ item: AttentionItem) {
        selectWorkspace(item.workspaceID)
        if let sessionID = item.sessionID {
            updateWorkspace(id: item.workspaceID) { workspace in
                if let tab = workspace.tabs.first(where: { $0.root.terminalIDs.contains(sessionID) }) {
                    workspace.selectedTabID = tab.id
                    if let index = workspace.tabs.firstIndex(where: { $0.id == tab.id }) {
                        workspace.tabs[index].focusedSessionID = sessionID
                    }
                }
            }
        }
        if let index = state.attentionItems.firstIndex(where: { $0.id == item.id }) {
            state.attentionItems[index].isRead = true
        }
        save()
    }

    func respondToAttentionItem(_ item: AttentionItem, input: String) {
        if let sessionID = item.sessionID {
            TerminalRegistry.shared.send(input, to: sessionID, appendNewline: true)
        }
        focusAttentionItem(item)
    }

    func dismissAttentionItem(_ item: AttentionItem) {
        state.attentionItems.removeAll { $0.id == item.id }
        save()
    }

    func clearReadAttention() {
        state.attentionItems.removeAll { $0.isRead }
        save()
    }

    func markAllAttentionRead() {
        for index in state.attentionItems.indices {
            state.attentionItems[index].isRead = true
        }
        save()
    }

    func updatePreferences(_ transform: (inout AppPreferences) -> Void) {
        transform(&state.preferences)
        save()
    }

    var capsuleFileURL: URL? {
        guard let workspace = selectedWorkspace else { return nil }
        let root = URL(fileURLWithPath: workspace.rootDirectory)
        return capsuleStore.existingCapsuleURL(workspaceRoot: root)
            ?? capsuleStore.capsuleURL(workspaceRoot: root)
    }

    var dotEnvFileURL: URL? {
        guard let workspace = selectedWorkspace else { return nil }
        let root = URL(fileURLWithPath: workspace.rootDirectory, isDirectory: true)
        return capsuleStore.dotEnvURL(workspaceRoot: root)
    }

    var hasDotEnvFile: Bool {
        guard let url = dotEnvFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Merged environment variables for the active workspace (Manifest variables + Workspace custom variables).
    var effectiveEnvironmentVariables: [String: String] {
        var merged = capsule?.variables ?? [:]
        if let workspaceVars = selectedWorkspace?.environmentVariables {
            merged.merge(workspaceVars) { _, wsValue in wsValue }
        }
        return merged
    }

    @discardableResult
    func setEnvironmentVariable(key: String, value: String, applyToTerminal: Bool = false) -> String? {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanValue = value.replacingOccurrences(of: "\0", with: "")
        guard !trimmedKey.isEmpty else {
            return "Variable key cannot be empty."
        }
        guard CapsuleInspector.validVariableName(trimmedKey) else {
            return "'\(trimmedKey)' is not a valid shell variable name (use letters, digits, and underscores)."
        }
        guard !cleanValue.contains("\n") else {
            return "Variable value cannot contain newline characters."
        }
        guard let workspaceID = state.selectedWorkspaceID,
              let workspace = selectedWorkspace else {
            return "No active workspace selected."
        }

        updateWorkspace(id: workspaceID) { ws in
            ws.environmentVariables[trimmedKey] = cleanValue
        }
        save()

        // Also persist non-secret variables into .nathstar/manifest.json when a Manifest exists
        let isSecretKey = CapsuleInspector.appearsSecret(key: trimmedKey)
        if var updatedCapsule = capsule, !isSecretKey {
            updatedCapsule.variables[trimmedKey] = cleanValue
            let root = URL(fileURLWithPath: workspace.rootDirectory, isDirectory: true)
            try? capsuleStore.save(updatedCapsule, workspaceRoot: root)
            reloadCapsule()
        }

        if applyToTerminal,
           let focusedID = selectedTab?.focusedSessionID {
            TerminalRegistry.shared.applyEnvironmentSilently(effectiveEnvironmentVariables, to: focusedID)
            envStatusMessage = "Set & applied \(trimmedKey) silently to active terminal."
        } else if isSecretKey {
            envStatusMessage = "Saved \(trimmedKey) locally (excluded from manifest.json because it looks like a secret)."
        } else {
            envStatusMessage = "Saved \(trimmedKey)."
        }
        return nil
    }

    func removeEnvironmentVariable(key: String) {
        guard let workspaceID = state.selectedWorkspaceID,
              let workspace = selectedWorkspace else { return }
        updateWorkspace(id: workspaceID) { ws in
            ws.environmentVariables.removeValue(forKey: key)
        }
        save()

        if var updatedCapsule = capsule, updatedCapsule.variables[key] != nil {
            updatedCapsule.variables.removeValue(forKey: key)
            let root = URL(fileURLWithPath: workspace.rootDirectory, isDirectory: true)
            try? capsuleStore.save(updatedCapsule, workspaceRoot: root)
            reloadCapsule()
        }
        if let focusedID = selectedTab?.focusedSessionID {
            TerminalRegistry.shared.applyEnvironmentSilently(effectiveEnvironmentVariables, to: focusedID, unsetKeys: [key])
        }
        envStatusMessage = "Removed \(key)."
    }

    func applyEnvironmentToFocusedTerminal() {
        let vars = effectiveEnvironmentVariables
        guard !vars.isEmpty else {
            envStatusMessage = "No environment variables to apply."
            return
        }
        guard let focusedID = selectedTab?.focusedSessionID else { return }
        TerminalRegistry.shared.applyEnvironmentSilently(vars, to: focusedID)
        envStatusMessage = "Applied \(vars.count) variable\(vars.count == 1 ? "" : "s") silently to active terminal."
    }

    func exportEnvironmentToDotEnv(revealInFinder: Bool = false) {
        guard let workspaceID = state.selectedWorkspaceID,
              let workspace = selectedWorkspace else { return }
        let vars = effectiveEnvironmentVariables
        guard !vars.isEmpty else {
            envStatusMessage = "Add at least one variable before exporting to .env."
            return
        }
        do {
            let root = URL(fileURLWithPath: workspace.rootDirectory, isDirectory: true)
            let url = try capsuleStore.exportDotEnv(variables: vars, workspaceRoot: root)
            envStatusMessage = "Exported \(vars.count) variable\(vars.count == 1 ? "" : "s") to .env"
            state.attentionItems.insert(
                AttentionItem(
                    workspaceID: workspaceID,
                    kind: .information,
                    title: "Exported .env file",
                    detail: "Wrote \(vars.count) environment variable\(vars.count == 1 ? "" : "s") to \(url.path)."
                ),
                at: 0
            )
            save()
            if revealInFinder {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } catch {
            envStatusMessage = "Could not export .env: \(error.localizedDescription)"
        }
    }

    func importEnvironmentFromDotEnv() {
        guard let workspaceID = state.selectedWorkspaceID,
              let workspace = selectedWorkspace else { return }
        do {
            let root = URL(fileURLWithPath: workspace.rootDirectory, isDirectory: true)
            let imported = try capsuleStore.loadDotEnv(workspaceRoot: root)
            guard !imported.isEmpty else {
                envStatusMessage = "No valid KEY=VALUE pairs found in .env."
                return
            }
            updateWorkspace(id: workspaceID) { ws in
                ws.environmentVariables.merge(imported) { _, new in new }
            }
            save()

            if var updatedCapsule = capsule {
                for (k, v) in imported where !CapsuleInspector.appearsSecret(key: k) {
                    updatedCapsule.variables[k] = v
                }
                try? capsuleStore.save(updatedCapsule, workspaceRoot: root)
                reloadCapsule()
            }
            envStatusMessage = "Imported \(imported.count) variable\(imported.count == 1 ? "" : "s") from .env."
        } catch {
            envStatusMessage = "Could not read .env: \(error.localizedDescription)"
        }
    }

    func reloadCapsule() {
        guard let workspace = selectedWorkspace else {
            capsule = nil
            capsuleInspection = nil
            capsuleError = nil
            return
        }
        do {
            let root = URL(fileURLWithPath: workspace.rootDirectory, isDirectory: true)
            capsule = try capsuleStore.load(workspaceRoot: root)
            capsuleInspection = capsule.map {
                CapsuleInspector().inspect($0, workspaceRoot: root)
            }
            capsuleError = nil
        } catch {
            capsule = nil
            capsuleInspection = nil
            capsuleError = "Could not read .nathstar/manifest.json: \(error.localizedDescription)"
        }
    }

    func createCapsuleTemplate() {
        guard let workspace = selectedWorkspace else { return }
        do {
            let root = URL(fileURLWithPath: workspace.rootDirectory, isDirectory: true)
            let url = try capsuleStore.createTemplate(
                workspaceRoot: root,
                workspaceName: workspace.name,
                initialVariables: workspace.environmentVariables
            )
            reloadCapsule()
            envStatusMessage = "Created \(url.lastPathComponent)"
        } catch {
            capsuleError = "Could not create the manifest: \(error.localizedDescription)"
        }
    }

    func revealCapsule() {
        guard let url = capsuleFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func activateCapsule() {
        guard let workspaceID = state.selectedWorkspaceID,
              let workspace = selectedWorkspace,
              let capsule,
              capsuleInspection?.canActivate == true else { return }

        let commands = capsule.startupCommands + capsule.services
            .filter(\.autoStart)
            .map { CapsuleCommand(name: $0.name, command: $0.command, workingDirectory: $0.workingDirectory) }
        guard !commands.isEmpty else {
            state.attentionItems.insert(
                AttentionItem(
                    workspaceID: workspaceID,
                    kind: .information,
                    title: "Manifest has no startup commands",
                    detail: "Add a startup command or an auto-start service to manifest.json."
                ),
                at: 0
            )
            save()
            return
        }

        let rootURL = URL(fileURLWithPath: workspace.rootDirectory, isDirectory: true)
        let environment = effectiveEnvironmentVariables.merging([
            "NATHSTAR_MANIFEST": "1",
            "NATHSTAR_CAPSULE": "1",
            "NATHSTAR_WORKSPACE_ROOT": workspace.rootDirectory
        ]) { manifestValue, _ in manifestValue }
        let sessions = commands.map { command in
            TerminalSession(
                title: command.name,
                workingDirectory: CapsuleInspector.resolve(
                    directory: command.workingDirectory,
                    workspaceRoot: rootURL
                )?.path ?? workspace.rootDirectory,
                startupCommand: command.command,
                environment: environment
            )
        }
        guard let paneRoot = makeCapsulePaneTree(sessions: sessions, layout: capsule.layout) else { return }
        let tab = TerminalTab(
            title: "Manifest: \(capsule.name)",
            root: paneRoot,
            focusedSessionID: sessions[0].id
        )
        updateWorkspace(id: workspaceID) { target in
            target.tabs.append(tab)
            target.selectedTabID = tab.id
        }
        state.attentionItems.insert(
            AttentionItem(
                workspaceID: workspaceID,
                kind: .information,
                title: "Project manifest activated",
                detail: "Started \(sessions.count) command\(sessions.count == 1 ? "" : "s") for \(capsule.name)."
            ),
            at: 0
        )
        save()
        isCapsulePresented = false
    }

    func runCapsuleCommand(_ command: CapsuleCommand) {
        guard let workspaceID = state.selectedWorkspaceID,
              let workspace = selectedWorkspace,
              capsule != nil,
              capsuleInspection?.canActivate == true else { return }
        let rootURL = URL(fileURLWithPath: workspace.rootDirectory, isDirectory: true)
        let session = TerminalSession(
            title: command.name,
            workingDirectory: CapsuleInspector.resolve(
                directory: command.workingDirectory,
                workspaceRoot: rootURL
            )?.path ?? workspace.rootDirectory,
            startupCommand: command.command,
            environment: effectiveEnvironmentVariables.merging([
                "NATHSTAR_MANIFEST": "1",
                "NATHSTAR_CAPSULE": "1",
                "NATHSTAR_WORKSPACE_ROOT": workspace.rootDirectory
            ]) { manifestValue, _ in manifestValue }
        )
        let tab = TerminalTab(
            title: command.name,
            root: .terminal(session),
            focusedSessionID: session.id
        )
        updateWorkspace(id: workspaceID) { target in
            target.tabs.append(tab)
            target.selectedTabID = tab.id
        }
        save()
        isCapsulePresented = false
    }

    // MARK: - AI Assistant & Chat

    func toggleAIChat() {
        updatePreferences { $0.showAIChat.toggle() }
        if state.preferences.showAIChat && state.preferences.aiSettings.selectedProvider == .ollama {
            Task { await refreshOllamaModels() }
        }
    }

    func refreshOllamaModels() async {
        let baseURL = state.preferences.aiSettings.ollamaBaseURL
        do {
            let models = try await aiClient.fetchOllamaModels(baseURL: baseURL)
            self.ollamaModels = models
            if !models.isEmpty {
                let current = state.preferences.aiSettings.ollamaModel.trimmingCharacters(in: .whitespacesAndNewlines)
                if current.isEmpty || !models.contains(current) {
                    updatePreferences { $0.aiSettings.ollamaModel = models[0] }
                }
                aiStatusMessage = "Connected to Ollama (\(models.count) model\(models.count == 1 ? "" : "s") available)."
            } else {
                aiStatusMessage = "Connected to Ollama, but no models are installed (`ollama pull llama3.2`)."
            }
        } catch {
            self.ollamaModels = []
            aiStatusMessage = error.localizedDescription
        }
    }

    func sendAIChatMessage(_ rawPrompt: String) {
        let prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        let settings = state.preferences.aiSettings
        let userMessage = AIChatMessage(role: .user, content: prompt)
        state.chatMessages.append(userMessage)
        save()

        let conversationSnapshot = state.chatMessages
        let envSnapshot = effectiveEnvironmentVariables
        let wsContext: AIWorkspaceContext? = selectedWorkspace.map { ws in
            let focusedSession = selectedTab.flatMap { $0.root.session(id: $0.focusedSessionID) }
            return AIWorkspaceContext(
                workspaceName: ws.name,
                workingDirectory: focusedSession?.workingDirectory ?? ws.rootDirectory,
                gitBranch: workspaceTelemetry[ws.id]?.gitBranch,
                capsuleName: capsule?.name
            )
        }

        aiGenerationTask?.cancel()
        isGeneratingAIResponse = true
        let streamingID = UUID()
        let placeholderMessage = AIChatMessage(
            id: streamingID,
            role: .assistant,
            content: "",
            modelName: settings.activeModel,
            providerName: settings.selectedProvider.shortName
        )
        state.chatMessages.append(placeholderMessage)

        aiGenerationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let reply = try await aiClient.sendStreamingChat(
                    messages: conversationSnapshot,
                    settings: settings,
                    workspaceContext: wsContext,
                    environmentVariables: envSnapshot
                ) { [weak self] partial in
                    await MainActor.run {
                        guard let self,
                              let idx = self.state.chatMessages.firstIndex(where: { $0.id == streamingID }) else { return }
                        self.state.chatMessages[idx].content = partial
                    }
                }
                guard !Task.isCancelled else { return }
                if let idx = self.state.chatMessages.firstIndex(where: { $0.id == streamingID }) {
                    self.state.chatMessages[idx].content = reply
                }
                self.isGeneratingAIResponse = false
                self.save()
            } catch {
                guard !Task.isCancelled else { return }
                if let idx = self.state.chatMessages.firstIndex(where: { $0.id == streamingID }) {
                    self.state.chatMessages[idx].content = error.localizedDescription
                    self.state.chatMessages[idx].isError = true
                }
                self.isGeneratingAIResponse = false
                self.save()
            }
        }
    }

    func cancelAIGeneration() {
        aiGenerationTask?.cancel()
        aiGenerationTask = nil
        isGeneratingAIResponse = false
    }

    func clearAIChatHistory() {
        cancelAIGeneration()
        state.chatMessages.removeAll()
        save()
    }

    func sendCommandToFocusedTerminal(_ command: String, execute: Bool) {
        guard let sessionID = selectedTab?.focusedSessionID else { return }
        if execute {
            TerminalRegistry.shared.send(command, to: sessionID, appendNewline: true)
        } else {
            composerPrefillText = command
        }
    }

    /// Pulls the command currently typed on the active terminal prompt into the bottom
    /// Safe-Run text field so the user can edit it like a native macOS text field.
    func pullActiveTerminalLineIntoComposer() {
        guard let sessionID = selectedTab?.focusedSessionID else { return }
        let currentLine = TerminalRegistry.shared.readActiveCommandLine(sessionID: sessionID)
        if !currentLine.isEmpty {
            composerPrefillText = currentLine
        } else {
            composerPrefillText = ""
        }
    }

    // MARK: - One-Click Fix Failed Command & Inline AI Command Bar (⌘I)

    func handleCommandStatus(sessionID: UUID, event: FailedCommandEvent?) {
        if let event {
            failedCommandsBySession[sessionID] = event
        } else {
            failedCommandsBySession.removeValue(forKey: sessionID)
        }
    }

    func dismissFailedCommand(sessionID: UUID) {
        failedCommandsBySession.removeValue(forKey: sessionID)
    }

    func explainAndFixFailedCommand(sessionID: UUID) {
        guard let failed = failedCommandsBySession[sessionID] else { return }
        let recentOutput = TerminalRegistry.shared.readRecentOutput(sessionID: sessionID, maxLines: 35)
        updatePreferences { $0.showAIChat = true }
        let prompt = """
        My shell command failed with exit code \(failed.exitCode):
        `\(failed.command)`

        Recent terminal output:
        ```
        \(recentOutput.isEmpty ? "(no output captured)" : recentOutput)
        ```

        Briefly explain why it failed and provide the exact corrected zsh command in a ```zsh block.
        """
        failedCommandsBySession.removeValue(forKey: sessionID)
        sendAIChatMessage(prompt)
    }

    func sendRecentTerminalOutputToAI() {
        guard let sessionID = selectedTab?.focusedSessionID else { return }
        let recentOutput = TerminalRegistry.shared.readRecentOutput(sessionID: sessionID, maxLines: 45)
        updatePreferences { $0.showAIChat = true }
        let prompt = """
        Here is the recent output from my active terminal pane:
        ```
        \(recentOutput.isEmpty ? "(terminal buffer is currently empty)" : recentOutput)
        ```
        Summarize any issues or suggest the next command to run.
        """
        sendAIChatMessage(prompt)
    }

    func toggleInlineAIBar() {
        isInlineAIBarPresented.toggle()
        inlineAIError = nil
    }

    func generateInlineCommand(prompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let settings = state.preferences.aiSettings
        let envSnapshot = effectiveEnvironmentVariables
        let wsContext: AIWorkspaceContext? = selectedWorkspace.map { ws in
            let focusedSession = selectedTab.flatMap { $0.root.session(id: $0.focusedSessionID) }
            return AIWorkspaceContext(
                workspaceName: ws.name,
                workingDirectory: focusedSession?.workingDirectory ?? ws.rootDirectory,
                gitBranch: workspaceTelemetry[ws.id]?.gitBranch,
                capsuleName: capsule?.name
            )
        }

        inlineAITask?.cancel()
        isGeneratingInlineCommand = true
        inlineAIError = nil
        inlineAITask = Task { [weak self] in
            guard let self else { return }
            do {
                let command = try await aiClient.translateNaturalLanguageToCommand(
                    prompt: trimmed,
                    settings: settings,
                    workspaceContext: wsContext,
                    environmentVariables: envSnapshot
                )
                guard !Task.isCancelled else { return }
                self.composerPrefillText = command
                self.isGeneratingInlineCommand = false
                self.isInlineAIBarPresented = false
            } catch {
                guard !Task.isCancelled else { return }
                self.inlineAIError = error.localizedDescription
                self.isGeneratingInlineCommand = false
            }
        }
    }

    // MARK: - In-Terminal Search (⌘F) & Quick Links/Hints (⇧⌘L)

    func toggleTerminalSearch() {
        isTerminalSearchPresented.toggle()
        if isTerminalSearchPresented {
            performTerminalSearch()
        }
    }

    func performTerminalSearch() {
        guard let sessionID = selectedTab?.focusedSessionID else {
            terminalSearchMatches = []
            selectedSearchMatchIndex = 0
            return
        }
        let bufferText = TerminalRegistry.shared.readBufferText(sessionID: sessionID)
        terminalSearchMatches = TerminalBufferScanner.search(
            bufferText: bufferText,
            query: terminalSearchQuery,
            caseSensitive: terminalSearchCaseSensitive,
            useRegex: terminalSearchRegex
        )
        selectedSearchMatchIndex = terminalSearchMatches.isEmpty ? 0 : max(0, terminalSearchMatches.count - 1)
    }

    func nextSearchMatch() {
        guard !terminalSearchMatches.isEmpty else { return }
        selectedSearchMatchIndex = (selectedSearchMatchIndex + 1) % terminalSearchMatches.count
    }

    func previousSearchMatch() {
        guard !terminalSearchMatches.isEmpty else { return }
        selectedSearchMatchIndex = (selectedSearchMatchIndex - 1 + terminalSearchMatches.count) % terminalSearchMatches.count
    }

    func toggleQuickLinks() {
        if !isQuickLinksPresented {
            refreshDetectedItems()
        }
        isQuickLinksPresented.toggle()
    }

    func refreshDetectedItems() {
        guard let sessionID = selectedTab?.focusedSessionID else {
            detectedItems = []
            return
        }
        let dir = selectedTab?.root.session(id: sessionID)?.workingDirectory
            ?? selectedWorkspace?.rootDirectory
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        let bufferText = TerminalRegistry.shared.readBufferText(sessionID: sessionID)
        detectedItems = TerminalBufferScanner.detectItems(in: bufferText, workingDirectory: dir)
    }

    func openDetectedItem(_ item: DetectedTerminalItem) {
        switch item.kind {
        case .url, .endpoint:
            if let url = URL(string: item.value) {
                NSWorkspace.shared.open(url)
            }
        case .filePath:
            let fileURL = URL(fileURLWithPath: item.value)
            if let line = item.line {
                // Try opening at exact line in VS Code if `code` CLI is available, else default app
                let codePaths = ["/usr/local/bin/code", "/opt/homebrew/bin/code", "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"]
                if let codeBin = codePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: codeBin)
                    let target = item.column != nil ? "\(item.value):\(line):\(item.column!)" : "\(item.value):\(line)"
                    proc.arguments = ["-g", target]
                    try? proc.run()
                    return
                }
            }
            NSWorkspace.shared.open(fileURL)
        }
    }

    func copyFocusedTerminalOutput(maxLines: Int = 50) {
        guard let sessionID = selectedTab?.focusedSessionID else { return }
        let output = TerminalRegistry.shared.readRecentOutput(sessionID: sessionID, maxLines: maxLines)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }

    // MARK: - Tab Reordering & Split Equalizing

    func reorderTab(draggedTabID: UUID, targetTabID: UUID) {
        guard draggedTabID != targetTabID,
              let workspaceID = state.selectedWorkspaceID else { return }
        updateWorkspace(id: workspaceID) { workspace in
            guard let fromIndex = workspace.tabs.firstIndex(where: { $0.id == draggedTabID }),
                  let toIndex = workspace.tabs.firstIndex(where: { $0.id == targetTabID }) else { return }
            let moved = workspace.tabs.remove(at: fromIndex)
            workspace.tabs.insert(moved, at: toIndex)
        }
        save()
    }

    func equalizeSplits() {
        guard let workspaceID = state.selectedWorkspaceID else { return }
        updateWorkspace(id: workspaceID) { workspace in
            guard let index = workspace.tabs.firstIndex(where: { $0.id == workspace.selectedTabID }) else { return }
            workspace.tabs[index].root = workspace.tabs[index].root.equalizingSplits()
        }
        save()
    }

    // MARK: - Workflows / Snippets

    func addSnippet(title: String, command: String, category: String = "Custom", description: String = "") {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanCmd.isEmpty else { return }
        state.snippets.insert(
            CommandSnippet(title: cleanTitle, command: cleanCmd, category: category, description: description),
            at: 0
        )
        save()
    }

    func removeSnippet(id: UUID) {
        state.snippets.removeAll { $0.id == id }
        save()
    }

    func triggerSnippet(_ snippet: CommandSnippet, executeImmediately: Bool = false) {
        if snippet.placeholders.isEmpty && executeImmediately {
            sendCommandToFocusedTerminal(snippet.command, execute: true)
        } else {
            composerPrefillText = snippet.command
        }
    }

    // MARK: - SSH Host Manager

    var allSSHHosts: [SSHHostEntry] {
        var combined = state.sshHosts
        let existingAliases = Set(combined.map { $0.alias.lowercased() })
        for host in discoveredSSHHosts where !existingAliases.contains(host.alias.lowercased()) {
            combined.append(host)
        }
        return combined
    }

    func refreshSSHHosts() {
        discoveredSSHHosts = SSHConfigParser.parseDefaultSSHConfig()
    }

    func addSSHHost(alias: String, hostname: String, user: String?, port: Int?) {
        let cleanAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHost = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty else { return }
        let entry = SSHHostEntry(
            alias: cleanAlias.isEmpty ? cleanHost : cleanAlias,
            hostname: cleanHost,
            user: user?.trimmingCharacters(in: .whitespacesAndNewlines),
            port: port,
            isFromSSHConfig: false
        )
        state.sshHosts.insert(entry, at: 0)
        save()
    }

    func removeSSHHost(id: UUID) {
        state.sshHosts.removeAll { $0.id == id }
        save()
    }

    func connectSSHHost(_ host: SSHHostEntry, useSFTP: Bool = false) {
        guard let workspaceID = state.selectedWorkspaceID,
              let workspace = selectedWorkspace else { return }
        let cmd = useSFTP ? host.sftpCommand : host.sshCommand
        let label = useSFTP ? "SFTP: \(host.alias)" : "SSH: \(host.alias)"
        let session = TerminalSession(
            title: label,
            workingDirectory: workspace.rootDirectory,
            startupCommand: cmd,
            environment: effectiveEnvironmentVariables.isEmpty ? nil : effectiveEnvironmentVariables
        )
        let tab = TerminalTab(
            title: label,
            root: .terminal(session),
            focusedSessionID: session.id
        )
        updateWorkspace(id: workspaceID) { target in
            target.tabs.append(tab)
            target.selectedTabID = tab.id
        }
        zoomedSessionID = nil
        save()
    }

    // MARK: - Command Blocks & Autocomplete

    func recordCommandBlock(
        sessionID: UUID,
        command: String,
        workingDirectory: String,
        exitCode: Int32,
        durationMs: Int,
        outputSnippet: String
    ) {
        let owningWorkspaceID = state.workspaces.first { ws in
            ws.tabs.contains { $0.root.terminalIDs.contains(sessionID) }
        }?.id ?? state.selectedWorkspaceID ?? UUID()

        let block = CommandBlock(
            sessionID: sessionID,
            workspaceID: owningWorkspaceID,
            command: command,
            workingDirectory: workingDirectory,
            exitCode: exitCode,
            durationMs: durationMs,
            outputSnippet: outputSnippet
        )
        state.commandBlocks.insert(block, at: 0)
        if state.commandBlocks.count > 150 {
            state.commandBlocks = Array(state.commandBlocks.prefix(150))
        }

        if !cachedZshHistory.contains(command) {
            cachedZshHistory.insert(command, at: 0)
        }

        // Automatically notify Attention Center if a long-running command finishes
        let durationSeconds = Double(durationMs) / 1000.0
        if durationSeconds >= state.preferences.longRunningCommandThreshold {
            let succeeded = exitCode == 0
            state.attentionItems.insert(
                AttentionItem(
                    workspaceID: owningWorkspaceID,
                    sessionID: sessionID,
                    kind: succeeded ? .success : .failure,
                    title: succeeded
                        ? "Command completed (\(block.formattedDuration))"
                        : "Command failed (\(block.formattedDuration) · exit \(exitCode))",
                    detail: command
                ),
                at: 0
            )
        }

        if state.preferences.restoreScrollbackOnLaunch {
            let snapshot = TerminalRegistry.shared.readRecentOutput(sessionID: sessionID, maxLines: 50)
            if !snapshot.isEmpty {
                state.sessionScrollbackSnapshots[sessionID] = snapshot
            }
        }
        save()
        if state.preferences.showAttentionCenter && rightPanelTab == .ports {
            refreshLivePortsAndProcesses()
        }
    }

    // MARK: - Live Ports & Processes Manager

    func activeShellSessionInfos() -> [TerminalShellSessionInfo] {
        var infos: [TerminalShellSessionInfo] = []
        for ws in state.workspaces {
            for tab in ws.tabs {
                for sessionID in tab.root.terminalIDs {
                    guard let pid = TerminalRegistry.shared.shellPID(for: sessionID) else { continue }
                    let sessionTitle = tab.root.session(id: sessionID)?.title ?? tab.title
                    infos.append(
                        TerminalShellSessionInfo(
                            sessionID: sessionID,
                            sessionTitle: sessionTitle,
                            workspaceID: ws.id,
                            workspaceName: ws.name,
                            shellPID: pid
                        )
                    )
                }
            }
        }
        return infos
    }

    func refreshLivePortsAndProcesses() {
        let sessionInfos = activeShellSessionInfos()
        portScanTask?.cancel()
        isScanningPorts = true
        portScanTask = Task { [weak self] in
            let discovered = await Task.detached(priority: .utility) {
                LivePortScanner.scanLivePortsAndProcesses(sessions: sessionInfos)
            }.value
            guard !Task.isCancelled else { return }
            self?.livePortProcesses = discovered
            self?.isScanningPorts = false
        }
    }

    func killPortOrProcess(_ item: LivePortProcess, force: Bool = false) {
        let sig: Int32 = force ? SIGKILL : SIGTERM
        let result = Darwin.kill(item.pid, sig)
        if result == 0 {
            let targetDesc = item.port.map { "port :\($0) (\(item.processName), PID \(item.pid))" }
                ?? "\(item.processName) (PID \(item.pid))"
            portsStatusMessage = "Sent \(force ? "SIGKILL (-9)" : "SIGTERM") to \(targetDesc)."
        } else {
            portsStatusMessage = "Could not kill PID \(item.pid) (errno \(errno))."
        }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            self?.refreshLivePortsAndProcesses()
        }
    }

    func focusPortProcess(_ item: LivePortProcess) {
        guard let workspaceID = item.workspaceID,
              let sessionID = item.sessionID else { return }
        selectWorkspace(workspaceID)
        updateWorkspace(id: workspaceID) { workspace in
            if let tab = workspace.tabs.first(where: { $0.root.terminalIDs.contains(sessionID) }) {
                workspace.selectedTabID = tab.id
                if let index = workspace.tabs.firstIndex(where: { $0.id == tab.id }) {
                    workspace.tabs[index].focusedSessionID = sessionID
                }
            }
        }
        TerminalRegistry.shared.focus(sessionID: sessionID)
        save()
    }

    func openPortsPanel() {
        updatePreferences { $0.showAttentionCenter = true }
        rightPanelTab = .ports
        refreshLivePortsAndProcesses()
    }

    func commandBlocks(for sessionID: UUID) -> [CommandBlock] {
        state.commandBlocks.filter { $0.sessionID == sessionID }
    }

    func clearCommandBlocks(for sessionID: UUID? = nil) {
        if let sessionID {
            state.commandBlocks.removeAll { $0.sessionID == sessionID }
        } else {
            state.commandBlocks.removeAll()
        }
        save()
    }

    func explainCommandBlock(_ block: CommandBlock) {
        updatePreferences { $0.showAIChat = true }
        let statusDesc = block.exitCode == 0
            ? "succeeded in \(block.formattedDuration)"
            : "failed with exit code \(block.exitCode) after \(block.formattedDuration)"
        let prompt = """
        Analyze this terminal command Block (\(statusDesc) in `\(block.workingDirectory)`):
        `\(block.command)`

        Captured output:
        ```
        \(block.outputSnippet.isEmpty ? "(no output)" : block.outputSnippet)
        ```
        """
        sendAIChatMessage(prompt)
    }

    func autocompleteSuggestions(for input: String, workingDirectory: String) -> [AutocompleteSuggestion] {
        guard state.preferences.enableComposerAutocomplete else { return [] }
        return AutocompleteEngine.suggest(
            for: input,
            workingDirectory: workingDirectory,
            commandBlocks: state.commandBlocks,
            snippets: state.snippets,
            shellHistory: cachedZshHistory
        )
    }

    func persistImmediateSnapshotBeforeQuit() {
        saveTask?.cancel()
        if state.preferences.restoreScrollbackOnLaunch {
            let liveSnapshots = TerminalRegistry.shared.captureScrollbackSnapshots(maxLines: 50)
            for (sessionID, text) in liveSnapshots {
                state.sessionScrollbackSnapshots[sessionID] = text
            }
        }
        try? store?.save(state)
    }

    private func updateWorkspace(id: UUID, transform: (inout Workspace) -> Void) {
        guard let index = state.workspaces.firstIndex(where: { $0.id == id }) else { return }
        transform(&state.workspaces[index])
    }

    private func save() {
        guard let store else { return }
        let snapshot = state
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                try await Task.detached(priority: .utility) {
                    try store.save(snapshot)
                }.value
                self?.lastPersistenceError = nil
            } catch {
                self?.lastPersistenceError = error.localizedDescription
            }
        }
    }

    private static func initialState() -> NorthstarState {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let workspace = Workspace(name: "Home", rootDirectory: home, isPinned: true)
        return NorthstarState(workspaces: [workspace], selectedWorkspaceID: workspace.id)
    }

    func refreshTelemetry() {
        var updated: [UUID: WorkspaceTelemetry] = [:]
        let selectedID = state.selectedWorkspaceID
        for ws in state.workspaces {
            var info = WorkspaceTelemetry()
            info.gitBranch = readGitBranchFast(at: ws.rootDirectory)
            if ws.id == selectedID, let capsule, let capsuleInspection {
                let totalTools = capsuleInspection.tools.count
                let readyTools = capsuleInspection.tools.filter { $0.executablePath != nil }.count
                let totalChecks = max(totalTools + capsule.healthChecks.count, 1)
                let passedChecks = readyTools + (capsuleInspection.canActivate ? capsule.healthChecks.count : 0)
                info.capsuleTotalChecks = totalChecks
                info.capsuleHealthyCount = passedChecks
            }
            updated[ws.id] = info
        }
        if workspaceTelemetry != updated {
            workspaceTelemetry = updated
        }
    }
}

private func readGitBranchFast(at rootPath: String) -> String? {
    let headURL = URL(fileURLWithPath: rootPath)
        .appendingPathComponent(".git", isDirectory: true)
        .appendingPathComponent("HEAD", isDirectory: false)
    guard let raw = try? String(contentsOf: headURL, encoding: .utf8) else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("ref: refs/heads/") {
        return String(trimmed.dropFirst("ref: refs/heads/".count))
    }
    if trimmed.count >= 7 {
        return String(trimmed.prefix(7))
    }
    return nil
}

private func makeCapsulePaneTree(sessions: [TerminalSession], layout: CapsuleLayout) -> PaneNode? {
    guard let first = sessions.first else { return nil }
    return sessions.dropFirst().enumerated().reduce(PaneNode.terminal(first)) { node, item in
        let (index, session) = item
        let axis: SplitAxis
        switch layout {
        case .horizontal: axis = .horizontal
        case .vertical: axis = .vertical
        case .grid: axis = index.isMultiple(of: 2) ? .vertical : .horizontal
        }
        return .split(axis: axis, ratio: 0.5, first: node, second: .terminal(session))
    }
}

private func resetSessionStates(in node: PaneNode, workspaceRoot: String) -> PaneNode {
    switch node {
    case .terminal(let session):
        var reset = session
        reset.status = .starting
        reset.lastExitCode = nil
        var isDir: ObjCBool = false
        let stdRoot = URL(fileURLWithPath: workspaceRoot).standardizedFileURL.path
        let stdSessionDir = URL(fileURLWithPath: reset.workingDirectory).standardizedFileURL.path
        let dirExists = FileManager.default.fileExists(atPath: stdSessionDir, isDirectory: &isDir) && isDir.boolValue
        let isInsideWorkspace = stdSessionDir == stdRoot || stdSessionDir.hasPrefix(stdRoot + "/")
        if !dirExists || !isInsideWorkspace {
            reset.workingDirectory = workspaceRoot
        }
        return .terminal(reset)
    case .split(let axis, let ratio, let first, let second):
        return .split(
            axis: axis,
            ratio: ratio,
            first: resetSessionStates(in: first, workspaceRoot: workspaceRoot),
            second: resetSessionStates(in: second, workspaceRoot: workspaceRoot)
        )
    }
}
