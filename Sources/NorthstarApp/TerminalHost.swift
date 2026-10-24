import AppKit
import Darwin
import NorthstarCore
import SwiftUI
@preconcurrency import SwiftTerm

@MainActor
final class TerminalRegistry {
    static let shared = TerminalRegistry()

    private var terminals: [UUID: LocalProcessTerminalView] = [:]
    private let silentEnvDirURL: URL = {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nathstar-env-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func existing(sessionID: UUID) -> LocalProcessTerminalView? {
        terminals[sessionID]
    }

    func contains(sessionID: UUID) -> Bool {
        terminals[sessionID] != nil
    }

    func register(_ terminal: LocalProcessTerminalView, sessionID: UUID) {
        terminals[sessionID] = terminal
    }

    func shellPID(for sessionID: UUID) -> Int32? {
        guard let terminal = terminals[sessionID],
              terminal.process.running,
              terminal.process.shellPid > 0 else {
            return nil
        }
        return Int32(terminal.process.shellPid)
    }

    func envFileURL(for sessionID: UUID) -> URL {
        silentEnvDirURL.appendingPathComponent("\(sessionID.uuidString).sh")
    }

    func statusFileURL(for sessionID: UUID) -> URL {
        silentEnvDirURL.appendingPathComponent("\(sessionID.uuidString).status")
    }

    func readBufferText(sessionID: UUID) -> String {
        guard let terminal = terminals[sessionID] else { return "" }
        let data = terminal.getTerminal().getBufferAsData(kind: .active, encoding: .utf8)
        guard let raw = String(data: data, encoding: .utf8) else { return "" }
        return raw
    }

    func readRecentOutput(sessionID: UUID, maxLines: Int = 50) -> String {
        let full = readBufferText(sessionID: sessionID)
        let lines = full
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.suffix(maxLines).joined(separator: "\n")
    }

    func captureScrollbackSnapshots(maxLines: Int = 60) -> [UUID: String] {
        var snapshots: [UUID: String] = [:]
        for (id, _) in terminals {
            let recent = readRecentOutput(sessionID: id, maxLines: maxLines)
            if !recent.isEmpty {
                snapshots[id] = recent
            }
        }
        return snapshots
    }

    func feedRestoredSnapshot(_ snapshot: String, to terminal: LocalProcessTerminalView) {
        let cleanLines = snapshot
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .suffix(40)
        guard !cleanLines.isEmpty else { return }
        let banner = "\u{1b}[90m── Restored Previous Session Output ──\r\n"
        let body = cleanLines.joined(separator: "\r\n")
        let footer = "\r\n──────────────────────────────────────\u{1b}[0m\r\n"
        terminal.feed(text: banner + body + footer)
    }

    func readActiveCommandLine(sessionID: UUID) -> String {
        guard let terminal = terminals[sessionID] else { return "" }
        return terminal.getTerminal().getActiveCommandLineText()
    }

    /// Replaces the currently typed command in the active shell line (using Ctrl+E + Ctrl+U to clear
    /// any existing partial input) and either leaves it in the prompt for further editing or executes it.
    func replaceActiveCommandLine(sessionID: UUID, with text: String, execute: Bool) {
        guard let terminal = terminals[sessionID] else { return }
        let payload = "\u{05}\u{15}" + text + (execute ? "\n" : "")
        let bytes = Array(payload.utf8)
        terminal.send(source: terminal, data: bytes[...])
        terminal.window?.makeFirstResponder(terminal)
    }

    /// Writes `export KEY='VALUE'` lines to a private session file and optionally signals `SIGUSR1` to the shell
    /// so the live shell loads the variables silently without printing anything in the terminal window.
    func applyEnvironmentSilently(_ variables: [String: String], to sessionID: UUID, unsetKeys: [String] = [], signalRunningShell: Bool = true) {
        let validPairs = variables
            .filter { CapsuleInspector.validVariableName($0.key) }
            .sorted { $0.key < $1.key }
        var lines = unsetKeys
            .filter { CapsuleInspector.validVariableName($0) }
            .map { "unset \($0)" }
        lines.append(contentsOf: validPairs.map { key, value -> String in
            let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
            return "export \(key)='\(escaped)'"
        })
        let payload = lines.joined(separator: "\n") + "\n"
        let fileURL = envFileURL(for: sessionID)
        try? payload.write(to: fileURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)

        guard signalRunningShell,
              let terminal = terminals[sessionID],
              terminal.process.running,
              terminal.process.shellPid > 0 else { return }
        kill(terminal.process.shellPid, SIGUSR1)
    }

    func send(_ text: String, to sessionID: UUID, appendNewline: Bool = true) {
        guard let terminal = terminals[sessionID] else { return }
        let payload = appendNewline ? text + "\n" : text
        let bytes = Array(payload.utf8)
        terminal.send(source: terminal, data: bytes[...])
        terminal.window?.makeFirstResponder(terminal)
    }

    func focus(sessionID: UUID) {
        guard let terminal = terminals[sessionID] else { return }
        terminal.window?.makeFirstResponder(terminal)
    }

    func terminate(sessionID: UUID) {
        try? FileManager.default.removeItem(at: envFileURL(for: sessionID))
        try? FileManager.default.removeItem(at: statusFileURL(for: sessionID))
        guard let terminal = terminals.removeValue(forKey: sessionID) else { return }
        terminal.processDelegate = nil
        terminal.terminate()
        terminal.removeFromSuperview()
    }

    func terminateAll() {
        let sessionIDs = Array(terminals.keys)
        sessionIDs.forEach(terminate(sessionID:))
    }

    /// Creates a lightweight ZDOTDIR shim that sources the user's real zsh dotfiles and installs a silent `TRAPUSR1`
    /// handler so environment variable updates never print `export ...` into the terminal buffer, plus `preexec`/`precmd`
    /// hooks to track command exit codes for One-Click AI Error Fixing.
    func prepareSilentZshDotDir(userHome: String, existingZdotDir: String?) -> String {
        let shimDir = silentEnvDirURL.appendingPathComponent("zdotdir", isDirectory: true)
        try? FileManager.default.createDirectory(at: shimDir, withIntermediateDirectories: true)
        var realZdot = (existingZdotDir?.isEmpty == false) ? existingZdotDir! : userHome
        if realZdot == shimDir.path || realZdot.contains("/nathstar-env-") {
            realZdot = userHome
        }

        let zshenv = """
        export ZDOTDIR="\(realZdot)"
        if [[ -f "\(realZdot)/.zshenv" ]]; then source "\(realZdot)/.zshenv"; fi
        export ZDOTDIR="\(shimDir.path)"
        """
        let zprofile = """
        export ZDOTDIR="\(realZdot)"
        if [[ -f "\(realZdot)/.zprofile" ]]; then source "\(realZdot)/.zprofile"; fi
        export ZDOTDIR="\(shimDir.path)"
        """
        let zshrc = """
        export ZDOTDIR="\(realZdot)"
        if [[ -f "\(realZdot)/.zshrc" ]]; then source "\(realZdot)/.zshrc"; fi
        zmodload zsh/datetime 2>/dev/null
        __nathstar_last_cmd=""
        __nathstar_cmd_start="0"
        __nathstar_load_env() {
            if [[ -n "$NATHSTAR_ENV_FILE" && -f "$NATHSTAR_ENV_FILE" ]]; then
                source "$NATHSTAR_ENV_FILE" >/dev/null 2>&1
            fi
        }
        __nathstar_preexec() {
            __nathstar_last_cmd="$1"
            __nathstar_cmd_start="${EPOCHREALTIME:-0}"
            printf '\\e]133;C\\a'
            __nathstar_load_env
        }
        __nathstar_precmd() {
            local exit_code=$?
            local end_time="${EPOCHREALTIME:-0}"
            if [[ -n "$__nathstar_last_cmd" && -n "$NATHSTAR_STATUS_FILE" ]]; then
                printf "%s\\t%s\\t%s\\t%s\\t%s\\n" "$exit_code" "$__nathstar_cmd_start" "$end_time" "$PWD" "$__nathstar_last_cmd" >| "$NATHSTAR_STATUS_FILE" 2>/dev/null
            fi
            __nathstar_last_cmd=""
        }
        if (( $+widgets[zle-line-init] )); then
            functions -c "${widgets[zle-line-init]#user:}" __nathstar_orig_zle_line_init 2>/dev/null
        fi
        __nathstar_zle_line_init() {
            if (( $+functions[__nathstar_orig_zle_line_init] )); then
                __nathstar_orig_zle_line_init "$@"
            fi
            printf '\\e]133;P;k=i;cl=m\\a\\e]133;B\\a'
        }
        zle -N zle-line-init __nathstar_zle_line_init 2>/dev/null
        TRAPUSR1() {
            __nathstar_load_env
        }
        autoload -Uz add-zsh-hook 2>/dev/null
        add-zsh-hook preexec __nathstar_preexec
        add-zsh-hook precmd __nathstar_precmd
        __nathstar_load_env
        """
        let zlogin = """
        export ZDOTDIR="\(realZdot)"
        if [[ -f "\(realZdot)/.zlogin" ]]; then source "\(realZdot)/.zlogin"; fi
        """

        try? zshenv.write(to: shimDir.appendingPathComponent(".zshenv"), atomically: true, encoding: .utf8)
        try? zprofile.write(to: shimDir.appendingPathComponent(".zprofile"), atomically: true, encoding: .utf8)
        try? zshrc.write(to: shimDir.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
        try? zlogin.write(to: shimDir.appendingPathComponent(".zlogin"), atomically: true, encoding: .utf8)
        return shimDir.path
    }
}

final class NathstarTerminalView: LocalProcessTerminalView {
    private var didLaunchShell = false
    private var pendingLaunch: (() -> Void)?

    func scheduleShellLaunch(_ launch: @escaping () -> Void) {
        guard !didLaunchShell else { return }
        if frame.width > 10 && frame.height > 10 {
            didLaunchShell = true
            launch()
        } else {
            pendingLaunch = launch
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        triggerPendingLaunchIfReady()
    }

    override func layout() {
        super.layout()
        triggerPendingLaunchIfReady()
    }

    private func triggerPendingLaunchIfReady() {
        guard !didLaunchShell,
              frame.width > 10,
              frame.height > 10,
              let launch = pendingLaunch else { return }
        didLaunchShell = true
        pendingLaunch = nil
        launch()
    }
}

struct TerminalPaneView: NSViewRepresentable, Equatable {
    let session: TerminalSession
    let preferences: AppPreferences
    var restoredSnapshot: String? = nil
    let onStart: () -> Void
    let onFocus: () -> Void
    let onTitleChange: (String) -> Void
    let onDirectoryChange: (String?) -> Void
    let onTermination: (Int32?) -> Void
    var onCommandStatus: ((FailedCommandEvent?) -> Void)? = nil
    var onCommandCompleted: ((String, String, Int32, Int, String) -> Void)? = nil

    nonisolated static func == (lhs: TerminalPaneView, rhs: TerminalPaneView) -> Bool {
        lhs.session.id == rhs.session.id
            && lhs.preferences.fontName == rhs.preferences.fontName
            && lhs.preferences.fontSize == rhs.preferences.fontSize
            && lhs.preferences.theme == rhs.preferences.theme
            && lhs.preferences.cursorStyle == rhs.preferences.cursorStyle
            && lhs.preferences.useMetalRenderer == rhs.preferences.useMetalRenderer
            && abs(lhs.preferences.backgroundOpacity - rhs.preferences.backgroundOpacity) < 0.01
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        if let existing = TerminalRegistry.shared.existing(sessionID: session.id) {
            existing.removeFromSuperview()
            existing.processDelegate = context.coordinator
            configure(existing, coordinator: context.coordinator)
            context.coordinator.startStatusMonitoring(sessionID: session.id)
            DispatchQueue.main.async {
                existing.window?.makeFirstResponder(existing)
            }
            return existing
        }

        let font = terminalFont
        let options = TerminalOptions(
            cursorStyle: swiftTermCursorStyle(preferences.cursorStyle),
            scrollback: max(500, preferences.scrollbackLines)
        )
        let terminal = NathstarTerminalView(frame: .zero, font: font, options: options)
        terminal.processDelegate = context.coordinator
        configure(terminal, coordinator: context.coordinator)
        TerminalRegistry.shared.register(terminal, sessionID: session.id)
        context.coordinator.startStatusMonitoring(sessionID: session.id)

        let session = self.session
        let preferences = self.preferences
        let restoredSnapshot = self.restoredSnapshot
        let onStart = self.onStart
        terminal.scheduleShellLaunch { [weak terminal] in
            guard let terminal else { return }
            if preferences.restoreScrollbackOnLaunch,
               let snapshot = restoredSnapshot,
               !snapshot.isEmpty {
                TerminalRegistry.shared.feedRestoredSnapshot(snapshot, to: terminal)
            }
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            let shellName = URL(fileURLWithPath: shell).lastPathComponent
            var processEnvironment = ProcessInfo.processInfo.environment
            processEnvironment["TERM"] = "xterm-256color"
            processEnvironment["COLORTERM"] = "truecolor"
            let sessionEnvFile = TerminalRegistry.shared.envFileURL(for: session.id)
            let sessionStatusFile = TerminalRegistry.shared.statusFileURL(for: session.id)
            processEnvironment["NATHSTAR_ENV_FILE"] = sessionEnvFile.path
            processEnvironment["NATHSTAR_STATUS_FILE"] = sessionStatusFile.path
            if shellName == "zsh" {
                let userHome = processEnvironment["HOME"] ?? FileManager.default.homeDirectoryForCurrentUser.path
                processEnvironment["ZDOTDIR"] = TerminalRegistry.shared.prepareSilentZshDotDir(
                    userHome: userHome,
                    existingZdotDir: processEnvironment["ZDOTDIR"]
                )
            }
            processEnvironment.merge(session.environment ?? [:]) { _, capsuleValue in capsuleValue }
            if let initialVars = session.environment, !initialVars.isEmpty {
                TerminalRegistry.shared.applyEnvironmentSilently(
                    initialVars,
                    to: session.id,
                    signalRunningShell: false
                )
            }
            let workingDirectory = FileManager.default.fileExists(atPath: session.workingDirectory)
                ? session.workingDirectory
                : FileManager.default.homeDirectoryForCurrentUser.path

            let tmuxCandidates = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux"]
            if preferences.enablePersistentTmuxSessions,
               session.startupCommand == nil,
               let tmuxBin = tmuxCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
                let shortID = String(session.id.uuidString.prefix(8)).lowercased()
                terminal.startProcess(
                    executable: tmuxBin,
                    args: ["new-session", "-A", "-s", "nathstar-\(shortID)", "-c", workingDirectory],
                    environment: processEnvironment.map { "\($0.key)=\($0.value)" }.sorted(),
                    execName: "tmux",
                    currentDirectory: workingDirectory
                )
            } else {
                terminal.startProcess(
                    executable: shell,
                    args: ["-l"],
                    environment: processEnvironment.map { "\($0.key)=\($0.value)" }.sorted(),
                    execName: "-\(shellName)",
                    currentDirectory: workingDirectory
                )
            }
            onStart()
            DispatchQueue.main.async {
                if preferences.useMetalRenderer {
                    try? terminal.setUseMetal(true)
                }
                terminal.window?.makeFirstResponder(terminal)
            }
            if let startupCommand = session.startupCommand {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    guard TerminalRegistry.shared.contains(sessionID: session.id) else { return }
                    TerminalRegistry.shared.send(startupCommand, to: session.id)
                }
            }
        }
        return terminal
    }

    func updateNSView(_ terminal: LocalProcessTerminalView, context: Context) {
        context.coordinator.parent = self
        if terminal.processDelegate !== context.coordinator {
            terminal.processDelegate = context.coordinator
        }
        configure(terminal, coordinator: context.coordinator)
    }

    static func dismantleNSView(_ terminal: LocalProcessTerminalView, coordinator: Coordinator) {
        terminal.processDelegate = nil
        coordinator.stopStatusMonitoring()
    }

    private var terminalFont: NSFont {
        NSFont(name: preferences.fontName, size: preferences.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: preferences.fontSize, weight: .regular)
    }

    private func swiftTermCursorStyle(_ style: TerminalCursorStyle) -> CursorStyle {
        switch style {
        case .blinkBlock: return .blinkBlock
        case .steadyBlock: return .steadyBlock
        case .blinkBar: return .blinkBar
        case .steadyBar: return .steadyBar
        case .blinkUnderline: return .blinkUnderline
        case .steadyUnderline: return .steadyUnderline
        }
    }

    private func nsColor(_ rgb: NorthstarCore.RGBColor, alpha: Double = 1.0) -> NSColor {
        NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: alpha)
    }

