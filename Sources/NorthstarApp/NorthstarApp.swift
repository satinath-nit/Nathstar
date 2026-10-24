import AppKit
import Carbon
import SwiftUI

@main
struct NathstarApp: App {
    @NSApplicationDelegateAdaptor(NathstarAppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Nathstar", id: "main") {
            RootView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 620)
                .preferredColorScheme(.dark)
                .background(MainWindowTracker())
                .onAppear {
                    NathstarAppDelegate.sharedModel = model
                    NathstarWindowController.openMainWindowAction = {
                        openWindow(id: "main")
                    }
                }
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") { model.addTab() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open Nathstar Terminal") {
                    NathstarWindowController.restoreOrFocusWindow()
                }
                .keyboardShortcut("t", modifiers: .command)
                Button("Open Folder as Workspace…") { openWorkspace() }
                    .keyboardShortcut("o", modifiers: .command)
                Divider()
                Button("Close Window") {
                    NathstarWindowController.closeActiveWindow()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit Nathstar") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            CommandMenu("Terminal") {
                Button("New Tab") { model.addTab() }
                    .keyboardShortcut("n", modifiers: .command)
                Divider()
                Button("Find in Terminal Buffer…") { model.toggleTerminalSearch() }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Quick Links & File Paths…") { model.toggleQuickLinks() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Inline AI Command Generator…") { model.toggleInlineAIBar() }
                    .keyboardShortcut("i", modifiers: .command)
                Button("Edit Active Command Line in Composer") { model.pullActiveTerminalLineIntoComposer() }
                    .keyboardShortcut("e", modifiers: .command)
                Divider()
                Button("Split Vertically") { model.splitFocused(axis: .vertical) }
                    .keyboardShortcut("d", modifiers: .command)
                Button("Split Horizontally") { model.splitFocused(axis: .horizontal) }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Button("Equalize Split Panes") { model.equalizeSplits() }
                    .keyboardShortcut("=", modifiers: [.command, .shift])
                Button("Toggle Pane Zoom") { model.toggleZoomFocusedPane() }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                Divider()
                Button("Close Focused Pane") { model.closeFocusedPane() }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                Button("Close Window") {
                    NathstarWindowController.closeActiveWindow()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            CommandMenu("Navigate") {
                Button("Open Nathstar Terminal (or Double-Tap ⌃)") {
                    NathstarWindowController.restoreOrFocusWindow()
                }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Command Palette") { model.isCommandPalettePresented = true }
                    .keyboardShortcut("k", modifiers: .command)
                Button(model.state.preferences.isSidebarPinned ? "Collapse Sidebar (Hover Mode)" : "Pin Sidebar Open") {
                    model.updatePreferences { $0.isSidebarPinned.toggle() }
                }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Button("Toggle Attention Center") {
                    model.updatePreferences { $0.showAttentionCenter.toggle() }
                }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                Button("Live Ports & Processes") {
                    model.openPortsPanel()
                }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Button("Toggle AI Assistant Chat") {
                    model.toggleAIChat()
                }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                Button("Project Manifest & Environment") {
                    model.reloadCapsule()
                    model.isCapsulePresented = true
                }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }

    private func openWorkspace() {
        let panel = NSOpenPanel()
        panel.title = "Open a Terminal Workspace"
        panel.prompt = "Open Workspace"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            model.addWorkspace(url: url)
        }
    }
}

@MainActor
private struct MainWindowTracker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                NathstarWindowController.configureMainWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                NathstarWindowController.configureMainWindow(window)
            }
        }
    }
}

@MainActor
final class MainWindowCloseInterceptor: NSObject, NSWindowDelegate {
    static let shared = MainWindowCloseInterceptor()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide the window on red button click / performClose so all live PTY sessions remain intact
        // and the window can be reopened instantly from the Dock icon, ⌘T, or Double-Tap ⌃.
        NathstarWindowController.primaryWindow = sender
        sender.orderOut(nil)
        return false
    }
}

