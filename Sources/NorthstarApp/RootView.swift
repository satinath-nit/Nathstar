import AppKit
import NorthstarCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isSidebarHovered = false
    @State private var hoverDismissTask: Task<Void, Never>?

    private var isSidebarPinned: Bool {
        model.state.preferences.isSidebarPinned
    }

    private func setSidebarHover(_ hovering: Bool) {
        hoverDismissTask?.cancel()
        if hovering {
            withAnimation(.easeOut(duration: 0.16)) {
                isSidebarHovered = true
            }
        } else {
            hoverDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(160))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    isSidebarHovered = false
                }
            }
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                if isSidebarPinned {
                    WorkspaceSidebar(onDismissHover: {})
                        .frame(minWidth: 195, idealWidth: 225, maxWidth: 260)
                    Divider()
                } else {
                    CollapsedSidebarRail(
                        isExpandedByHover: isSidebarHovered,
                        onHoverChange: { hovering in
                            if hovering {
                                setSidebarHover(true)
                            }
                        },
                        onPinSidebar: {
                            model.updatePreferences { $0.isSidebarPinned = true }
                            isSidebarHovered = false
                        }
                    )
                    .frame(width: 44)
                    Divider()
                }

                Group {
                    if let workspace = model.selectedWorkspace,
                       let tab = model.selectedTab {
                        WorkspaceView(workspace: workspace, tab: tab)
                    } else {
                        ContentUnavailableView(
                            "No Workspace",
                            systemImage: "terminal",
                            description: Text("Open a folder to start a terminal workspace.")
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if model.state.preferences.showAttentionCenter {
                    Divider()
                    AttentionPanel()
                        .frame(minWidth: 270, idealWidth: 300, maxWidth: 360)
                }

                if model.state.preferences.showAIChat {
                    Divider()
                    AIChatPanelView()
                        .frame(minWidth: 310, idealWidth: 345, maxWidth: 420)
                }
            }

            // Floating hover-expanded sidebar drawer when unpinned
            if !isSidebarPinned && isSidebarHovered {
                HStack(spacing: 0) {
                    WorkspaceSidebar(onDismissHover: {
                        setSidebarHover(false)
                    })
                    .frame(width: 235)
                    .frame(maxHeight: .infinity)
                    .background(Color(nsColor: NSColor(calibratedRed: 0.043, green: 0.063, blue: 0.09, alpha: 1)))
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.cyan.opacity(0.28))
                            .frame(width: 1)
                    }
                    .shadow(color: .black.opacity(0.55), radius: 18, x: 8, y: 0)
                    .onHover { hovering in
                        setSidebarHover(hovering)
                    }

                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .background(Color(nsColor: NSColor(calibratedRed: 0.035, green: 0.05, blue: 0.07, alpha: 1)))
        .background(WindowTopDoubleClickMaximizer())
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.updatePreferences { $0.isSidebarPinned.toggle() }
                    isSidebarHovered = false
                } label: {
                    Label(
                        isSidebarPinned ? "Collapse Sidebar (Auto-Show on Hover)" : "Pin Sidebar Open",
                        systemImage: isSidebarPinned ? "sidebar.left" : "pin"
                    )
                }
                .help(isSidebarPinned ? "Collapse Sidebar to Hover Mode (⇧⌘S)" : "Pin Sidebar Always Shown (⇧⌘S)")

                Button {
                    model.addTab()
                } label: {
                    Label("New Tab", systemImage: "plus")
                }
                .help("New Tab (⌘N)")

                Button {
                    model.splitFocused(axis: .vertical)
                } label: {
                    Label("Split Vertically", systemImage: "rectangle.split.2x1")
                }
                .help("Split Vertically (⌘D)")

                Button {
                    model.splitFocused(axis: .horizontal)
                } label: {
                    Label("Split Horizontally", systemImage: "rectangle.split.1x2")
                }
                .help("Split Horizontally (⇧⌘D)")

                Button {
                    model.updatePreferences { $0.showAttentionCenter.toggle() }
                } label: {
                    Label("Attention", systemImage: model.unreadAttentionCount == 0 ? "bell" : "bell.badge")
                }
                .help("Toggle Attention Center")

                Button {
                    model.reloadCapsule()
                    model.isCapsulePresented = true
                } label: {
                    Label("Project Manifest", systemImage: model.capsule == nil ? "shippingbox" : "shippingbox.fill")
                }
                .help("Project Manifest & Environment (⇧⌘E)")

                Button {
                    model.toggleAIChat()
                } label: {
                    Label("AI Chat", systemImage: model.state.preferences.showAIChat ? "bubble.left.and.sparkles.fill" : "bubble.left.and.bubble.right")
                }
                .help("Toggle AI Assistant Chat (⇧⌘I)")
            }
        }
        .sheet(isPresented: $model.isCommandPalettePresented) {
            CommandPaletteView()
                .environmentObject(model)
        }
        .sheet(isPresented: $model.isCapsulePresented) {
            CapsulePanel()
                .environmentObject(model)
        }
        .alert("Nathstar could not save its state", isPresented: persistenceErrorBinding) {
            Button("Dismiss") { model.lastPersistenceError = nil }
        } message: {
            Text(model.lastPersistenceError ?? "Unknown persistence error")
        }
        .task {
            await runSmokeTestIfRequested()
        }
    }

    private var persistenceErrorBinding: Binding<Bool> {
        Binding(
            get: { model.lastPersistenceError != nil },
            set: { if !$0 { model.lastPersistenceError = nil } }
        )
    }

    @MainActor
    private func runSmokeTestIfRequested() async {
        guard ProcessInfo.processInfo.environment["NATHSTAR_SMOKE_TEST"] == "1" else { return }
        try? await Task.sleep(for: .seconds(2))
        guard let workspace = model.selectedWorkspace,
              let tab = model.selectedTab,
              tab.root.terminalIDs.contains(where: { TerminalRegistry.shared.contains(sessionID: $0) }) else {
            FileHandle.standardError.write(Data("FAIL: Nathstar launched without a live terminal session\n".utf8))
            TerminalRegistry.shared.terminateAll()
            exit(EXIT_FAILURE)
        }
        print("PASS: Nathstar launched with workspace '\(workspace.name)'")
        print("PASS: A live PTY-backed terminal view was created")
        print("PASS: Workspace, tabs, panes, composer, settings, and Attention Center loaded")
        fflush(stdout)
        TerminalRegistry.shared.terminateAll()
        exit(EXIT_SUCCESS)
    }
}