    private func swiftTermColor(_ rgb: NorthstarCore.RGBColor) -> SwiftTerm.Color {
        SwiftTerm.Color(
            red8: UInt16(max(0, min(255, Int(rgb.red * 255.0 + 0.5)))),
            green8: UInt16(max(0, min(255, Int(rgb.green * 255.0 + 0.5)))),
            blue8: UInt16(max(0, min(255, Int(rgb.blue * 255.0 + 0.5))))
        )
    }

    private func configure(_ terminal: LocalProcessTerminalView, coordinator: Coordinator) {
        if coordinator.appliedFontName != preferences.fontName
            || abs(coordinator.appliedFontSize - preferences.fontSize) > 0.1 {
            coordinator.appliedFontName = preferences.fontName
            coordinator.appliedFontSize = preferences.fontSize
            terminal.font = terminalFont
        }

        if coordinator.appliedTheme != preferences.theme
            || abs(coordinator.appliedOpacity - preferences.backgroundOpacity) > 0.01 {
            coordinator.appliedTheme = preferences.theme
            coordinator.appliedOpacity = preferences.backgroundOpacity

            let palette = preferences.theme.palette
            let opacity = max(0.65, min(1.0, preferences.backgroundOpacity))
            terminal.nativeForegroundColor = nsColor(palette.foreground)
            terminal.nativeBackgroundColor = nsColor(palette.background, alpha: opacity)
            terminal.backgroundOpacity = CGFloat(opacity)
            terminal.caretColor = nsColor(palette.caret)
            terminal.selectedTextBackgroundColor = nsColor(palette.selection)
            if palette.ansiColors.count == 16 {
                terminal.installColors(palette.ansiColors.map(swiftTermColor))
            }
            terminal.layer?.backgroundColor = terminal.nativeBackgroundColor.cgColor
            if let window = terminal.window {
                window.isOpaque = opacity >= 0.99
                window.alphaValue = CGFloat(max(0.75, min(1.0, opacity)))
            }
        }

        if coordinator.appliedCursorStyle != preferences.cursorStyle {
            coordinator.appliedCursorStyle = preferences.cursorStyle
            terminal.getTerminal().setCursorStyle(swiftTermCursorStyle(preferences.cursorStyle))
        }

        if terminal.window != nil && coordinator.appliedUseMetal != preferences.useMetalRenderer {
            coordinator.appliedUseMetal = preferences.useMetalRenderer
            try? terminal.setUseMetal(preferences.useMetalRenderer)
        }
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency LocalProcessTerminalViewDelegate {
        var parent: TerminalPaneView
        var appliedFontName: String = ""
        var appliedFontSize: Double = 0
        var appliedTheme: TerminalThemePreset?
        var appliedCursorStyle: TerminalCursorStyle?
        var appliedOpacity: Double = -1
        var appliedUseMetal: Bool?
        private var lastTitle: String = ""
        private var lastDirectory: String?
        private var statusTimer: Timer?
        private var lastSeenStatusToken: String = ""

        init(parent: TerminalPaneView) {
            self.parent = parent
        }

        @MainActor
        func startStatusMonitoring(sessionID: UUID) {
            statusTimer?.invalidate()
            let fileURL = TerminalRegistry.shared.statusFileURL(for: sessionID)
            statusTimer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.checkStatusFile(fileURL: fileURL, sessionID: sessionID)
                }
            }
        }

