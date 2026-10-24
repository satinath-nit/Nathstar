import AppKit
import NorthstarCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showOpenAIKey = false
    @State private var showAnthropicKey = false
    @State private var showCustomKey = false
    @State private var newSnippetTitle = ""
    @State private var newSnippetCommand = ""
    @State private var newSnippetCategory = "Custom"

    private var aiSettings: AISettings {
        model.state.preferences.aiSettings
    }

    var body: some View {
        TabView {
            Form {
                Toggle("Show Attention Center", isOn: preferenceBinding(\.showAttentionCenter))
                Toggle("Show AI Assistant Chat Panel", isOn: preferenceBinding(\.showAIChat))
                Toggle("Show Warp-style Command Blocks ribbon on terminal panes", isOn: preferenceBinding(\.showCommandBlocksBar))
                Toggle("Show IDE autocomplete suggestions in Safe-Run composer", isOn: preferenceBinding(\.enableComposerAutocomplete))
                Toggle("Warn before risky commands", isOn: preferenceBinding(\.warnBeforeRiskyCommands))
                Toggle("Global Hotkey: Double-tap Control (⌃⌃) to summon Nathstar from anywhere", isOn: preferenceBinding(\.enableDoubleTapControlHotkey))
                Toggle("Quake Visor Mode: Dock to top of screen & toggle hide/show on Double-tap ⌃", isOn: preferenceBinding(\.enableQuakeVisorMode))
                Toggle("Restore terminal scrollback history on app launch", isOn: preferenceBinding(\.restoreScrollbackOnLaunch))
                Toggle("Background Multiplexer Mode: Attach panes to persistent tmux sessions across Quit (⌘Q)", isOn: preferenceBinding(\.enablePersistentTmuxSessions))
                LabeledContent("Long-running threshold") {
                    HStack {
                        Slider(value: preferenceBinding(\.longRunningCommandThreshold), in: 2...60, step: 1)
                            .frame(width: 180)
                        Text("\(Int(model.state.preferences.longRunningCommandThreshold)) sec")
                            .monospacedDigit()
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
            .padding(20)
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Picker("Active Provider", selection: preferenceBinding(\.aiSettings.selectedProvider)) {
                    ForEach(AIProviderKind.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                switch aiSettings.selectedProvider {
                case .ollama:
                    Section("Ollama (Local Hosted)") {
                        TextField("Endpoint URL", text: preferenceBinding(\.aiSettings.ollamaBaseURL))
                            .font(.system(.body, design: .monospaced))
                        HStack {
                            if !model.ollamaModels.isEmpty {
                                Picker("Installed Model", selection: preferenceBinding(\.aiSettings.ollamaModel)) {
                                    ForEach(model.ollamaModels, id: \.self) { name in
                                        Text(name).tag(name)
                                    }
                                }
                            } else {
                                TextField("Model (e.g. llama3.2, qwen2.5-coder)", text: preferenceBinding(\.aiSettings.ollamaModel))
                                    .font(.system(.body, design: .monospaced))
                            }
                            Button("Detect Models") {
                                Task { await model.refreshOllamaModels() }
                            }
                        }
                        if let status = model.aiStatusMessage {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(model.ollamaModels.isEmpty ? .orange : .green)
                        }
                    }

                case .openAI:
                    Section("OpenAI API") {
                        TextField("Base URL", text: preferenceBinding(\.aiSettings.openAIBaseURL))
                            .font(.system(.body, design: .monospaced))
                        HStack {
                            if showOpenAIKey {
                                TextField("API Key (or set OPENAI_API_KEY in env)", text: preferenceBinding(\.aiSettings.openAIAPIKey))
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                SecureField("API Key (or set OPENAI_API_KEY in env)", text: preferenceBinding(\.aiSettings.openAIAPIKey))
                                    .font(.system(.body, design: .monospaced))
                            }
                            Button(showOpenAIKey ? "Hide" : "Show") {
                                showOpenAIKey.toggle()
                            }
                        }
                        TextField("Model (e.g. gpt-4o, gpt-4o-mini)", text: preferenceBinding(\.aiSettings.openAIModel))
                            .font(.system(.body, design: .monospaced))
                    }

                case .anthropic:
                    Section("Anthropic (Claude) API") {
                        TextField("Base URL", text: preferenceBinding(\.aiSettings.anthropicBaseURL))
                            .font(.system(.body, design: .monospaced))
                        HStack {
                            if showAnthropicKey {
                                TextField("API Key (or set ANTHROPIC_API_KEY in env)", text: preferenceBinding(\.aiSettings.anthropicAPIKey))
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                SecureField("API Key (or set ANTHROPIC_API_KEY in env)", text: preferenceBinding(\.aiSettings.anthropicAPIKey))
                                    .font(.system(.body, design: .monospaced))
                            }
                            Button(showAnthropicKey ? "Hide" : "Show") {
                                showAnthropicKey.toggle()
                            }
                        }
                        TextField("Model (e.g. claude-3-5-sonnet-latest)", text: preferenceBinding(\.aiSettings.anthropicModel))
                            .font(.system(.body, design: .monospaced))
                    }

                case .customOpenAICompatible:
                    Section("OpenAI-Compatible Endpoint (LM Studio, Groq, OpenRouter, vLLM)") {
                        TextField("Base URL (e.g. http://127.0.0.1:1234/v1)", text: preferenceBinding(\.aiSettings.customBaseURL))
                            .font(.system(.body, design: .monospaced))
                        HStack {
                            if showCustomKey {
                                TextField("API Key (Optional for local servers)", text: preferenceBinding(\.aiSettings.customAPIKey))
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                SecureField("API Key (Optional for local servers)", text: preferenceBinding(\.aiSettings.customAPIKey))
                                    .font(.system(.body, design: .monospaced))
                            }
                            Button(showCustomKey ? "Hide" : "Show") {
                                showCustomKey.toggle()
                            }
                        }
                        TextField("Model Name", text: preferenceBinding(\.aiSettings.customModel))
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Section("Context & System Prompt") {
                    Toggle("Include active workspace path & git branch in context", isOn: preferenceBinding(\.aiSettings.includeWorkspaceContext))
                    TextField("System Prompt", text: preferenceBinding(\.aiSettings.systemPrompt), axis: .vertical)
                        .lineLimit(3...5)
                        .font(.system(size: 11.5))
                }
            }
            .padding(20)
            .tabItem { Label("AI", systemImage: "bubble.left.and.sparkles.fill") }

            Form {
                Section("Theme & Cursor") {
                    Picker("Color Theme", selection: preferenceBinding(\.theme)) {
                        ForEach(TerminalThemePreset.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    Picker("Cursor Style", selection: preferenceBinding(\.cursorStyle)) {
                        ForEach(TerminalCursorStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    LabeledContent("Background Opacity") {
                        HStack {
                            Slider(value: preferenceBinding(\.backgroundOpacity), in: 0.65...1.0, step: 0.05)
                                .frame(width: 180)
                            Text("\(Int(round(model.state.preferences.backgroundOpacity * 100)))%")
                                .monospacedDigit()
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                }

                Section("Typography & Rendering") {
                    Picker("Terminal Font", selection: preferenceBinding(\.fontName)) {
                        ForEach(monospacedFonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }
                    LabeledContent("Font Size") {
                        HStack {
                            Slider(value: preferenceBinding(\.fontSize), in: 9...24, step: 1)
                                .frame(width: 180)
                            Text("\(Int(model.state.preferences.fontSize)) pt")
                                .monospacedDigit()
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                    Toggle("Use Metal GPU rendering (120Hz hardware shader pipeline)", isOn: preferenceBinding(\.useMetalRenderer))
                }
            }
            .padding(20)
            .tabItem { Label("Terminal", systemImage: "terminal") }

            Form {
                Section("Add Reusable Command Snippet / Workflow") {
                    TextField("Title (e.g. Deploy Staging)", text: $newSnippetTitle)
                    TextField("Command (supports {{param}} placeholders)", text: $newSnippetCommand)
                        .font(.system(.body, design: .monospaced))
                    HStack {
                        TextField("Category", text: $newSnippetCategory)
                            .frame(width: 160)
                        Spacer()
                        Button("Add Snippet") {
                            model.addSnippet(
                                title: newSnippetTitle,
                                command: newSnippetCommand,
                                category: newSnippetCategory
                            )
                            newSnippetTitle = ""
                            newSnippetCommand = ""
                        }
                        .disabled(
                            newSnippetTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || newSnippetCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                }

                Section("Saved Snippets (\(model.state.snippets.count))") {
                    List {
                        ForEach(model.state.snippets) { snippet in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(snippet.title)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(snippet.command)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    model.removeSnippet(id: snippet.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(minHeight: 160)
                }
            }
            .padding(20)
            .tabItem { Label("Snippets", systemImage: "text.book.closed") }

            Form {
                LabeledContent("Workspace data") {
                    Text("~/Library/Application Support/Nathstar")
                        .textSelection(.enabled)
                }
                LabeledContent("Terminal content") {
                    Text("Local only")
                }
                LabeledContent("Telemetry") {
                    Text("Disabled")
                }
                Text("Nathstar does not upload commands, output, paths, hostnames, or workspace names unless you explicitly send a prompt to a configured AI provider.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .frame(width: 660, height: 490)
    }

    private var monospacedFonts: [String] {
        let preferred = ["SF Mono", "Menlo", "Monaco", "JetBrains Mono", "Fira Code"]
        return preferred.filter { NSFont(name: $0, size: 13) != nil }
    }

    private func preferenceBinding<Value>(_ keyPath: WritableKeyPath<NorthstarCore.AppPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { model.state.preferences[keyPath: keyPath] },
            set: { newValue in
                model.updatePreferences { $0[keyPath: keyPath] = newValue }
            }
        )
    }
}
