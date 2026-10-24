import AppKit
import NorthstarCore
import SwiftUI

struct AIChatPanelView: View {
    @EnvironmentObject private var model: AppModel
    @State private var inputText = ""
    @State private var showQuickConfig = false
    @FocusState private var isInputFocused: Bool

    private var aiSettings: AISettings {
        model.state.preferences.aiSettings
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().opacity(0.5)
            providerControlsBar
            if showQuickConfig {
                Divider().opacity(0.5)
                quickConfigForm
            }
            Divider().opacity(0.5)
            messagesList
            Divider().opacity(0.5)
            composerBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: NSColor(calibratedRed: 0.04, green: 0.058, blue: 0.084, alpha: 1)))
        .task {
            if aiSettings.selectedProvider == .ollama && model.ollamaModels.isEmpty {
                await model.refreshOllamaModels()
            }
        }
    }

    // MARK: - Header Bar (38pt aligned with TabStrip)

    private var headerBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.sparkles.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.cyan)
                Text("AI Assistant")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showQuickConfig.toggle()
                }
            } label: {
                Image(systemName: showQuickConfig ? "slider.horizontal.3" : "gearshape")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(showQuickConfig ? .cyan : .secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(showQuickConfig ? Color.cyan.opacity(0.14) : Color.white.opacity(0.04))
                    )
            }
            .buttonStyle(.plain)
            .help("Configure AI Provider & API Key")

            if !model.state.chatMessages.isEmpty {
                Button {
                    model.clearAIChatHistory()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Clear Chat History")
            }

            Button {
                model.toggleAIChat()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("Close AI Chat (⇧⌘I)")
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color(nsColor: NSColor(calibratedRed: 0.035, green: 0.05, blue: 0.075, alpha: 1)))
    }

    // MARK: - Provider & Model Bar (40pt aligned with ContextBar)

    private var providerControlsBar: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(AIProviderKind.allCases, id: \.self) { provider in
                    Button {
                        model.updatePreferences { $0.aiSettings.selectedProvider = provider }
                        if provider == .ollama {
                            Task { await model.refreshOllamaModels() }
                        }
                    } label: {
                        HStack {
                            Text(provider.displayName)
                            if aiSettings.selectedProvider == provider {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(providerStatusColor)
                        .frame(width: 6, height: 6)
                    Text(aiSettings.selectedProvider.shortName)
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8.5, weight: .bold))
                }
                .foregroundStyle(.cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.cyan.opacity(0.28), lineWidth: 1)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if aiSettings.selectedProvider == .ollama && !model.ollamaModels.isEmpty {
                Menu {
                    ForEach(model.ollamaModels, id: \.self) { modelName in
                        Button {
                            model.updatePreferences { $0.aiSettings.ollamaModel = modelName }
                        } label: {
                            HStack {
                                Text(modelName)
                                if aiSettings.ollamaModel == modelName {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(aiSettings.ollamaModel)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8.5, weight: .bold))
                    }
                    .foregroundStyle(.primary.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
                }
                .menuStyle(.borderlessButton)
            } else {
                TextField(
                    "Model name",
                    text: Binding(
                        get: { model.state.preferences.aiSettings.activeModel },
                        set: { val in model.updatePreferences { $0.aiSettings.activeModel = val } }
                    )
                )
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
            }

            if aiSettings.selectedProvider == .ollama {
                Button {
                    Task { await model.refreshOllamaModels() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Refresh Local Ollama Models")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(Color(nsColor: NSColor(calibratedRed: 0.043, green: 0.063, blue: 0.09, alpha: 1)))
    }

    private var providerStatusColor: Color {
        switch aiSettings.selectedProvider {
        case .ollama:
            return model.ollamaModels.isEmpty ? .orange : .green
        case .openAI:
            let hasKey = !aiSettings.openAIAPIKey.isEmpty
                || model.effectiveEnvironmentVariables["OPENAI_API_KEY"] != nil
                || ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil
            return hasKey ? .green : .orange
        case .anthropic:
            let hasKey = !aiSettings.anthropicAPIKey.isEmpty
                || model.effectiveEnvironmentVariables["ANTHROPIC_API_KEY"] != nil
                || ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil
            return hasKey ? .green : .orange
        case .customOpenAICompatible:
            return .green
        }
    }

    // MARK: - Inline Quick Configuration Drawer

    private var quickConfigForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PROVIDER CONFIGURATION")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                SettingsLink {
                    Text("Full Settings…")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Endpoint URL")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField(
                    aiSettings.selectedProvider.defaultBaseURL,
                    text: Binding(
                        get: { model.state.preferences.aiSettings.activeBaseURL },
                        set: { val in model.updatePreferences { $0.aiSettings.activeBaseURL = val } }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
            }

            if aiSettings.selectedProvider != .ollama {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    SecureField(
                        aiSettings.selectedProvider == .customOpenAICompatible ? "Optional API Key" : "sk-...",
                        text: Binding(
                            get: { model.state.preferences.aiSettings.activeAPIKey },
                            set: { val in model.updatePreferences { $0.aiSettings.activeAPIKey = val } }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                }
            }

            Toggle(
                "Include active workspace & git context",
                isOn: Binding(
                    get: { model.state.preferences.aiSettings.includeWorkspaceContext },
                    set: { val in model.updatePreferences { $0.aiSettings.includeWorkspaceContext = val } }
                )
            )
            .font(.system(size: 11))
            .toggleStyle(.checkbox)

            if let status = model.aiStatusMessage, aiSettings.selectedProvider == .ollama {
                Text(status)
                    .font(.system(size: 10))
                    .foregroundStyle(model.ollamaModels.isEmpty ? .orange : .green)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.025))
    }

    // MARK: - Chat Messages List

    @ViewBuilder
    private var messagesList: some View {
        if model.state.chatMessages.isEmpty {
            ScrollView {
                VStack(spacing: 14) {
                    Image(systemName: "bubble.left.and.sparkles.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.cyan.opacity(0.85))
                        .padding(.top, 36)

                    Text("Nathstar AI Assistant")
                        .font(.system(size: 14, weight: .semibold))

                    Text("Chat with local models via Ollama or connect OpenAI, Anthropic, and custom APIs. Run generated commands directly in your active terminal.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("QUICK PROMPTS")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        suggestionButton("Show git status and recent commits in a compact graph")
                        suggestionButton("Find which process is listening on port 3000 or 8080")
                        suggestionButton("List the largest files and directories in this workspace")
                        suggestionButton("Explain how to set up a local model with Ollama")
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.state.chatMessages) { message in
                            AIChatBubbleView(
                                message: message,
                                onRunCommand: { cmd in
                                    model.sendCommandToFocusedTerminal(cmd, execute: true)
                                },
                                onInsertCommand: { cmd in
                                    model.sendCommandToFocusedTerminal(cmd, execute: false)
                                }
                            )
                            .id(message.id)
                        }

                        if model.isGeneratingAIResponse {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Thinking (\(aiSettings.activeModel))…")
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Stop") {
                                    model.cancelAIGeneration()
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.orange)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                            .id("ai-loading-indicator")
                        }
                    }
                    .padding(12)
                }
                .onChange(of: model.state.chatMessages.count) { _, _ in
                    if let lastID = model.state.chatMessages.last?.id {
                        withAnimation(.easeOut(duration: 0.16)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: model.state.chatMessages.last?.content) { _, _ in
                    if let lastID = model.state.chatMessages.last?.id {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
                .onChange(of: model.isGeneratingAIResponse) { _, generating in
                    if generating {
                        withAnimation(.easeOut(duration: 0.16)) {
                            proxy.scrollTo("ai-loading-indicator", anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func suggestionButton(_ prompt: String) -> some View {
        Button {
            model.sendAIChatMessage(prompt)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.cyan)
                Text(prompt)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.88))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Composer Bar

    private var composerBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                model.sendRecentTerminalOutputToAI()
            } label: {
                Image(systemName: "terminal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 26, height: 26)
                    .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.cyan.opacity(0.28), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .help("Send Recent Terminal Output to AI for Analysis")

            TextField(
                "Ask AI or request a terminal command…",
                text: $inputText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .lineLimit(1...5)
            .focused($isInputFocused)
            .onSubmit {
                submitPrompt()
            }

            if model.isGeneratingAIResponse {
                Button {
                    model.cancelAIGeneration()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.orange)
                        .frame(width: 28, height: 26)
                        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Stop generating")
            } else {
                Button {
                    submitPrompt()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.cyan)
                        .frame(width: 28, height: 26)
                        .background(Color.cyan.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.cyan.opacity(0.32), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                .help("Send Message (⏎)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 42)
        .background(Color(nsColor: NSColor(calibratedRed: 0.043, green: 0.063, blue: 0.09, alpha: 1)))
    }

    private func submitPrompt() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !model.isGeneratingAIResponse else { return }
        inputText = ""
        model.sendAIChatMessage(trimmed)
    }
}

// MARK: - Chat Bubble & Code Block Parsing

private struct AIChatBubbleView: View {
    let message: AIChatMessage
    let onRunCommand: (String) -> Void
    let onInsertCommand: (String) -> Void

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 5) {
            HStack(spacing: 5) {
                if isUser {
                    Spacer()
                    Text("You")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: message.isError ? "exclamationmark.triangle.fill" : "sparkles")
                        .font(.system(size: 10))
                        .foregroundStyle(message.isError ? .orange : .cyan)
                    Text(message.providerName ?? "AI")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(message.isError ? .orange : .cyan)
                    if let modelName = message.modelName, !modelName.isEmpty {
                        Text("· \(modelName)")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(parseSegments(message.content).enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .text(let text):
                        Text(text)
                            .font(.system(size: 12))
                            .foregroundStyle(message.isError ? Color.orange : Color.primary.opacity(0.92))
                            .textSelection(.enabled)
                    case .code(let language, let code):
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 6) {
                                Text(language.isEmpty ? "shell" : language)
                                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(code, forType: .string)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                        .font(.system(size: 9.5, weight: .medium))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .help("Copy to Clipboard")

                                Button {
                                    onInsertCommand(code)
                                } label: {
                                    Label("Insert", systemImage: "arrow.right.doc.on.clipboard")
                                        .font(.system(size: 9.5, weight: .medium))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.cyan)
                                .help("Paste into active terminal without running")

                                Button {
                                    onRunCommand(code)
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 8.5))
                                        Text("Run")
                                            .font(.system(size: 9.5, weight: .semibold))
                                    }
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                .help("Execute in active terminal")
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.05))

                            Text(code)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.95))
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.4))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        }
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(bubbleBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(bubbleBorder, lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var bubbleBackground: Color {
        if message.isError {
            return Color.orange.opacity(0.08)
        }
        return isUser ? Color.cyan.opacity(0.14) : Color.white.opacity(0.035)
    }

    private var bubbleBorder: Color {
        if message.isError {
            return Color.orange.opacity(0.32)
        }
        return isUser ? Color.cyan.opacity(0.3) : Color.white.opacity(0.07)
    }

    private enum MessageSegment {
        case text(String)
        case code(language: String, content: String)
    }

    private func parseSegments(_ raw: String) -> [MessageSegment] {
        var segments: [MessageSegment] = []
        let lines = raw.components(separatedBy: "\n")
        var currentText: [String] = []
        var currentCode: [String] = []
        var codeLang = ""
        var insideCode = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if insideCode {
                    let codeContent = currentCode.joined(separator: "\n").trimmingCharacters(in: .newlines)
                    if !codeContent.isEmpty {
                        segments.append(.code(language: codeLang, content: codeContent))
                    }
                    currentCode.removeAll()
                    codeLang = ""
                    insideCode = false
                } else {
                    let flushed = currentText.joined(separator: "\n").trimmingCharacters(in: .newlines)
                    if !flushed.isEmpty {
                        segments.append(.text(flushed))
                    }
                    currentText.removeAll()
                    codeLang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    insideCode = true
                }
            } else {
                if insideCode {
                    currentCode.append(line)
                } else {
                    currentText.append(line)
                }
            }
        }

        if insideCode {
            let codeContent = currentCode.joined(separator: "\n").trimmingCharacters(in: .newlines)
            if !codeContent.isEmpty {
                segments.append(.code(language: codeLang, content: codeContent))
            }
        } else {
            let flushed = currentText.joined(separator: "\n").trimmingCharacters(in: .newlines)
            if !flushed.isEmpty {
                segments.append(.text(flushed))
            }
        }

        return segments.isEmpty ? [.text(raw)] : segments
    }
}
