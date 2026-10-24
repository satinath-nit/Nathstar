import AppKit
import NorthstarCore
import SwiftUI

struct CommandPaletteView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var actions: [PaletteAction] {
        var values: [PaletteAction] = [
            PaletteAction(title: "New Tab", subtitle: "Open another shell (⌘N)", icon: "plus") {
                model.addTab()
            },
            PaletteAction(title: "Find in Terminal Buffer", subtitle: "Search scrollback buffer with regex & case options (⌘F)", icon: "doc.text.magnifyingglass") {
                model.toggleTerminalSearch()
            },
            PaletteAction(title: "Quick Links & File Paths", subtitle: "Detect & open URLs, localhost ports, and file:line paths (⇧⌘L)", icon: "link") {
                model.toggleQuickLinks()
            },
            PaletteAction(title: "Inline AI Command Generator", subtitle: "Translate natural language into a shell command (⌘I)", icon: "sparkles") {
                model.toggleInlineAIBar()
            },
            PaletteAction(title: "Send Recent Terminal Output to AI", subtitle: "Analyze the last 45 lines of active terminal output in AI Chat", icon: "bubble.left.and.sparkles.fill") {
                model.sendRecentTerminalOutputToAI()
            },
            PaletteAction(title: "Copy Recent Terminal Output", subtitle: "Copy the last 50 lines of active terminal output to clipboard", icon: "doc.on.doc") {
                model.copyFocusedTerminalOutput(maxLines: 50)
            },
            PaletteAction(title: "Split Vertically", subtitle: "Open a terminal beside the current pane (⌘D)", icon: "rectangle.split.2x1") {
                model.splitFocused(axis: .vertical)
            },
            PaletteAction(title: "Split Horizontally", subtitle: "Open a terminal below the current pane (⇧⌘D)", icon: "rectangle.split.1x2") {
                model.splitFocused(axis: .horizontal)
            },
            PaletteAction(title: "Equalize Split Panes", subtitle: "Reset all split ratios to 50/50 (⇧⌘=)", icon: "rectangle.split.2x2") {
                model.equalizeSplits()
            },
            PaletteAction(title: "Toggle Pane Zoom", subtitle: "Maximize or restore the focused split pane (⇧⌘⏎)", icon: "arrow.up.left.and.arrow.down.right") {
                model.toggleZoomFocusedPane()
            },
            PaletteAction(title: "Toggle Quake Visor Mode", subtitle: "Dock window to top of screen & toggle hide/show on Double-Tap ⌃", icon: "rectangle.topthird.inset.filled") {
                model.updatePreferences { $0.enableQuakeVisorMode.toggle() }
            },
            PaletteAction(title: "Toggle Attention Center", subtitle: "Show or hide session notifications", icon: "bell") {
                model.updatePreferences { $0.showAttentionCenter.toggle() }
            },
            PaletteAction(title: "Live Ports & Processes", subtitle: "View & kill active listening ports and terminal processes (⇧⌘P)", icon: "network") {
                model.openPortsPanel()
            },
            PaletteAction(title: "Toggle AI Assistant Chat", subtitle: "Open or close the AI chat panel for Ollama & API models (⇧⌘I)", icon: "bubble.left.and.sparkles.fill") {
                model.toggleAIChat()
            },
            PaletteAction(title: "Project Manifest & Environment", subtitle: "Manage environment variables, export .env, and activate project manifest", icon: "shippingbox") {
                model.reloadCapsule()
                model.isCapsulePresented = true
            },
            PaletteAction(title: "Export Environment Variables to .env", subtitle: "Write workspace KEY=VALUE variables to .env in project root", icon: "square.and.arrow.up") {
                model.exportEnvironmentToDotEnv(revealInFinder: true)
            },
            PaletteAction(title: "Apply Environment Variables to Terminal", subtitle: "Run export KEY=VALUE in the active terminal pane", icon: "terminal") {
                model.applyEnvironmentToFocusedTerminal()
            },
            PaletteAction(title: "Docs & Contribute", subtitle: "Read documentation, explore features, and contribute to Nathstar", icon: "book.pages.fill") {
                if let url = URL(string: "https://github.com/satinath-nit/Nathstar") {
                    NSWorkspace.shared.open(url)
                }
            },
            PaletteAction(title: "Close Window", subtitle: "Close the Nathstar window (⌘W)", icon: "xmark.circle") {
                NathstarWindowController.closeActiveWindow()
            }
        ]
        for snippet in model.state.snippets {
            values.append(
                PaletteAction(
                    title: "Snippet: \(snippet.title)",
                    subtitle: snippet.command,
                    icon: "text.book.closed"
                ) {
                    model.triggerSnippet(snippet, executeImmediately: false)
                }
            )
        }
        for host in model.allSSHHosts {
            values.append(
                PaletteAction(
                    title: "SSH: \(host.alias)",
                    subtitle: host.sshCommand,
                    icon: "server.rack"
                ) {
                    model.connectSSHHost(host, useSFTP: false)
                }
            )
        }
        for theme in TerminalThemePreset.allCases {
            values.append(
                PaletteAction(
                    title: "Theme: \(theme.displayName)",
                    subtitle: "Switch terminal color palette to \(theme.displayName)",
                    icon: "paintpalette"
                ) {
                    model.updatePreferences { $0.theme = theme }
                }
            )
        }
        if let capsule = model.capsule {
            for command in capsule.startupCommands + capsule.usefulCommands {
                values.append(
                    PaletteAction(
                        title: "Manifest: \(command.name)",
                        subtitle: command.command,
                        icon: "play.circle"
                    ) {
                        model.runCapsuleCommand(command)
                    }
                )
            }
        }
        values.append(contentsOf: model.state.workspaces.map { workspace in
            PaletteAction(
                title: workspace.name,
                subtitle: workspace.rootDirectory,
                icon: "shippingbox"
            ) {
                model.selectWorkspace(workspace.id)
            }
        })
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return values }
        return values.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.subtitle.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search actions and workspaces", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
            }
            .padding(16)
            Divider()
            List(actions) { action in
                Button {
                    action.perform()
                    dismiss()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title)
                            Text(action.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: action.icon)
                            .frame(width: 22)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
        .frame(width: 580, height: 420)
    }
}

private struct PaletteAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let perform: () -> Void
}
