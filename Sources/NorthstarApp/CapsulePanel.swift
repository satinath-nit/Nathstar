import NorthstarCore
import SwiftUI

struct CapsulePanel: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmActivation = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 740, idealWidth: 800, minHeight: 640, idealHeight: 740)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Activate project manifest?", isPresented: $confirmActivation) {
            Button("Cancel", role: .cancel) {}
            Button("Run Commands") { model.activateCapsule() }
        } message: {
            Text(activationMessage)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.Below.ecg.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.title2)
                .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.capsule?.name ?? "Project Manifest & Environment")
                    .font(.headline)
                Text("Portable project setup (.nathstar/manifest.json) & workspace environment (.env)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Reload") { model.reloadCapsule() }
            if model.capsule != nil {
                Button("Show in Finder") { model.revealCapsule() }
                Button("Activate") { confirmActivation = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.capsuleInspection?.canActivate != true || activationCommands.isEmpty)
            } else {
                Button("Create Manifest File") { model.createCapsuleTemplate() }
                    .buttonStyle(.borderedProminent)
            }
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if let error = model.capsuleError {
                    GroupBox {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.callout)
                            Spacer()
                            Button("Show in Finder") { model.revealCapsule() }
                            Button("Reload") { model.reloadCapsule() }
                        }
                    }
                }

                // Always show the interactive Environment Variables form + .env exporter
                GroupBox {
                    EnvironmentVariablesEditorView(compact: false)
                        .environmentObject(model)
                        .padding(.top, 4)
                } label: {
                    Label("Environment Variables & .env Export", systemImage: "list.bullet.rectangle.portrait")
                }

                if let capsule = model.capsule {
                    if !capsule.description.isEmpty {
                        Text(capsule.description)
                            .foregroundStyle(.secondary)
                    }
                    readiness(capsule)
                    commandSection(
                        title: "Startup Commands",
                        icon: "play.fill",
                        commands: capsule.startupCommands,
                        showsRun: true
                    )
                    servicesSection(capsule.services)
                    commandSection(
                        title: "Health Checks",
                        icon: "waveform.path.ecg",
                        commands: capsule.healthChecks,
                        showsRun: true
                    )
                    commandSection(
                        title: "Useful Commands",
                        icon: "command",
                        commands: capsule.usefulCommands,
                        showsRun: true
                    )
                    instructionsSection(capsule.agentInstructions)
                } else {
                    GroupBox {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.badge.gearshape")
                                .font(.title2)
                                .foregroundStyle(.cyan)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("No .nathstar/manifest.json file yet")
                                    .fontWeight(.semibold)
                                Text("You can already add environment variables and export them to .env above, or generate a version-controlled Manifest template for startup commands, services, and health checks.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Create Manifest Template") { model.createCapsuleTemplate() }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 6)
                    } label: {
                        Label("Project Manifest", systemImage: "shippingbox")
                    }
                }
            }
            .padding(18)
        }
    }

    private func readiness(_ capsule: EnvironmentCapsule) -> some View {
        GroupBox("Readiness") {
            VStack(alignment: .leading, spacing: 8) {
                if let inspection = model.capsuleInspection {
                    if inspection.tools.isEmpty && inspection.issues.isEmpty {
                        Label("Manifest is ready", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    ForEach(inspection.tools) { status in
                        Label {
                            HStack {
                                Text(status.tool.name).fontWeight(.medium)
                                Spacer()
                                Text(status.executablePath ?? "Not found")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        } icon: {
                            Image(systemName: status.executablePath == nil ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(status.executablePath == nil ? .orange : .green)
                        }
                    }
                    ForEach(inspection.issues) { issue in
                        Label(issue.message, systemImage: issue.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(issue.severity == .error ? .red : .orange)
                    }
                }
                LabeledContent("Layout", value: capsule.layout.rawValue.capitalized)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func commandSection(
        title: String,
        icon: String,
        commands: [CapsuleCommand],
        showsRun: Bool
    ) -> some View {
        if !commands.isEmpty {
            GroupBox {
                VStack(spacing: 0) {
                    ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                        commandRow(command, showsRun: showsRun)
                        if index < commands.count - 1 { Divider() }
                    }
                }
            } label: {
                Label(title, systemImage: icon)
            }
        }
    }

    @ViewBuilder
    private func servicesSection(_ services: [CapsuleService]) -> some View {
        if !services.isEmpty {
            GroupBox {
                VStack(spacing: 0) {
                    ForEach(Array(services.enumerated()), id: \.element.id) { index, service in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: service.autoStart ? "bolt.circle.fill" : "circle")
                                .foregroundStyle(service.autoStart ? .green : .secondary)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(service.name).fontWeight(.medium)
                                    if service.autoStart {
                                        Text("AUTO-START")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.green)
                                    }
                                }
                                Text(service.command)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                if let healthCheck = service.healthCheck {
                                    Text("Health: \(healthCheck)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Run") {
                                model.runCapsuleCommand(
                                    CapsuleCommand(
                                        name: service.name,
                                        command: service.command,
                                        workingDirectory: service.workingDirectory
                                    )
                                )
                            }
                            .disabled(model.capsuleInspection?.canActivate != true)
                        }
                        .padding(.vertical, 9)
                        if index < services.count - 1 { Divider() }
                    }
                }
            } label: {
                Label("Services", systemImage: "server.rack")
            }
        }
    }

    private func commandRow(_ command: CapsuleCommand, showsRun: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(command.name).fontWeight(.medium)
                Text(command.command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if let directory = command.workingDirectory {
                    Label(directory, systemImage: "folder")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if showsRun {
                Button("Run") { model.runCapsuleCommand(command) }
                    .disabled(model.capsuleInspection?.canActivate != true)
            }
        }
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private func instructionsSection(_ instructions: [String]) -> some View {
        if !instructions.isEmpty {
            GroupBox("Agent Instructions") {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(instructions, id: \.self) { instruction in
                        Label(instruction, systemImage: "sparkles")
                            .font(.callout)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var activationCommands: [CapsuleCommand] {
        guard let capsule = model.capsule else { return [] }
        return capsule.startupCommands + capsule.services.filter(\.autoStart).map {
            CapsuleCommand(name: $0.name, command: $0.command, workingDirectory: $0.workingDirectory)
        }
    }

    private var activationMessage: String {
        let commands = activationCommands.map { "• \($0.name): \($0.command)" }.joined(separator: "\n")
        return "Nathstar will open and run these commands in the current workspace:\n\n\(commands)"
    }
}

struct EnvironmentVariablesEditorView: View {
    @EnvironmentObject private var model: AppModel
    let compact: Bool

    @State private var newKey = ""
    @State private var newValue = ""
    @State private var showNewValue = false
    @State private var revealedKeys: Set<String> = []
    @State private var revealAll = false
    @State private var isPreviewPresented = false
    @State private var applyImmediately = true
    @State private var validationError: String?

    private var sortedVariables: [(key: String, value: String)] {
        model.effectiveEnvironmentVariables
            .map { (key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Input form
            if compact {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("KEY (e.g. PORT)", text: $newKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11.5, design: .monospaced))
                    HStack(spacing: 4) {
                        Group {
                            if showNewValue {
                                TextField("VALUE (e.g. 3000)", text: $newValue)
                            } else {
                                SecureField("VALUE (masked)", text: $newValue)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11.5, design: .monospaced))
                        .onSubmit(addOrUpdateVariable)

                        Button {
                            showNewValue.toggle()
                        } label: {
                            Image(systemName: showNewValue ? "eye.slash" : "eye")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .help(showNewValue ? "Hide value" : "Show value")
                    }
                    HStack(spacing: 6) {
                        Toggle("Export to active shell", isOn: $applyImmediately)
                            .font(.system(size: 10.5))
                            .toggleStyle(.checkbox)
                        Spacer()
                        Button("Set Variable") {
                            addOrUpdateVariable()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    TextField("KEY (e.g. PORT, NODE_ENV)", text: $newKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: 220)
                    Text("=")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Group {
                            if showNewValue {
                                TextField("VALUE (e.g. 3000, development)", text: $newValue)
                            } else {
                                SecureField("VALUE (masked)", text: $newValue)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit(addOrUpdateVariable)

                        Button {
                            showNewValue.toggle()
                        } label: {
                            Image(systemName: showNewValue ? "eye.slash" : "eye")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help(showNewValue ? "Hide value" : "Show value")
                    }
                    Toggle("Export to active shell", isOn: $applyImmediately)
                        .font(.caption)
                        .toggleStyle(.checkbox)
                    Button("Set Variable") {
                        addOrUpdateVariable()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if let validationError {
                Text(validationError)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let statusMessage = model.envStatusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.cyan)
            }

            // Action buttons for applying to shell, previewing, exporting/importing .env, and revealing all values
            if compact {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Button {
                            model.applyEnvironmentToFocusedTerminal()
                        } label: {
                            Label("Apply", systemImage: "terminal")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.small)
                        .disabled(sortedVariables.isEmpty)
                        .help("Run export KEY=VALUE in the currently focused terminal pane")

                        Button {
                            isPreviewPresented = true
                        } label: {
                            Label("Preview .env", systemImage: "doc.text.magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.small)
                        .help("Preview KEY=VALUE content in a temporary window (Esc to close)")
                    }

                    HStack(spacing: 6) {
                        Button {
                            model.exportEnvironmentToDotEnv(revealInFinder: false)
                        } label: {
                            Label("Export .env", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.small)
                        .disabled(sortedVariables.isEmpty)
                        .help("Write all environment variables to .env in the workspace root folder")

                        if model.hasDotEnvFile {
                            Button {
                                model.importEnvironmentFromDotEnv()
                            } label: {
                                Label("Load .env", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.small)
                            .help("Import KEY=VALUE pairs from the workspace .env file")
                        }
                    }

                    if !sortedVariables.isEmpty {
                        HStack {
                            Spacer()
                            Button {
                                revealAll.toggle()
                                if !revealAll {
                                    revealedKeys.removeAll()
                                }
                            } label: {
                                Label(revealAll ? "Hide All" : "Show All", systemImage: revealAll ? "eye.slash" : "eye")
                            }
                            .controlSize(.small)
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Button {
                        model.applyEnvironmentToFocusedTerminal()
                    } label: {
                        Label("Apply to Terminal", systemImage: "terminal")
                    }
                    .controlSize(.small)
                    .disabled(sortedVariables.isEmpty)
                    .help("Run export KEY=VALUE in the currently focused terminal pane")

                    Button {
                        isPreviewPresented = true
                    } label: {
                        Label("Preview .env", systemImage: "doc.text.magnifyingglass")
                    }
                    .controlSize(.small)
                    .help("Preview KEY=VALUE content in a temporary window (Esc to close)")

                    Button {
                        model.exportEnvironmentToDotEnv(revealInFinder: true)
                    } label: {
                        Label("Export .env", systemImage: "square.and.arrow.up")
                    }
                    .controlSize(.small)
                    .disabled(sortedVariables.isEmpty)
                    .help("Write all environment variables to .env in the workspace root folder")

                    if model.hasDotEnvFile {
                        Button {
                            model.importEnvironmentFromDotEnv()
                        } label: {
                            Label("Load .env", systemImage: "square.and.arrow.down")
                        }
                        .controlSize(.small)
                        .help("Import KEY=VALUE pairs from the workspace .env file")
                    }

                    if !sortedVariables.isEmpty {
                        Spacer(minLength: 4)
                        Button {
                            revealAll.toggle()
                            if !revealAll {
                                revealedKeys.removeAll()
                            }
                        } label: {
                            Label(revealAll ? "Hide All" : "Show All", systemImage: revealAll ? "eye.slash" : "eye")
                        }
                        .controlSize(.small)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help(revealAll ? "Mask all environment variable values" : "Reveal all environment variable values")
                    }
                }
            }

            if sortedVariables.isEmpty {
                Text("No environment variables configured yet. Add a KEY and VALUE above to inject into terminals or export to .env.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 4) {
                    ForEach(sortedVariables, id: \.key) { item in
                        let isVisible = revealAll || revealedKeys.contains(item.key)
                        HStack(spacing: 8) {
                            Text(item.key)
                                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.primary)
                            Text("=")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            if isVisible {
                                Text(item.value)
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .textSelection(.enabled)
                            } else {
                                Text(maskedDisplay(for: item.value))
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            if CapsuleInspector.appearsSecret(key: item.key) {
                                Text("LOCAL")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.14), in: Capsule())
                                    .help("Stored locally & exported to .env, excluded from manifest.json")
                            }
                            Button {
                                if revealAll {
                                    revealAll = false
                                    revealedKeys = Set(sortedVariables.map(\.key)).subtracting([item.key])
                                } else if revealedKeys.contains(item.key) {
                                    revealedKeys.remove(item.key)
                                } else {
                                    revealedKeys.insert(item.key)
                                }
                            } label: {
                                Image(systemName: isVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(isVisible ? Color.cyan : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(isVisible ? "Hide value for \(item.key)" : "Show value for \(item.key)")

                            Button {
                                newKey = item.key
                                newValue = item.value
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Edit \(item.key)")

                            Button {
                                model.removeEnvironmentVariable(key: item.key)
                                revealedKeys.remove(item.key)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.red.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                            .help("Remove \(item.key)")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .sheet(isPresented: $isPreviewPresented) {
            EnvironmentPreviewSheet()
                .environmentObject(model)
        }
    }

    private func maskedDisplay(for value: String) -> String {
        guard !value.isEmpty else { return "(empty)" }
        let count = min(max(value.count, 6), 12)
        return String(repeating: "•", count: count)
    }

    private func addOrUpdateVariable() {
        if let err = model.setEnvironmentVariable(
            key: newKey,
            value: newValue,
            applyToTerminal: applyImmediately
        ) {
            validationError = err
        } else {
            validationError = nil
            newKey = ""
            newValue = ""
            showNewValue = false
        }
    }
}

struct EnvironmentPreviewSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var workspaceName: String {
        model.selectedWorkspace?.name ?? "workspace"
    }

    private var dotEnvDiskContent: String? {
        guard let url = model.dotEnvFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let content = try? String(contentsOf: url, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return content
    }

    private var previewText: String {
        let vars = model.effectiveEnvironmentVariables
        if !vars.isEmpty {
            return CapsuleStore.formatDotEnvContent(variables: vars, workspaceName: workspaceName)
        }
        if let disk = dotEnvDiskContent {
            return disk
        }
        return "# No environment variables configured yet.\n# Add KEY and VALUE pairs or click 'Load .env' to import from disk.\n"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preview .env — \(workspaceName)")
                        .font(.headline)
                    Text("Temporary read-only preview · Press Esc to close")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(previewText, forType: .string)
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .controlSize(.small)

                Button("Close (Esc)") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(14)
            .background(Color(nsColor: NSColor(calibratedRed: 0.035, green: 0.05, blue: 0.075, alpha: 1)))

            Divider().opacity(0.5)

            ScrollView {
                Text(previewText)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.92))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(Color(nsColor: NSColor(calibratedRed: 0.024, green: 0.035, blue: 0.055, alpha: 1)))
        }
        .frame(width: 560, height: 400)
        .onExitCommand {
            dismiss()
        }
    }
}