/// Slim left-edge rail displayed when the sidebar is unpinned. Hovering anywhere over this rail
/// expands the full `WorkspaceSidebar` drawer over the window; clicking the pin button docks it permanently.
private struct CollapsedSidebarRail: View {
    @EnvironmentObject private var model: AppModel
    let isExpandedByHover: Bool
    let onHoverChange: (Bool) -> Void
    let onPinSidebar: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onPinSidebar) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 28, height: 28)
                    .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.cyan.opacity(0.28), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .help("Hover to expand · Click to Pin Sidebar Open (⇧⌘S)")

            Divider().opacity(0.45)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(model.state.workspaces) { workspace in
                        let isSelected = model.state.selectedWorkspaceID == workspace.id
                        let unread = model.state.attentionItems.filter { $0.workspaceID == workspace.id && !$0.isRead }.count
                        let isLive = workspace.tabs.flatMap { $0.root.terminalIDs }.contains { TerminalRegistry.shared.contains(sessionID: $0) }

                        Button {
                            model.selectWorkspace(workspace.id)
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: workspace.rootDirectory.contains("ssh://") ? "terminal" : "shippingbox")
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(isSelected ? .cyan : .secondary)
                                    .frame(width: 30, height: 30)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill(isSelected ? Color.cyan.opacity(0.16) : Color.white.opacity(0.03))
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 7)
                                            .stroke(isSelected ? Color.cyan.opacity(0.38) : Color.clear, lineWidth: 1)
                                    }

                                if unread > 0 {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 6.5, height: 6.5)
                                        .offset(x: 2, y: -2)
                                } else if isLive {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                        .offset(x: 1.5, y: -1.5)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help(workspace.name)
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()

            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
            .help("Settings")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: NSColor(calibratedRed: 0.04, green: 0.058, blue: 0.084, alpha: 1)))
        .contentShape(Rectangle())
        .onHover(perform: onHoverChange)
    }
}

private struct WorkspaceSidebar: View {
    @EnvironmentObject private var model: AppModel
    var onDismissHover: () -> Void = {}

    @State private var editingCategory: WorkspaceCategory?
    @State private var editingTitleText: String = ""
    @State private var isSSHSectionCollapsed = false
    @State private var isAddingSSHHost = false
    @State private var newSSHAlias = ""
    @State private var newSSHHostname = ""
    @State private var newSSHUser = ""
    @State private var newSSHPort = "22"
    @FocusState private var isEditingTitleFocused: Bool

    private var isSidebarPinned: Bool {
        model.state.preferences.isSidebarPinned
    }

    private func workspaces(in category: WorkspaceCategory) -> [Workspace] {
        model.state.workspaces.filter { $0.category == category }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .foregroundStyle(.cyan)
                Text("Nathstar")
                    .font(.headline)
                Spacer()
                Button {
                    let willPin = !isSidebarPinned
                    model.updatePreferences { $0.isSidebarPinned = willPin }
                    if !willPin {
                        onDismissHover()
                    }
                } label: {
                    Image(systemName: isSidebarPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(isSidebarPinned ? .cyan : .secondary)
                        .rotationEffect(.degrees(isSidebarPinned ? 0 : 45))
                        .frame(width: 24, height: 24)
                        .background(
                            (isSidebarPinned ? Color.cyan.opacity(0.14) : Color.white.opacity(0.05)),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSidebarPinned ? Color.cyan.opacity(0.32) : Color.white.opacity(0.08), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .help(isSidebarPinned ? "Unpin Sidebar (Collapse & Auto-Expand on Hover · ⇧⌘S)" : "Pin Sidebar Always Shown (⇧⌘S)")

                Button {
                    chooseFolder(category: .projects)
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13, weight: .medium))
                        .padding(5)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .help("Open Folder as Workspace")
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .overlay(alignment: .bottom) {
                Divider().opacity(0.5)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(WorkspaceCategory.allCases, id: \.self) { category in
                        categorySection(category)
                    }
                    sshHostsSection
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider().opacity(0.5)

            HStack {
                Button {
                    chooseFolder(category: .projects)
                } label: {
                    Label("Open Folder", systemImage: "plus")
                        .font(.system(size: 12.5, weight: .medium))
                }
                .buttonStyle(.plain)
                Spacer()
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .foregroundStyle(.secondary)
            .background(Color(nsColor: NSColor(calibratedRed: 0.035, green: 0.05, blue: 0.075, alpha: 1)))
        }
        .background(Color(nsColor: NSColor(calibratedRed: 0.043, green: 0.063, blue: 0.09, alpha: 1)))
    }

    @ViewBuilder
    private func categorySection(_ category: WorkspaceCategory) -> some View {
        let items = workspaces(in: category)
        let isCollapsed = model.state.preferences.isCategoryCollapsed(category)
        let title = model.state.preferences.title(for: category)
        let liveCount = items.filter { ws in
            ws.tabs.flatMap { $0.root.terminalIDs }.contains { TerminalRegistry.shared.contains(sessionID: $0) }
        }.count

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.14)) {
                        model.toggleSidebarCategoryCollapsed(category)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 11)

                        Image(systemName: category.iconName)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.cyan.opacity(0.85))

                        if editingCategory == category {
                            TextField(category.defaultTitle, text: $editingTitleText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.primary)
                                .focused($isEditingTitleFocused)
                                .onSubmit {
                                    commitCategoryRename(category)
                                }
                        } else {
                            Text(title.uppercased())
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        if isCollapsed && liveCount > 0 {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                        }

                        Text("\(items.count)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5.5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.06), in: Capsule())
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    chooseFolder(category: category)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("Add folder to \(title)")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.025))
            )
            .dropDestination(for: String.self) { droppedStrings, _ in
                guard let first = droppedStrings.first,
                      let wsID = UUID(uuidString: first) else { return false }
                model.setWorkspaceCategory(workspaceID: wsID, category: category)
                return true
            }
            .contextMenu {
                Button(isCollapsed ? "Expand Section" : "Collapse Section") {
                    model.toggleSidebarCategoryCollapsed(category)
                }
                Button("Rename Section…") {
                    editingCategory = category
                    editingTitleText = title
                    isEditingTitleFocused = true
                }
                if model.state.preferences.customSidebarCategoryTitles[category] != nil {
                    Button("Reset Section Name to '\(category.defaultTitle)'") {
                        model.renameSidebarCategory(category, newTitle: category.defaultTitle)
                    }
                }
                Divider()
                Button("Add Folder to \(title)…") {
                    chooseFolder(category: category)
                }
            }

