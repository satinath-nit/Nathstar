import AppKit
import NorthstarCore
import SwiftUI

struct AttentionPanel: View {
    @EnvironmentObject private var model: AppModel
    @State private var portSearchQuery = ""
    @State private var showTerminalOwnedOnly = false

    var body: some View {
        VStack(spacing: 0) {
            // Top segmented header aligned with TabStrip (38pt)
            HStack(spacing: 6) {
                Button {
                    model.rightPanelTab = .attention
                } label: {
                    HStack(spacing: 5) {
                        Text("Attention")
                            .font(.system(size: 11.5, weight: .semibold))
                        if model.unreadAttentionCount > 0 {
                            Text("\(model.unreadAttentionCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.orange, in: Capsule())
                        }
                    }
                    .foregroundStyle(model.rightPanelTab == .attention ? .primary : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(model.rightPanelTab == .attention ? Color.white.opacity(0.085) : Color.clear)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    model.reloadCapsule()
                    model.rightPanelTab = .manifest
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: model.capsule == nil ? "doc.badge.gearshape" : "doc.badge.gearshape.fill")
                            .font(.system(size: 10.5))
                            .foregroundStyle(model.capsule == nil ? Color.secondary : Color.cyan)
                        Text("Manifest")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(model.rightPanelTab == .manifest ? .primary : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(model.rightPanelTab == .manifest ? Color.white.opacity(0.085) : Color.clear)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    model.rightPanelTab = .ports
                    model.refreshLivePortsAndProcesses()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "network")
                            .font(.system(size: 10.5))
                            .foregroundStyle(model.livePortProcesses.isEmpty ? Color.secondary : Color.green)
                        Text("Ports")
                            .font(.system(size: 11.5, weight: .semibold))
                        if !model.livePortProcesses.isEmpty {
                            Text("\(model.livePortProcesses.count)")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.cyan)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.cyan.opacity(0.14), in: Capsule())
                        }
                    }
                    .foregroundStyle(model.rightPanelTab == .ports ? .primary : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(model.rightPanelTab == .ports ? Color.white.opacity(0.085) : Color.clear)
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                Menu {
                    Button("Mark All Read") { model.markAllAttentionRead() }
                    Button("Clear Read Items") { model.clearReadAttention() }
                    Divider()
                    Button("Refresh Live Ports & Processes") {
                        model.refreshLivePortsAndProcesses()
                    }
                    Divider()
                    Button("Open Full Manifest Sheet…") {
                        model.reloadCapsule()
                        model.isCapsulePresented = true
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(Color(nsColor: NSColor(calibratedRed: 0.035, green: 0.05, blue: 0.075, alpha: 1)))
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                toggleWindowMaximize()
            }

            Divider().opacity(0.5)

            switch model.rightPanelTab {
            case .attention:
                attentionContent
            case .manifest:
                inlineManifestContent
            case .ports:
                portsAndProcessesContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: NSColor(calibratedRed: 0.043, green: 0.063, blue: 0.09, alpha: 1)))
        .task(id: model.rightPanelTab) {
            guard model.rightPanelTab == .ports else { return }
            model.refreshLivePortsAndProcesses()
            while !Task.isCancelled && model.rightPanelTab == .ports {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled && model.rightPanelTab == .ports {
                    model.refreshLivePortsAndProcesses()
                }
            }
        }
    }

    @ViewBuilder
    private var attentionContent: some View {
        HStack {
            Text(model.unreadAttentionCount == 0 ? "Activity & Alerts" : "\(model.unreadAttentionCount) unread alert\(model.unreadAttentionCount == 1 ? "" : "s")")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            if !model.state.attentionItems.isEmpty {
                Button("Mark all read") {
                    model.markAllAttentionRead()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.cyan)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)

        Divider().opacity(0.5)

        if model.state.attentionItems.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("All Clear")
                    .font(.headline)
                Text("Completed, failed, or waiting sessions across your workspaces will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 56)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(model.state.attentionItems) { item in
                        AttentionCard(
                            item: item,
                            workspaceName: workspaceName(item.workspaceID),
                            onFocus: { model.focusAttentionItem(item) },
                            onApprove: { model.respondToAttentionItem(item, input: "y") },
                            onDeny: { model.respondToAttentionItem(item, input: "n") },
                            onDismiss: { model.dismissAttentionItem(item) }
                        )
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private var inlineManifestContent: some View {
        HStack {
            Text(model.capsule?.name ?? "Project Manifest & Env")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            Button("Expand") {
                model.isCapsulePresented = true
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.cyan)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)

        Divider().opacity(0.5)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Interactive Environment Variable Form & .env Exporter
                VStack(alignment: .leading, spacing: 8) {
                    Text("ENVIRONMENT VARIABLES (.ENV)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    EnvironmentVariablesEditorView(compact: true)
                        .environmentObject(model)
                }
                .padding(10)
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))

                if let capsule = model.capsule {
                    if !capsule.description.isEmpty {
                        Text(capsule.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let inspection = model.capsuleInspection {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("READINESS")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(inspection.tools) { toolStatus in
                                HStack {
                                    Image(systemName: toolStatus.executablePath != nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(toolStatus.executablePath != nil ? .green : .orange)
                                    Text(toolStatus.tool.name)
                                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                    Spacer()
                                    Text(toolStatus.executablePath != nil ? "Ready" : "Missing")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        model.activateCapsule()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Activate Project Manifest")
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.cyan.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(model.capsuleInspection?.canActivate != true)

                    let allCommands = capsule.startupCommands + capsule.usefulCommands
                    if !allCommands.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("COMMANDS")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(allCommands) { cmd in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cmd.name)
                                            .font(.system(size: 11.5, weight: .medium))
                                        Text(cmd.command)
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Button("Run") {
                                        model.runCapsuleCommand(cmd)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                                .padding(8)
                                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 7))
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROJECT MANIFEST")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Create a portable .nathstar/manifest.json to automate startup commands, services, and checks for this workspace.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Create Manifest Template") {
                            model.createCapsuleTemplate()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var filteredPortProcesses: [LivePortProcess] {
        let base = showTerminalOwnedOnly
            ? model.livePortProcesses.filter(\.isFromNathstarTerminal)
            : model.livePortProcesses
        let query = portSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }
        return base.filter { item in
            if let port = item.port, String(port).contains(query) {
                return true
            }
            if String(item.pid).contains(query) {
                return true
            }
            if item.processName.localizedCaseInsensitiveContains(query)
                || item.commandLine.localizedCaseInsensitiveContains(query) {
                return true
            }
            if let ws = item.workspaceName, ws.localizedCaseInsensitiveContains(query) {
                return true
            }
            return false
        }
    }

    @ViewBuilder
    private var portsAndProcessesContent: some View {
        HStack(spacing: 8) {
            Text("Live Ports & Processes")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()

            Button {
                showTerminalOwnedOnly.toggle()
            } label: {
                Text(showTerminalOwnedOnly ? "Terminals Only" : "All Local")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(showTerminalOwnedOnly ? Color.cyan : Color.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(showTerminalOwnedOnly ? Color.cyan.opacity(0.14) : Color.white.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
            .help("Toggle between processes spawned inside Nathstar terminals vs all local user listening ports")

            Button {
                model.refreshLivePortsAndProcesses()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.cyan)
            }
            .buttonStyle(.plain)
            .help("Refresh Live Ports & Processes")
        }
        .padding(.horizontal, 14)
        .frame(height: 40)

        Divider().opacity(0.5)

        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            TextField("Filter by :port, PID, process, or workspace…", text: $portSearchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5, design: .monospaced))
            if !portSearchQuery.isEmpty {
                Button {
                    portSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.025))

        Divider().opacity(0.5)

        if let statusMsg = model.portsStatusMessage {
            HStack(spacing: 6) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.cyan)
                Text(statusMsg)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(1)
                Spacer()
                Button {
                    model.portsStatusMessage = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.cyan.opacity(0.09))
            Divider().opacity(0.5)
        }

        let items = filteredPortProcesses
        if items.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "network")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("No Matching Ports or Processes")
                    .font(.headline)
                Text(
                    showTerminalOwnedOnly
                        ? "No active child processes or listening TCP ports were found in your open Nathstar terminals."
                        : "Active listening TCP ports (e.g. :3000, :5173, :8080) and running terminal processes will appear here with one-click Kill controls."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            }
            .padding(.top, 56)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        LivePortProcessCard(
                            item: item,
                            onOpenBrowser: {
                                if let url = item.browserURL {
                                    NSWorkspace.shared.open(url)
                                }
                            },
                            onFocusPane: {
                                model.focusPortProcess(item)
                            },
                            onKill: {
                                model.killPortOrProcess(item, force: false)
                            },
                            onForceKill: {
                                model.killPortOrProcess(item, force: true)
                            }
                        )
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func workspaceName(_ id: UUID) -> String {
        model.state.workspaces.first { $0.id == id }?.name ?? "Workspace"
    }
}

private struct LivePortProcessCard: View {
    let item: LivePortProcess
    let onOpenBrowser: () -> Void
    let onFocusPane: () -> Void
    let onKill: () -> Void
    let onForceKill: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                if let port = item.port {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text(":\(String(port))")
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.green.opacity(0.32), lineWidth: 1)
                    }
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 6, height: 6)
                        Text("PROC")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
                }

                Text(item.processName)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Text("PID \(item.pid)")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
            }

            Text(item.commandLine)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.88))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.35))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
                .lineLimit(2)

            HStack(spacing: 6) {
                if let wsName = item.workspaceName {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                            .font(.system(size: 9.5))
                        Text(item.sessionTitle.map { "\(wsName) · \($0)" } ?? wsName)
                            .lineLimit(1)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.cyan)
                } else if let addr = item.bindAddress {
                    Text(addr)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Local Process")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if item.port != nil {
                    Button(action: onOpenBrowser) {
                        HStack(spacing: 3) {
                            Image(systemName: "globe")
                                .font(.system(size: 9.5))
                            Text("Open")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .help("Open http://localhost:\(item.port ?? 0) in browser")
                }

                if item.isFromNathstarTerminal {
                    Button(action: onFocusPane) {
                        Text("Focus")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .help("Jump to the terminal pane running this process")
                }

                Button(action: onKill) {
                    Text("Kill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.orange.opacity(0.32), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .help("Terminate process gracefully (SIGTERM)")

                Button(action: onForceKill) {
                    Text("Kill -9")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.red.opacity(0.32), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .help("Force kill process immediately (SIGKILL -9)")
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(item.isFromNathstarTerminal ? Color.cyan.opacity(0.045) : Color.white.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    item.isFromNathstarTerminal ? Color.cyan.opacity(0.24) : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        }
    }
}

private struct AttentionCard: View {
    let item: AttentionItem
    let workspaceName: String
    let onFocus: () -> Void
    let onApprove: () -> Void
    let onDeny: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                Spacer()
                Text(item.createdAt, style: .time)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }

            Text(item.detail)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.88))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.35))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
                .lineLimit(3)

            HStack(spacing: 6) {
                Text(workspaceName)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if item.kind == .approval {
                    Button(action: onApprove) {
                        Text("Approve (y)")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)

                    Button(action: onDeny) {
                        Text("Deny (n)")
                            .font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onFocus) {
                    Text("Focus Pane")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardBorder, lineWidth: 1)
        }
    }

    private var cardBackground: Color {
        switch item.kind {
        case .approval: Color.orange.opacity(0.06)
        case .failure: Color.red.opacity(0.05)
        case .success: Color.white.opacity(0.03)
        case .disconnected: Color.orange.opacity(0.05)
        case .information: Color.white.opacity(0.03)
        }
    }

    private var cardBorder: Color {
        switch item.kind {
        case .approval: Color.orange.opacity(0.3)
        case .failure: Color.red.opacity(0.26)
        case .success: item.isRead ? Color.white.opacity(0.07) : Color.green.opacity(0.25)
        case .disconnected: Color.orange.opacity(0.25)
        case .information: Color.white.opacity(0.08)
        }
    }

    private var icon: String {
        switch item.kind {
        case .success: "checkmark.circle.fill"
        case .approval: "exclamationmark.circle.fill"
        case .failure: "xmark.circle.fill"
        case .disconnected: "wifi.slash"
        case .information: "info.circle.fill"
        }
    }

    private var color: Color {
        switch item.kind {
        case .success: .green
        case .approval: .orange
        case .failure: .red
        case .disconnected: .orange
        case .information: .cyan
        }
    }
}