@MainActor
enum NathstarWindowController {
    static var primaryWindow: NSWindow?
    static var openMainWindowAction: (() -> Void)?

    static func configureMainWindow(_ window: NSWindow) {
        guard window.title != "Settings" else { return }
        if let existing = primaryWindow, existing !== window {
            // Ensure only one main Nathstar window exists
            window.orderOut(nil)
            window.close()
            return
        }
        primaryWindow = window
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        if window.delegate !== MainWindowCloseInterceptor.shared {
            window.delegate = MainWindowCloseInterceptor.shared
        }
    }

    static func trackWindowIfNeeded(_ window: NSWindow?) {
        guard let window else { return }
        configureMainWindow(window)
    }

    static func closeActiveWindow() {
        if let target = NSApp.keyWindow ?? NSApp.mainWindow ?? primaryWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
            if target.title != "Settings" {
                configureMainWindow(target)
                target.orderOut(nil)
            } else {
                target.close()
            }
        }
    }

    static func minimizeActiveWindow() {
        if let target = NSApp.keyWindow ?? NSApp.mainWindow ?? primaryWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
            primaryWindow = target
            target.miniaturize(nil)
        }
    }

    static func restoreOrFocusWindow(triggeredByHotkey: Bool = false) {
        let visorMode = NathstarAppDelegate.sharedModel?.state.preferences.enableQuakeVisorMode ?? false
        if triggeredByHotkey,
           visorMode,
           NSApp.isActive,
           let active = primaryWindow ?? NSApp.keyWindow,
           active.isVisible {
            active.orderOut(nil)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        if let minimized = NSApp.windows.first(where: { $0.isMiniaturized }) {
            minimized.deminiaturize(nil)
            if visorMode {
                applyQuakeVisorFrame(to: minimized)
            }
            minimized.makeKeyAndOrderFront(nil)
            minimized.orderFrontRegardless()
            primaryWindow = minimized
            return
        }
        if let existing = primaryWindow ?? NSApp.windows.first(where: { $0.title != "Settings" && $0.canBecomeMain }) ?? NSApp.windows.first(where: { $0.title != "Settings" }) {
            if existing.isMiniaturized {
                existing.deminiaturize(nil)
            }
            if visorMode {
                applyQuakeVisorFrame(to: existing)
            }
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            primaryWindow = existing
            return
        }
        openMainWindowAction?()
    }

    static func applyQuakeVisorFrame(to window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? window.screen
            ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }
        let visorHeight = max(620, round(visibleFrame.height * 0.62))
        let visorFrame = NSRect(
            x: visibleFrame.minX,
            y: visibleFrame.maxY - visorHeight,
            width: visibleFrame.width,
            height: visorHeight
        )
        window.setFrame(visorFrame, display: true, animate: true)
    }
}

@MainActor
final class NathstarAppDelegate: NSObject, NSApplicationDelegate {
    static weak var sharedModel: AppModel?

    private var keyMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var modifierPollTimer: Timer?
    private var carbonHotKeyRef: EventHotKeyRef?
    private var carbonEventHandler: EventHandlerRef?