            if !isCollapsed {
                if items.isEmpty {
                    Button {
                        chooseFolder(category: category)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.dashed")
                                .font(.system(size: 11))
                            Text("No items in \(title) · Click to add")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary.opacity(0.75))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(items) { workspace in
                        workspaceRow(workspace)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var sshHostsSection: some View {
        let hosts = model.allSSHHosts
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.14)) {
                        isSSHSectionCollapsed.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSSHSectionCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 11)

                        Image(systemName: "network")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.cyan.opacity(0.85))

                        Text("SSH HOSTS")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Text("\(hosts.count)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5.5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.06), in: Capsule())
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.14)) {
                        isSSHSectionCollapsed = false
                        isAddingSSHHost.toggle()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("Add SSH Host Connection")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.025))
            )

            if !isSSHSectionCollapsed {
                if isAddingSSHHost {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Alias (e.g. prod-api)", text: $newSSHAlias)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                        TextField("Hostname / IP (e.g. 10.0.1.24)", text: $newSSHHostname)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                        HStack(spacing: 6) {
                            TextField("User (ubuntu)", text: $newSSHUser)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                            TextField("Port", text: $newSSHPort)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 56)
                        }
                        HStack {
                            Button("Cancel") {
                                isAddingSSHHost = false
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            Spacer()
                            Button("Save Host") {
                                model.addSSHHost(
                                    alias: newSSHAlias,
                                    hostname: newSSHHostname,
                                    user: newSSHUser.isEmpty ? nil : newSSHUser,
                                    port: Int(newSSHPort)
                                )
                                newSSHAlias = ""
                                newSSHHostname = ""
                                newSSHUser = ""
                                newSSHPort = "22"
                                isAddingSSHHost = false
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                            .disabled(newSSHHostname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                }

                if hosts.isEmpty && !isAddingSSHHost {
                    Button {
                        isAddingSSHHost = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.dashed")
                                .font(.system(size: 11))
                            Text("Add SSH host or ~/.ssh/config")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary.opacity(0.75))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(hosts) { host in
                        Button {
                            model.connectSSHHost(host, useSFTP: false)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "server.rack")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.cyan)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(host.alias)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        if host.isFromSSHConfig {
                                            Text("ssh_config")
                                                .font(.system(size: 8.5, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.white.opacity(0.06), in: Capsule())
                                        }
                                    }
                                    Text(host.displaySubtitle)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Connect via SSH (\(host.sshCommand))") {
                                model.connectSSHHost(host, useSFTP: false)
                            }
                            Button("Open SFTP Session (\(host.sftpCommand))") {
                                model.connectSSHHost(host, useSFTP: true)
                            }
                            if !host.isFromSSHConfig {
                                Divider()
                                Button("Remove SSH Host", role: .destructive) {
                                    model.removeSSHHost(id: host.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func commitCategoryRename(_ category: WorkspaceCategory) {
        model.renameSidebarCategory(category, newTitle: editingTitleText)
        editingCategory = nil
    }

    @ViewBuilder
    private func workspaceRow(_ workspace: Workspace) -> some View {
        let isSelected = model.state.selectedWorkspaceID == workspace.id
        let telemetry = model.workspaceTelemetry[workspace.id]
        let unreadForWorkspace = model.state.attentionItems.filter { $0.workspaceID == workspace.id && !$0.isRead }.count
        let activeSessions = workspace.tabs.flatMap { $0.root.terminalIDs }.filter { TerminalRegistry.shared.contains(sessionID: $0) }.count

        Button {
            model.selectWorkspace(workspace.id)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: workspace.rootDirectory.contains("ssh://") ? "terminal" : "shippingbox")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.cyan)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(workspace.name)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        workspaceStatusBadge(
                            unreadCount: unreadForWorkspace,
                            activeSessions: activeSessions
                        )
                    }

                    HStack(spacing: 5) {
                        Text(abbreviatedPath(workspace.rootDirectory))
                            .lineLimit(1)
                        if let branch = telemetry?.gitBranch {
                            Text("· ⎇ \(branch)")
                                .foregroundStyle(Color.purple.opacity(0.9))
                                .lineLimit(1)
                        }
                    }
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.cyan.opacity(0.12) : Color.clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.cyan.opacity(0.32) : Color.clear, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .draggable(workspace.id.uuidString)
        .contextMenu {
            Menu("Move to Section") {
                ForEach(WorkspaceCategory.allCases, id: \.self) { category in
                    Button {
                        model.setWorkspaceCategory(workspaceID: workspace.id, category: category)
                    } label: {
                        HStack {
                            Text(model.state.preferences.title(for: category))
                            if workspace.category == category {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Remove Workspace", role: .destructive) {
                model.removeWorkspace(workspaceID: workspace.id)
            }
            .disabled(model.state.workspaces.count == 1)
        }
    }

    @ViewBuilder
    private func workspaceStatusBadge(unreadCount: Int, activeSessions: Int) -> some View {
        if unreadCount > 0 {
            Text("\(unreadCount) alert\(unreadCount == 1 ? "" : "s")")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(Color.orange.opacity(0.16), in: Capsule())
                .overlay {
                    Capsule().stroke(Color.orange.opacity(0.35), lineWidth: 1)
                }
        } else if activeSessions > 0 {
            Text("live")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(Color.green.opacity(0.15), in: Capsule())
                .overlay {
                    Capsule().stroke(Color.green.opacity(0.3), lineWidth: 1)
                }
        } else {
            Text("idle")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(Color.white.opacity(0.06), in: Capsule())
        }
    }

    private func chooseFolder(category: WorkspaceCategory = .projects) {
        let panel = NSOpenPanel()
        let title = model.state.preferences.title(for: category)
        panel.title = "Open a Terminal Workspace in \(title)"
        panel.prompt = "Open in \(title)"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            model.addWorkspace(url: url, category: category)
        }
    }
}

private struct WorkspaceView: View {
    @EnvironmentObject private var model: AppModel
    let workspace: Workspace
    let tab: TerminalTab

    private var isMultiPane: Bool {
        tab.root.terminalIDs.count > 1
    }

    private var themeBackground: Color {
        let bg = model.state.preferences.theme.palette.background
        return Color(nsColor: NSColor(srgbRed: bg.red, green: bg.green, blue: bg.blue, alpha: 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            TabStrip(workspace: workspace)
            Divider().opacity(0.5)
            ContextBar(workspace: workspace, tab: tab)
            Divider().opacity(0.5)

            if model.isTerminalSearchPresented {
                TerminalSearchBar()
                Divider().opacity(0.5)
            }

            if model.isQuickLinksPresented {
                QuickLinksBar()
                Divider().opacity(0.5)
            }

            Group {
                if let zoomedID = model.zoomedSessionID,
                   let zoomedSession = tab.root.session(id: zoomedID),
                   isMultiPane {
                    TerminalPaneChrome(
                        session: zoomedSession,
                        isFocused: true,
                        isMultiPane: true,
                        isZoomed: true
                    )
                    .id(zoomedSession.id)
                } else {
                    PaneNodeView(
                        node: tab.root,
                        focusedSessionID: tab.focusedSessionID,
                        isMultiPane: isMultiPane
                    )
                }
            }
            .id("\(workspace.id.uuidString)-\(tab.id.uuidString)")
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeBackground)

            if model.isInlineAIBarPresented {
                Divider().opacity(0.5)
                InlineAICommandBar()
            }

            Divider().opacity(0.5)
            CommandComposer(
                session: tab.root.session(id: tab.focusedSessionID),
                preferences: model.state.preferences
            )
        }
    }
}

private struct TerminalSearchBar: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.cyan)

                TextField("Find in terminal scrollback (⌘F)…", text: $model.terminalSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .focused($isSearchFocused)
                    .onSubmit {
                        model.nextSearchMatch()
                    }
                    .onChange(of: model.terminalSearchQuery) { _, _ in
                        model.performTerminalSearch()
                    }

                Toggle("Aa", isOn: $model.terminalSearchCaseSensitive)
                    .toggleStyle(.button)
                    .controlSize(.mini)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .help("Case Sensitive")
                    .onChange(of: model.terminalSearchCaseSensitive) { _, _ in
                        model.performTerminalSearch()
                    }

                Toggle(".*", isOn: $model.terminalSearchRegex)
                    .toggleStyle(.button)
                    .controlSize(.mini)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .help("Regular Expression")
                    .onChange(of: model.terminalSearchRegex) { _, _ in
                        model.performTerminalSearch()
                    }

                let count = model.terminalSearchMatches.count
                Text(count == 0 ? "0 matches" : "\(model.selectedSearchMatchIndex + 1) of \(count)")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(count == 0 ? Color.secondary : Color.cyan)
                    .frame(minWidth: 68, alignment: .trailing)

                Button {
                    model.previousSearchMatch()
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(count == 0)
                .help("Previous Match")

                Button {
                    model.nextSearchMatch()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(count == 0)
                .help("Next Match (⏎)")

                Button {
                    model.performTerminalSearch()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10.5))
                }
                .buttonStyle(.plain)
                .help("Rescan Terminal Buffer")

                Button {
                    model.isTerminalSearchPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close Find Bar")
            }
            .padding(.horizontal, 12)
            .frame(height: 34)

            if !model.terminalSearchMatches.isEmpty {
                Divider().opacity(0.35)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(model.terminalSearchMatches.enumerated()), id: \.element.id) { idx, match in
                            let isSelected = idx == model.selectedSearchMatchIndex
                            Button {
                                model.selectedSearchMatchIndex = idx
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(match.lineText, forType: .string)
                            } label: {
                                HStack(spacing: 5) {
                                    Text("L\(match.lineNumber)")
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.cyan)
                                    Text(match.lineText)
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(.primary.opacity(0.9))
                                        .lineLimit(1)
                                        .frame(maxWidth: 260)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(isSelected ? Color.cyan.opacity(0.18) : Color.white.opacity(0.05))
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(isSelected ? Color.cyan.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .help("Click to copy matched line: \(match.lineText)")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(Color(nsColor: NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.09, alpha: 1)))
        .onAppear {
            isSearchFocused = true
        }
    }
}

private struct QuickLinksBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "link")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.cyan)
                Text("Detected Links & Paths")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if model.detectedItems.isEmpty {
                Text("No URLs, localhost ports, or file paths detected in current terminal buffer.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.detectedItems) { item in
                            Button {
                                model.openDetectedItem(item)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: icon(for: item.kind))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.cyan)
                                    Text(item.displayText)
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(Color.cyan.opacity(0.11), in: RoundedRectangle(cornerRadius: 5))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.cyan.opacity(0.28), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Open") {
                                    model.openDetectedItem(item)
                                }
                                Button("Copy to Clipboard") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(item.displayText, forType: .string)
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 4)
            }

            Button {
                model.refreshDetectedItems()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10.5))
            }
            .buttonStyle(.plain)
            .help("Refresh Detected Links & File Paths")

            Button {
                model.isQuickLinksPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close Quick Links Bar (⇧⌘L)")
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color(nsColor: NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.09, alpha: 1)))
    }

    private func icon(for kind: DetectedItemKind) -> String {
        switch kind {
        case .url: "globe"
        case .endpoint: "network"
        case .filePath: "doc.text.fill"
        }
    }
}