        @MainActor
        func stopStatusMonitoring() {
            statusTimer?.invalidate()
            statusTimer = nil
        }

        @MainActor
        private func checkStatusFile(fileURL: URL, sessionID: UUID) {
            guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != lastSeenStatusToken else { return }
            lastSeenStatusToken = trimmed

            let parts = trimmed.split(separator: "\t", maxSplits: 4).map(String.init)
            guard parts.count >= 5,
                  let exitCode = Int32(parts[0]) else { return }
            let startEpoch = Double(parts[1]) ?? 0
            let endEpoch = Double(parts[2]) ?? startEpoch
            let pwd = parts[3]
            let command = parts[4].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty else { return }

            let durationMs = startEpoch > 0 && endEpoch >= startEpoch
                ? max(1, Int(((endEpoch - startEpoch) * 1000.0).rounded()))
                : 10
            let outputSnippet = TerminalRegistry.shared.readRecentOutput(sessionID: sessionID, maxLines: 25)

            parent.onCommandCompleted?(command, pwd, exitCode, durationMs, outputSnippet)

            if exitCode != 0 && exitCode != 130 {
                // Non-zero exit (ignore 130 which is intentional Ctrl+C)
                parent.onCommandStatus?(
                    FailedCommandEvent(
                        sessionID: sessionID,
                        command: command,
                        exitCode: exitCode,
                        durationMs: durationMs
                    )
                )
            } else {
                parent.onCommandStatus?(nil)
            }
        }

        @MainActor
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        @MainActor
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            guard title != lastTitle else { return }
            lastTitle = title
            parent.onTitleChange(title)
        }

        @MainActor
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            guard directory != lastDirectory else { return }
            lastDirectory = directory
            parent.onDirectoryChange(directory)
        }

        @MainActor
        func processTerminated(source: TerminalView, exitCode: Int32?) {
            parent.onTermination(exitCode)
        }
    }
}