    private var wasControlDownInPoll = false
    private var lastControlReleaseTime: TimeInterval = 0
    private var controlPressStartTime: TimeInterval = 0
    private var controlWasPressedAlone = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            NathstarWindowController.trackWindowIfNeeded(NSApp.windows.first)
        }
        installShortcutMonitor()
        installDoubleTapControlMonitor()
        installCarbonGlobalHotKey()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.sharedModel?.persistImmediateSnapshotBeforeQuit()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NathstarWindowController.restoreOrFocusWindow()
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        let hasVisibleMain = NSApp.windows.contains { $0.isVisible && $0.title != "Settings" }
        if !hasVisibleMain {
            NathstarWindowController.restoreOrFocusWindow()
        }
    }

    private func installShortcutMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // If any regular key is pressed while Control is held, cancel the standalone Control tap
            self.controlWasPressedAlone = false

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags == [.command],
                  let chars = event.charactersIgnoringModifiers?.lowercased() else {
                return event
            }
            if chars == "w" {
                NathstarWindowController.closeActiveWindow()
                return nil
            }
            if chars == "q" {
                NSApp.terminate(nil)
                return nil
            }
            if chars == "t" {
                NathstarWindowController.restoreOrFocusWindow()
                return nil
            }
            return event
        }
    }

    /// Listens both locally and globally for a double-tap of `⌃` (Control) using:
    /// 1. `CGEventSource.flagsState(.combinedSessionState)` hardware modifier polling (works across all apps with zero Accessibility/Input Monitoring permissions required!)
    /// 2. `NSEvent` local & global flag monitors as immediate reinforcement.
    private func installDoubleTapControlMonitor() {
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event)
            }
        }
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
            Task { @MainActor in
                self?.controlWasPressedAlone = false
            }
        }

        // Poll hardware modifier flags at 60Hz via CGEventSource — works system-wide even without Accessibility permissions
        modifierPollTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollHardwareControlModifier()
            }
        }
    }

    private func pollHardwareControlModifier() {
        if let model = Self.sharedModel, !model.state.preferences.enableDoubleTapControlHotkey {
            return
        }

        let cgFlags = CGEventSource.flagsState(.combinedSessionState)
        let isControlDown = cgFlags.contains(.maskControl)
        let hasOtherModifiers = cgFlags.contains(.maskCommand)
            || cgFlags.contains(.maskAlternate)
            || cgFlags.contains(.maskShift)

        if hasOtherModifiers {
            controlWasPressedAlone = false
            wasControlDownInPoll = isControlDown
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        if isControlDown && !wasControlDownInPoll {
            // Control just pressed down
            wasControlDownInPoll = true
            controlWasPressedAlone = true
            controlPressStartTime = now
        } else if !isControlDown && wasControlDownInPoll {
            // Control just released
            wasControlDownInPoll = false
            let holdDuration = now - controlPressStartTime
            guard controlWasPressedAlone && holdDuration < 0.35 else {
                controlWasPressedAlone = false
                return
            }
            controlWasPressedAlone = false
            let delta = now - lastControlReleaseTime
            if delta > 0.04 && delta <= 0.45 {
                lastControlReleaseTime = 0
                NathstarWindowController.restoreOrFocusWindow(triggeredByHotkey: true)
            } else {
                lastControlReleaseTime = now
            }
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        if let model = Self.sharedModel, !model.state.preferences.enableDoubleTapControlHotkey {
            return
        }

        guard event.keyCode == 59 || event.keyCode == 62 else {
            controlWasPressedAlone = false
            return
        }

        let flags = event.modifierFlags.intersection([.control, .command, .option, .shift])
        let now = ProcessInfo.processInfo.systemUptime
        if flags == [.control] {
            wasControlDownInPoll = true
            controlWasPressedAlone = true
            controlPressStartTime = now
        } else if flags.isEmpty && controlWasPressedAlone {
            wasControlDownInPoll = false
            controlWasPressedAlone = false
            let delta = now - lastControlReleaseTime
            if delta > 0.04 && delta <= 0.45 {
                lastControlReleaseTime = 0
                NathstarWindowController.restoreOrFocusWindow(triggeredByHotkey: true)
            } else {
                lastControlReleaseTime = now
            }
        } else {
            controlWasPressedAlone = false
        }
    }

    /// Also registers `⌃` + `` ` `` (Control + Backtick) via Carbon `RegisterEventHotKey` as a secondary zero-permission global shortcut.
    private func installCarbonGlobalHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handler: EventHandlerUPP = { _, _, _ in
            Task { @MainActor in
                NathstarWindowController.restoreOrFocusWindow(triggeredByHotkey: true)
            }
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &carbonEventHandler
        )
        let hotKeyID = EventHotKeyID(signature: OSType(0x4E54_4853), id: 1) // 'NTHS'
        RegisterEventHotKey(
            UInt32(kVK_ANSI_Grave),
            UInt32(controlKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &carbonHotKeyRef
        )
    }
}