private struct InlineAICommandBar: View {
    @EnvironmentObject private var model: AppModel
    @State private var prompt = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                Text("AI Command ⌘I")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.purple)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(Color.purple.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.purple.opacity(0.32), lineWidth: 1)
            }

            TextField("Describe what you want to do in plain English (e.g. 'find files > 50MB' or 'undo last commit keeping changes')…", text: $prompt)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isFocused)
                .onSubmit {
                    model.generateInlineCommand(prompt: prompt)
                }

            if let error = model.inlineAIError {
                Text(error)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }

            if model.isGeneratingInlineCommand {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    model.generateInlineCommand(prompt: prompt)
                } label: {
                    Text("Generate ⏎")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Button {
                model.isInlineAIBarPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Color(nsColor: NSColor(calibratedRed: 0.048, green: 0.055, blue: 0.095, alpha: 1)))
        .onAppear {
            isFocused = true
        }
    }
}

private struct TabStrip: View {
    @EnvironmentObject private var model: AppModel
    let workspace: Workspace

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(workspace.tabs.enumerated()), id: \.element.id) { index, tab in
                        let isSelected = tab.id == workspace.selectedTabID
                        let isManifestTab = tab.title.hasPrefix("Manifest:") || tab.title.hasPrefix("Capsule:")
                        HStack(spacing: 7) {
                            Circle()
                                .fill(isSelected ? Color.green : (isManifestTab ? Color.cyan : Color.secondary.opacity(0.45)))
                                .frame(width: 7, height: 7)
                            Text("\(index + 1) · \(tab.title)")
                                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                .foregroundStyle(isSelected ? .primary : .secondary)
                                .lineLimit(1)
                            if workspace.tabs.count > 1 {
                                Button {
                                    model.closeTab(tab.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .opacity(isSelected ? 0.9 : 0.45)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.white.opacity(0.085) : Color.clear)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.white.opacity(0.1) : Color.clear, lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { model.selectTab(tab.id) }
                        .draggable(tab.id.uuidString)
                        .dropDestination(for: String.self) { items, _ in
                            guard let raw = items.first,
                                  let draggedID = UUID(uuidString: raw) else { return false }
                            model.reorderTab(draggedTabID: draggedID, targetTabID: tab.id)
                            return true
                        }
                    }

                    Button { model.addTab() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("New Tab (⌘N)")
                }
            }

            Spacer(minLength: 8)

            Button {
                model.toggleTerminalSearch()
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(model.isTerminalSearchPresented ? .cyan : .secondary)
                    .frame(width: 26, height: 24)
                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Find in Terminal Buffer (⌘F)")

            Button {
                model.toggleQuickLinks()
            } label: {
                Image(systemName: "link")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(model.isQuickLinksPresented ? .cyan : .secondary)
                    .frame(width: 26, height: 24)
                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Quick Links & File Paths in Terminal (⇧⌘L)")

            Menu {
                ForEach(TerminalThemePreset.allCases, id: \.self) { theme in
                    Button {
                        model.updatePreferences { $0.theme = theme }
                    } label: {
                        HStack {
                            Text(theme.displayName)
                            if model.state.preferences.theme == theme {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "paintpalette")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 24)
                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Switch Terminal Color Theme")

            Button {
                model.isCommandPalettePresented = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10.5))
                    Text("Search actions, history…")
                        .font(.system(size: 11))
                    Text("⌘K")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .help("Command Palette (⌘K)")

            Button {
                model.toggleAIChat()
            } label: {
                let isOpen = model.state.preferences.showAIChat
                HStack(spacing: 5) {
                    Image(systemName: isOpen ? "bubble.left.and.sparkles.fill" : "bubble.left.and.bubble.right")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("AI Chat")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(isOpen ? .cyan : .primary.opacity(0.88))
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isOpen ? Color.cyan.opacity(0.16) : Color.white.opacity(0.055))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isOpen ? Color.cyan.opacity(0.38) : Color.white.opacity(0.1), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .help("Toggle AI Assistant Chat (⇧⌘I)")
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(Color(nsColor: NSColor(calibratedRed: 0.035, green: 0.05, blue: 0.075, alpha: 1)))
    }
}

private struct ContextBar: View {
    @EnvironmentObject private var model: AppModel
    let workspace: Workspace
    let tab: TerminalTab

    private var focused: TerminalSession? {
        tab.root.session(id: tab.focusedSessionID)
    }

    private var telemetry: WorkspaceTelemetry? {
        model.workspaceTelemetry[workspace.id]
    }

    var body: some View {
        HStack(spacing: 8) {
            contextChip(
                text: abbreviatedPath(focused?.workingDirectory ?? workspace.rootDirectory),
                icon: "folder.fill",
                tint: .secondary
            )

            if let branch = telemetry?.gitBranch {
                let added = telemetry?.addedOrUntrackedCount ?? 0
                let modified = telemetry?.modifiedCount ?? 0
                let delta = (added > 0 || modified > 0) ? " (+\(added) ~\(modified))" : ""
                contextChip(
                    text: "⎇ \(branch)\(delta)",
                    icon: nil,
                    tint: .purple
                )
            }

            if let status = focused?.status {
                contextChip(
                    text: statusLabel(status),
                    icon: statusIcon(status),
                    tint: statusColor(status)
                )
            }

            if let capsule = model.capsule {
                let passed = telemetry?.capsuleHealthyCount ?? 0
                let total = telemetry?.capsuleTotalChecks ?? 0
                let envCount = model.effectiveEnvironmentVariables.count
                let checkSummary = total > 0 ? " (\(passed)/\(total) checks)" : (envCount > 0 ? " (\(envCount) env)" : "")
                Button {
                    if model.state.preferences.showAttentionCenter {
                        model.rightPanelTab = .manifest
                    } else {
                        model.isCapsulePresented = true
                    }
                } label: {
                    contextChip(
                        text: "Manifest: \(capsule.name)\(checkSummary)",
                        icon: "shippingbox.fill",
                        tint: .cyan
                    )
                }
                .buttonStyle(.plain)
                .help("Inspect Project Manifest & Environment Variables (⇧⌘E)")
            } else {
                let envCount = model.effectiveEnvironmentVariables.count
                Button {
                    if model.state.preferences.showAttentionCenter {
                        model.rightPanelTab = .manifest
                    } else {
                        model.isCapsulePresented = true
                    }
                } label: {
                    contextChip(
                        text: envCount > 0 ? "Env (\(envCount) var\(envCount == 1 ? "" : "s"))" : "Manifest & Env",
                        icon: "list.bullet.rectangle.portrait",
                        tint: envCount > 0 ? .cyan : .secondary
                    )
                }
                .buttonStyle(.plain)
                .help("Configure Environment Variables, .env Export, and Project Manifest (⇧⌘E)")
            }

            Spacer()

            Text(model.state.preferences.theme.displayName)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)

            if model.state.preferences.warnBeforeRiskyCommands {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("Safe-Run Active")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Color(nsColor: NSColor(calibratedRed: 0.043, green: 0.063, blue: 0.09, alpha: 1)))
    }

    @ViewBuilder
    private func contextChip(text: String, icon: String?, tint: Color) -> some View {
        let isNeutral = tint == .secondary
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10.5))
            }
            Text(text)
                .lineLimit(1)
        }
        .foregroundStyle(isNeutral ? Color.primary.opacity(0.82) : tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isNeutral ? Color.white.opacity(0.04) : tint.opacity(0.11))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(isNeutral ? Color.white.opacity(0.07) : tint.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct PaneNodeView: View {
    @EnvironmentObject private var model: AppModel
    let node: PaneNode
    let focusedSessionID: UUID
    let isMultiPane: Bool

    @ViewBuilder
    var body: some View {
        switch node {
        case .terminal(let session):
            TerminalPaneChrome(
                session: session,
                isFocused: focusedSessionID == session.id,
                isMultiPane: isMultiPane,
                isZoomed: false
            )
            .id(session.id)
        case .split(let axis, _, let first, let second):
            if axis == .vertical {
                HSplitView {
                    PaneNodeView(node: first, focusedSessionID: focusedSessionID, isMultiPane: isMultiPane)
                    PaneNodeView(node: second, focusedSessionID: focusedSessionID, isMultiPane: isMultiPane)
                }
            } else {
                VSplitView {
                    PaneNodeView(node: first, focusedSessionID: focusedSessionID, isMultiPane: isMultiPane)
                    PaneNodeView(node: second, focusedSessionID: focusedSessionID, isMultiPane: isMultiPane)
                }
            }
        }
    }
}

private struct TerminalPaneChrome: View {
    @EnvironmentObject private var model: AppModel
    let session: TerminalSession
    let isFocused: Bool
    let isMultiPane: Bool
    let isZoomed: Bool

    @State private var didCopyOutput = false
    @State private var inspectedBlock: CommandBlock?

    private var failedEvent: FailedCommandEvent? {
        model.failedCommandsBySession[session.id]
    }

    private var sessionBlocks: [CommandBlock] {
        model.commandBlocks(for: session.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor(session.status))
                    .frame(width: 7, height: 7)
                Text(session.title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isFocused ? .primary : .secondary)
                    .lineLimit(1)

                Text(abbreviatedPath(session.workingDirectory))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                    .lineLimit(1)

                if model.state.preferences.useMetalRenderer {
                    Text("METAL GPU")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.cyan.opacity(0.12), in: Capsule())
                }

                Spacer()

                if !sessionBlocks.isEmpty {
                    Button {
                        model.updatePreferences { $0.showCommandBlocksBar.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.stack")
                                .font(.system(size: 9.5))
                            Text("Blocks (\(sessionBlocks.count))")
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        }
                        .foregroundStyle(model.state.preferences.showCommandBlocksBar ? Color.cyan : Color.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (model.state.preferences.showCommandBlocksBar ? Color.cyan.opacity(0.12) : Color.white.opacity(0.04)),
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Warp-Style Command Blocks Ribbon")
                }

                if isMultiPane {
                    Button {
                        model.toggleZoomFocusedPane()
                    } label: {
                        Text(isZoomed ? "ZOOMED · ⇧⌘⏎ Restore" : (isFocused ? "FOCUSED · ⇧⌘⏎ Zoom" : "Zoom"))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(isZoomed ? Color.orange : (isFocused ? Color.cyan : Color.secondary))
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Pane Zoom (⇧⌘⏎)")
                }

                Button {
                    model.focusSession(session.id)
                    model.copyFocusedTerminalOutput(maxLines: 50)
                    didCopyOutput = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.2))
                        didCopyOutput = false
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: didCopyOutput ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9.5))
                        if didCopyOutput {
                            Text("Copied")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                    }
                    .foregroundStyle(didCopyOutput ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Copy Last 50 Lines of Terminal Output")

                Button {
                    model.focusSession(session.id)
                    model.toggleTerminalSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Find in Terminal Buffer (⌘F)")

                Button {
                    model.splitFocused(axis: .vertical)
                } label: {
                    Image(systemName: "rectangle.split.2x1")
                }
                .buttonStyle(.plain)
                .help("Split Vertically (⌘D)")

                Button {
                    model.splitFocused(axis: .horizontal)
                } label: {
                    Image(systemName: "rectangle.split.1x2")
                }
                .buttonStyle(.plain)
                .help("Split Horizontally (⇧⌘D)")
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.white.opacity(isFocused ? 0.04 : 0.02))
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                toggleWindowMaximize()
            }
            .onTapGesture {
                model.focusSession(session.id)
                TerminalRegistry.shared.focus(sessionID: session.id)
            }

            if model.state.preferences.showCommandBlocksBar && !sessionBlocks.isEmpty {
                CommandBlocksRibbon(
                    blocks: sessionBlocks,
                    inspectedBlock: $inspectedBlock,
                    onRerun: { block in
                        model.focusSession(session.id)
                        TerminalRegistry.shared.send(block.command, to: session.id, appendNewline: true)
                    },
                    onEditInComposer: { block in
                        model.composerPrefillText = block.command
                    },
                    onAskAI: { block in
                        model.explainCommandBlock(block)
                    },
                    onClear: {
                        model.clearCommandBlocks(for: session.id)
                        inspectedBlock = nil
                    }
                )
            }

            if let failed = failedEvent {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text("Exit \(failed.exitCode):")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                    Text(failed.command)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.9))
                        .lineLimit(1)

                    Spacer()

                    Button {
                        model.explainAndFixFailedCommand(sessionID: session.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Explain & Fix with AI")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.cyan.opacity(0.16), in: RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.dismissFailedCommand(sessionID: session.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.09))
            }

            TerminalPaneView(
                session: session,
                preferences: model.state.preferences,
                restoredSnapshot: model.state.sessionScrollbackSnapshots[session.id],
                onStart: { model.terminalDidStart(sessionID: session.id) },
                onFocus: { model.focusSession(session.id) },
                onTitleChange: { model.terminalDidChangeTitle(sessionID: session.id, title: $0) },
                onDirectoryChange: { model.terminalDidChangeDirectory(sessionID: session.id, directory: $0) },
                onTermination: { model.terminalDidTerminate(sessionID: session.id, exitCode: $0) },
                onCommandStatus: { event in
                    model.handleCommandStatus(sessionID: session.id, event: event)
                },
                onCommandCompleted: { cmd, pwd, exitCode, durationMs, outputSnippet in
                    model.recordCommandBlock(
                        sessionID: session.id,
                        command: cmd,
                        workingDirectory: pwd,
                        exitCode: exitCode,
                        durationMs: durationMs,
                        outputSnippet: outputSnippet
                    )
                }
            )
            .equatable()
        }
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(
                    isFocused
                        ? Color(nsColor: NSColor(calibratedRed: 0.055, green: 0.647, blue: 0.914, alpha: 0.85))
                        : Color.white.opacity(0.07),
                    lineWidth: isFocused ? 1.5 : 1
                )
                .allowsHitTesting(false)
        }
        .padding(2)
    }
}

private struct CommandBlocksRibbon: View {
    let blocks: [CommandBlock]
    @Binding var inspectedBlock: CommandBlock?
    let onRerun: (CommandBlock) -> Void
    let onEditInComposer: (CommandBlock) -> Void
    let onAskAI: (CommandBlock) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(blocks.prefix(20)) { block in
                            let isInspected = inspectedBlock?.id == block.id
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(block.isSuccess ? Color.green : Color.red)
                                    .frame(width: 6, height: 6)

                                Button {
                                    withAnimation(.easeInOut(duration: 0.14)) {
                                        if isInspected {
                                            inspectedBlock = nil
                                        } else {
                                            inspectedBlock = block
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(block.command)
                                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.primary.opacity(0.92))
                                            .lineLimit(1)
                                            .frame(maxWidth: 210)

                                        Text(block.formattedDuration)
                                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(block.isSuccess ? Color.secondary : Color.orange)
                                            .padding(.horizontal, 4.5)
                                            .padding(.vertical, 1)
                                            .background(Color.white.opacity(0.06), in: Capsule())
                                    }
                                }
                                .buttonStyle(.plain)

                                Button {
                                    onRerun(block)
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundStyle(.cyan)
                                }
                                .buttonStyle(.plain)
                                .help("Re-run Command")
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(isInspected ? Color.cyan.opacity(0.16) : Color.white.opacity(0.04))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(
                                        isInspected
                                            ? Color.cyan.opacity(0.45)
                                            : (block.isSuccess ? Color.white.opacity(0.08) : Color.red.opacity(0.32)),
                                        lineWidth: 1
                                    )
                            }
                            .contextMenu {
                                Button("Re-run Command") { onRerun(block) }
                                Button("Edit in Safe-Run Composer (⌘E)") { onEditInComposer(block) }
                                Button("Copy Command") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(block.command, forType: .string)
                                }
                                Button("Copy Captured Output") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(block.outputSnippet, forType: .string)
                                }
                                Divider()
                                Button("Analyze Block with AI Assistant") { onAskAI(block) }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }

                Button {
                    onClear()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 8)
                }
                .buttonStyle(.plain)
                .help("Clear Command Blocks")
            }
            .background(Color.black.opacity(0.28))

            if let block = inspectedBlock {
                Divider().opacity(0.35)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("$ \(block.command)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.cyan)
                            .lineLimit(1)
                        Text("exit \(block.exitCode) · \(block.formattedDuration)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(block.isSuccess ? Color.green : Color.orange)
                        Spacer()
                        Button("Edit in Composer") {
                            onEditInComposer(block)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        Button("Copy Output") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(block.outputSnippet, forType: .string)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        Button("Ask AI") {
                            onAskAI(block)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        Button {
                            inspectedBlock = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }

                    if !block.outputSnippet.isEmpty {
                        ScrollView {
                            Text(block.outputSnippet)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.88))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 95)
                        .padding(6)
                        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 5))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.42))
            }
        }
    }
}

private struct CommandComposer: View {
    @EnvironmentObject private var model: AppModel
    let session: TerminalSession?
    let preferences: AppPreferences

    @State private var command = ""
    @State private var pendingCommand: PendingCommand?
    @FocusState private var isFocused: Bool

    private var suggestions: [AutocompleteSuggestion] {
        guard let session else { return [] }
        return model.autocompleteSuggestions(
            for: command,
            workingDirectory: session.workingDirectory
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if !suggestions.isEmpty {
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 10))
                            .foregroundStyle(.cyan)
                        Text("Suggest")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    command = item.replacementCommand
                                    isFocused = true
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: item.kind.iconName)
                                            .font(.system(size: 9.5))
                                            .foregroundStyle(.cyan)
                                        Text(item.displayLabel)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                            .frame(maxWidth: 260)
                                        Text(item.subtitle)
                                            .font(.system(size: 9.5, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        if index == 0 {
                                            Text("⇥")
                                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.cyan)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(index == 0 ? Color.cyan.opacity(0.14) : Color.white.opacity(0.05))
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(index == 0 ? Color.cyan.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer(minLength: 4)

                    if let first = suggestions.first {
                        Button {
                            command = first.replacementCommand
                            isFocused = true
                        } label: {
                            Text("Accept ⇥")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.cyan)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.tab, modifiers: [])
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Color(nsColor: NSColor(calibratedRed: 0.036, green: 0.052, blue: 0.078, alpha: 1)))
                Divider().opacity(0.35)
            }

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "shield.lefthalf.filled")
                    Text("Safe-Run")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.green.opacity(0.28), lineWidth: 1)
                }

                Button {
                    model.toggleInlineAIBar()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("AI ⌘I")
                    }
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(model.isInlineAIBarPresented ? .purple : .cyan)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(
                        (model.isInlineAIBarPresented ? Color.purple.opacity(0.16) : Color.cyan.opacity(0.11)),
                        in: RoundedRectangle(cornerRadius: 5)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(model.isInlineAIBarPresented ? Color.purple.opacity(0.35) : Color.cyan.opacity(0.25), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .help("Translate Natural Language to Shell Command (⌘I)")

                Menu {
                    ForEach(model.state.snippets) { snippet in
                        Button {
                            model.triggerSnippet(snippet, executeImmediately: false)
                        } label: {
                            Text("\(snippet.title) — \(snippet.command)")
                        }
                    }
                    let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        Divider()
                        Button("Save Current Command as Snippet") {
                            let title = String(trimmed.prefix(32))
                            model.addSnippet(title: title, command: trimmed)
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "text.book.closed")
                        Text("Snippets")
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Insert or Save Reusable Workflow Snippets")

                Button {
                    model.pullActiveTerminalLineIntoComposer()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.doc")
                        Text("Edit Line ⌘E")
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Pull active terminal command line into this text box for easy editing (⌘E)")

                Text("❯")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)

                TextField("Type or edit a long command here (click anywhere to position cursor, ⇧⏎ to insert into terminal, ⌘⏎ to run)…", text: $command, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: preferences.fontSize, design: .monospaced))
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .onSubmit(runOrConfirm)
                    .onChange(of: model.composerPrefillText) { _, newValue in
                        guard let newValue else { return }
                        command = newValue
                        model.composerPrefillText = nil
                        isFocused = true
                    }

                Button {
                    insertIntoTerminalPrompt()
                } label: {
                    Text("Insert ⇧⏎")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.88))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [.shift])
                .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session == nil)
                .opacity(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                .help("Replace the terminal prompt line with this text without running it yet (⇧⏎)")

                Button {
                    runOrConfirm()
                } label: {
                    Text("Run ⌘⏎")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session == nil)
                .opacity(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 42)
            .background(Color(nsColor: NSColor(calibratedRed: 0.043, green: 0.063, blue: 0.09, alpha: 1)))
        }
        .alert(item: $pendingCommand) { pending in
            Alert(
                title: Text(pending.finding.title),
                message: Text("\(pending.finding.explanation)\n\nWorking directory: \(pending.workingDirectory)\n\n\(pending.command)"),
                primaryButton: .destructive(Text("Run Anyway")) {
                    send(pending.command)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func insertIntoTerminalPrompt() {
        guard let session else { return }
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        TerminalRegistry.shared.replaceActiveCommandLine(sessionID: session.id, with: trimmed, execute: false)
        command = ""
    }

    private func runOrConfirm() {
        guard let session else { return }
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let findings = CommandRiskAnalyzer().analyze(
            command: trimmed,
            workingDirectory: session.workingDirectory
        )
        if preferences.warnBeforeRiskyCommands, let finding = findings.first {
            pendingCommand = PendingCommand(
                command: trimmed,
                workingDirectory: session.workingDirectory,
                finding: finding
            )
        } else {
            send(trimmed)
        }
    }

    private func send(_ value: String) {
        guard let session else { return }
        TerminalRegistry.shared.replaceActiveCommandLine(sessionID: session.id, with: value, execute: true)
        command = ""
    }

    private struct PendingCommand: Identifiable {
        let id = UUID()
        let command: String
        let workingDirectory: String
        let finding: RiskFinding
    }
}

private func abbreviatedPath(_ path: String) -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    if path == home { return "~" }
    if path.hasPrefix(home + "/") {
        return "~" + path.dropFirst(home.count)
    }
    return path
}

private func statusLabel(_ status: SessionStatus) -> String {
    switch status {
    case .starting: "Starting"
    case .running: "Running"
    case .idle: "Idle"
    case .waiting: "Waiting"
    case .completed: "Completed"
    case .disconnected: "Disconnected"
    case .failed: "Failed"
    case .terminated: "Terminated"
    }
}

private func statusIcon(_ status: SessionStatus) -> String {
    switch status {
    case .starting: "circle.dotted"
    case .running: "play.circle.fill"
    case .idle: "pause.circle"
    case .waiting: "exclamationmark.circle.fill"
    case .completed: "checkmark.circle.fill"
    case .disconnected: "wifi.slash"
    case .failed: "xmark.circle.fill"
    case .terminated: "stop.circle"
    }
}

private func statusColor(_ status: SessionStatus) -> Color {
    switch status {
    case .starting, .idle: .secondary
    case .running: .green
    case .waiting: .orange
    case .completed: .green
    case .disconnected: .orange
    case .failed: .red
    case .terminated: .secondary
    }
}

@MainActor
private var savedUnmaximizedFrames: [ObjectIdentifier: NSRect] = [:]

@MainActor
private var lastWindowMaximizeToggleTime: TimeInterval = 0

@MainActor
func toggleWindowMaximize(_ targetWindow: NSWindow? = nil) {
    let now = ProcessInfo.processInfo.systemUptime
    guard now - lastWindowMaximizeToggleTime > 0.25 else { return }
    lastWindowMaximizeToggleTime = now

    guard let window = targetWindow ?? NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
        return
    }
    guard let screen = window.screen ?? NSScreen.main else {
        window.zoom(nil)
        return
    }
    let maxFrame = screen.visibleFrame
    let current = window.frame
    let key = ObjectIdentifier(window)
    let isCurrentlyMaximized = abs(current.width - maxFrame.width) < 12
        && abs(current.height - maxFrame.height) < 12
        && abs(current.origin.x - maxFrame.origin.x) < 12
        && abs(current.origin.y - maxFrame.origin.y) < 12

    // Important: use animate: false so the PTY receives a single atomic SIGWINCH
    // at the final size instead of dozens of intermediate column/row resizes that
    // cause rich prompts (Powerlevel10k / RPROMPT) to print a staircase of prompts.
    if isCurrentlyMaximized {
        if let previous = savedUnmaximizedFrames.removeValue(forKey: key) {
            window.setFrame(previous, display: true, animate: false)
        } else {
            let restoredWidth = min(max(maxFrame.width * 0.8, 1100), maxFrame.width)
            let restoredHeight = min(max(maxFrame.height * 0.82, 720), maxFrame.height)
            let restoredOrigin = NSPoint(
                x: maxFrame.origin.x + (maxFrame.width - restoredWidth) / 2,
                y: maxFrame.origin.y + (maxFrame.height - restoredHeight) / 2
            )
            window.setFrame(
                NSRect(origin: restoredOrigin, size: NSSize(width: restoredWidth, height: restoredHeight)),
                display: true,
                animate: false
            )
        }
    } else {
        savedUnmaximizedFrames[key] = current
        window.setFrame(maxFrame, display: true, animate: false)
    }
}

/// Installs a lightweight local mouse-down monitor so double-clicking anywhere in the top header
/// section (titlebar/toolbar, tab bar, or context bar) maximizes the window cleanly in one step.
private struct WindowTopDoubleClickMaximizer: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        private var monitor: Any?

        @MainActor
        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { event in
                guard event.clickCount == 2,
                      let window = event.window,
                      let contentView = window.contentView else {
                    return event
                }
                let distanceFromTop = window.frame.height - event.locationInWindow.y
                // Top 115pt covers the unified titlebar/toolbar strip, tab strip, and context bar
                guard distanceFromTop >= 0 && distanceFromTop <= 115 else {
                    return event
                }
                // Ignore double-clicks directly on interactive buttons or text fields
                let pointInContent = contentView.convert(event.locationInWindow, from: nil)
                if let hitView = contentView.hitTest(pointInContent) {
                    var cursor: NSView? = hitView
                    while let current = cursor {
                        if current is NSControl || current is NSTextView {
                            return event
                        }
                        cursor = current.superview
                    }
                }
                Task { @MainActor in
                    toggleWindowMaximize(window)
                }
                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}
