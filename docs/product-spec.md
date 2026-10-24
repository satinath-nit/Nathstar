# Product Specification: Native macOS Terminal Workspace

**Working name:** Nathstar Terminal  
**Status:** Draft v0.1  
**Date:** October 22, 2026  
**Primary platform:** macOS 15 and later  
**Distribution:** Signed and notarized direct download; Homebrew Cask after public launch  

> The Mac terminal that always knows what you are working on, what is running, what failed, and what needs your attention.

## 1. Executive Summary

Nathstar is a native macOS terminal workspace designed around projects, tasks, and attention rather than disposable windows and scrollback. It combines a fast, standards-compliant terminal with persistent project workspaces, structured command history, session recovery, and a unified view of processes or coding agents that need the user's attention.

The product will not attempt to win by offering the most settings or by replacing the shell with a proprietary command language. Its advantage will be reducing the cognitive work required to start, understand, resume, and safely complete command-line work.

The first release targets Mac developers who regularly work across several repositories, development servers, SSH sessions, and CLI coding agents. Nathstar must remain a trustworthy terminal first: normal shells, TUIs, editors, multiplexers, keyboard workflows, and escape sequences must work without requiring an account or cloud service.

## 2. Product Thesis

Existing terminal products tend to optimize one of four areas:

- Rendering speed and terminal compatibility
- Configuration depth and extensibility
- Cross-platform multiplexing
- AI-assisted and collaborative workflows

Nathstar will differentiate through **context continuity**:

1. Work is organized by project rather than by window.
2. Sessions and layouts survive app restarts.
3. Commands are understandable objects, not anonymous lines in scrollback.
4. The app identifies what completed, failed, disconnected, or needs approval.
5. Assistance is transparent, optional, and safety-aware.
6. The interface behaves like a first-class macOS application.

## 3. Product Principles

### 3.1 Terminal first

If Nathstar cannot accurately run a user's existing terminal workflow, no higher-level feature matters. Shells, SSH, tmux, Vim, Neovim, Emacs, REPLs, full-screen TUIs, mouse input, Unicode, emoji, ligatures, hyperlinks, clipboard sequences, and image protocols must behave predictably.

### 3.2 Projects over windows

The main organizational unit is a workspace connected to a directory, repository, remote host, or user-defined activity. Windows, tabs, and panes are views into that workspace.

### 3.3 Progressive power

The default experience must be useful with no configuration. Advanced functionality should be discoverable through the command palette, contextual actions, and settings rather than memorized configuration syntax.

### 3.4 Local-first and private

Core terminal functionality, workspaces, command metadata, search, risk detection, and session restoration operate locally. Cloud functionality is optional, separately consented to, and visibly identified.

### 3.5 Explain before acting

When the app proposes or runs an automated action, the user must be able to see the exact command, working directory, target host, material risks, and approval boundary.

### 3.6 Keyboard complete, pointer friendly

Every primary workflow must be efficient from the keyboard while remaining understandable to people who prefer menus, buttons, drag-and-drop, or contextual actions.

### 3.7 Native means behavioral, not decorative

Nathstar will follow macOS conventions for windows, tabs, menus, focus, text editing, drag-and-drop, accessibility, notifications, Quick Look, Services, Shortcuts, and system appearance.

## 4. Target Users

### 4.1 Primary persona: Multi-project developer

Works across multiple repositories and routinely runs development servers, tests, logs, databases, Git commands, and package managers.

**Current pain:** Reconstructs context from terminal tabs, shell history, IDE windows, and memory after interruptions or restarts.

**Desired outcome:** Reopen a project and immediately recover its layout, processes, recent commands, failures, and next action.

### 4.2 Secondary persona: Remote systems operator

Uses SSH, tunnels, remote logs, and long-running commands across several environments.

**Current pain:** Similar-looking sessions make it easy to act on the wrong host or lose track of completed and disconnected work.

**Desired outcome:** Strong host identity, connection status, safe reconnection, and clear notification routing.

### 4.3 Secondary persona: Coding-agent power user

Runs Codex, Claude Code, OpenCode, or other CLI agents in multiple repositories.

**Current pain:** Cannot easily see which agent is active, finished, failed, or waiting for input.

**Desired outcome:** A single attention view showing agent and process states without replacing the agent's native CLI.

### 4.4 Future persona: Terminal learner

Wants command-line power without having to memorize shell syntax or interpret opaque errors.

This persona influences usability and assistance design but is not the primary MVP market.

## 5. Jobs to Be Done

1. When I return to a project, restore the context I need so I can resume productive work immediately.
2. When several commands or agents are running, tell me which one needs attention without forcing me to inspect every tab.
3. When a command fails, help me understand the failure in the context where it happened.
4. When I work on a remote machine, make the host and risk level unmistakable.
5. When I need a prior command or result, let me retrieve it by meaning, project, directory, status, or time.
6. When I am about to run a dangerous command, help me detect an accident without blocking legitimate expert workflows.
7. When I adopt the app, import enough of my existing terminal setup that switching does not feel like starting over.

## 6. Success Metrics

### 6.1 North-star metric

**Median time from opening a saved workspace to the user's first successful productive command.**

Initial target: under 15 seconds for a restored local workspace.

### 6.2 Activation metrics

- At least 70% of new users successfully run a command during the first session.
- At least 50% create or automatically adopt a project workspace during the first day.
- At least 40% restore a workspace during the first week.
- Import completion rate exceeds 85% for supported sources.

### 6.3 Retention and value metrics

- Week-four retained users open at least three workspaces per week.
- At least 30% of weekly active users use command search or Attention Center.
- At least 25% of weekly active users restore a previous layout.
- Fewer than 0.5% of sessions end in an application crash.

### 6.4 Trust metrics

- Zero terminal content is uploaded without an explicit user action or enabled setting.
- Destructive-command false-positive rate remains low enough that fewer than 5% of users disable warnings after enabling them.
- No command is altered silently between composition and execution.

## 7. Scope

### 7.1 MVP: Version 1.0

- Standards-compliant, GPU-accelerated terminal surface
- Native windows, tabs, split panes, menus, and settings
- Local project workspaces
- Saved layouts and automatic workspace restoration
- Persistent terminal sessions through UI closure and app relaunch
- Structured command history when shell integration is active
- Search across commands, output metadata, workspaces, directories, and hosts
- Attention Center for completions, failures, disconnections, and input requests
- Native notifications with direct navigation to the originating pane
- Local command-risk warnings
- SSH-aware host identity and reconnection affordances
- Import from iTerm2, Ghostty configuration, `~/.ssh/config`, and common shell configuration
- Light/dark themes, font configuration, and essential keyboard customization
- VoiceOver, Full Keyboard Access, reduced-motion, and high-contrast support
- Crash reporting and product analytics only through explicit consent

### 7.2 Version 1.x

- Workspace templates and reusable runbooks
- Git branch and worktree visualization
- Port and local-process inspector
- Shareable, secret-scrubbed workspace definitions
- Apple Shortcuts and expanded App Intents
- Finder and Services integrations
- Optional local language-model integration
- Optional cloud AI with bring-your-own-provider credentials
- Plugin or extension API after the security model is stable

### 7.3 Explicit non-goals for MVP

- Replacing the user's shell
- Building a proprietary shell language
- Shipping an IDE or full graphical source editor
- Hosting repositories or syncing source code
- Team chat and real-time collaboration
- Cross-platform support
- A marketplace for plugins or themes
- Reimplementing terminal emulation from scratch
- Requiring an account, subscription, or network connection for core use
- Automatically executing AI-generated commands

## 8. Information Architecture

### 8.1 Primary window

The main window contains:

1. **Workspace sidebar** — pinned, recent, local, remote, and archived workspaces.
2. **Tab strip** — native-feeling tabs scoped to the selected workspace.
3. **Terminal canvas** — one or more terminal panes.
4. **Context bar** — current directory, Git branch, host, running state, and relevant warnings.
5. **Attention indicator** — count and severity of items requiring review.

The terminal canvas receives maximum space. Supporting UI must be collapsible and must not visually compete with terminal content.

### 8.2 Attention Center

The Attention Center is a quiet, chronological inbox containing:

- Completed long-running commands
- Failed commands
- Sessions disconnected from remote hosts
- Processes waiting for user input when detectable
- Coding-agent sessions waiting for approval or interaction when detectable
- Background session crashes or restoration failures

Each item includes workspace, pane, host, command summary, status, elapsed time, and timestamp. Selecting an item focuses the originating session and relevant output.

### 8.3 Command palette

The command palette provides fuzzy access to:

- Application actions
- Workspaces
- Tabs and panes
- Previous commands
- Directories
- SSH hosts
- Themes and settings
- Workspace templates

The palette is searchable without moving focus permanently away from the active terminal.

### 8.4 Settings

Settings categories:

- General
- Appearance
- Terminal
- Keyboard
- Workspaces and restoration
- Shell integration
- Notifications and attention
- Security and privacy
- AI providers, when available
- Advanced and diagnostics

Settings changed through the UI must have an inspectable serialized representation where practical, enabling backup and reproducibility without making configuration files the primary interface.

## 9. Core User Flows

### 9.1 First launch

1. User opens Nathstar.
2. The app explains in one screen that core use is local and account-free.
3. The app detects supported terminals, shells, SSH configuration, and likely repositories without uploading paths.
4. User may import settings or skip.
5. A terminal opens immediately using the user's default shell.
6. The app offers non-blocking shell integration installation after the first successful prompt.
7. The first project directory is automatically offered as a workspace.

**Acceptance criteria**

- A usable prompt appears within two seconds on a supported Apple Silicon Mac under normal conditions.
- Import and shell integration are skippable.
- Declining telemetry or cloud features does not reduce core functionality.

### 9.2 Create a workspace

1. User chooses **New Workspace** or opens a folder from Finder.
2. User selects a local folder, Git repository, SSH host, or blank workspace.
3. Nathstar proposes a name and icon based on repository metadata or directory name.
4. User optionally selects a layout template.
5. The workspace opens with a terminal rooted in the selected directory.

**Acceptance criteria**

- The app never modifies repository files merely to create a workspace.
- Workspace metadata is stored in the app's data directory unless the user explicitly exports it.
- Duplicate workspaces are detected and can be merged or kept separate.

### 9.3 Restore a workspace

1. User opens a saved workspace.
2. Nathstar restores windows, tabs, panes, working directories, zoom state, names, colors, and session associations.
3. Live persistent sessions reconnect to their existing PTYs.
4. Non-persistent sessions open fresh shells and clearly show that they were recreated.
5. Failed restorations are summarized with a retry action.

**Acceptance criteria**

- Restoring one failed pane does not prevent other panes from opening.
- The app distinguishes reconnecting, recreated, disconnected, and failed sessions.
- The restored interface is interactive while slower sessions continue reconnecting.

### 9.4 Run and inspect a command

1. User types normally at the shell prompt.
2. With shell integration active, Nathstar records prompt boundaries, command boundaries, directory, host, start time, end time, and exit status.
3. The user may select the command or output as one unit.
4. Contextual actions allow copy command, copy output, rerun, open working directory, search output, bookmark, and explain failure.

**Acceptance criteria**

- Structured metadata never changes terminal byte streams or command semantics.
- Secret-like values are redacted from previews and indexes according to configurable local rules.
- The user can disable command metadata per profile, workspace, or session.

### 9.5 Handle a long-running command

1. A command runs longer than the configured threshold.
2. The user switches to another workspace or application.
3. On completion or failure, Nathstar creates an Attention Center item.
4. If notifications are enabled, a native notification identifies the workspace and outcome.
5. Selecting the item returns to the relevant command output.

### 9.6 Connect to an SSH host

1. User chooses a host from `~/.ssh/config`, the command palette, or a manual command.
2. The pane adopts an unambiguous host badge and optional environment color.
3. Disconnects change session state without discarding scrollback.
4. User may reconnect in place or open a new session.

**Acceptance criteria**

- Local and remote sessions are visually distinguishable without relying on color alone.
- Production-marked hosts can require an additional confirmation for configured risky commands.
- SSH credentials remain managed by the user's existing SSH tooling and Keychain; Nathstar does not create a proprietary credential store.

## 10. Functional Requirements

### 10.1 Terminal engine

| ID | Requirement | Priority |
|---|---|---|
| TERM-001 | Render terminal output using Metal on supported Macs. | Must |
| TERM-002 | Support UTF-8, grapheme clusters, emoji, font fallback, ligatures, and wide characters. | Must |
| TERM-003 | Support true color, hyperlinks, bracketed paste, synchronized output, mouse reporting, focus reporting, and common clipboard sequences. | Must |
| TERM-004 | Correctly run common TUIs and editors, including tmux, Vim/Neovim, Emacs, `less`, `top`, `htop`, and interactive Git tools. | Must |
| TERM-005 | Support Kitty graphics protocol or an equivalent widely adopted image protocol. | Should |
| TERM-006 | Maintain rendering responsiveness during high-volume output. | Must |
| TERM-007 | Expose terminal state only through a versioned internal adapter so the engine can be upgraded or replaced. | Must |

### 10.2 Sessions and processes

| ID | Requirement | Priority |
|---|---|---|
| SESS-001 | Create local PTY sessions using the user's configured shell and environment. | Must |
| SESS-002 | Keep opted-in sessions alive when the UI window closes or the app relaunches. | Must |
| SESS-003 | Display explicit states: starting, running, idle, waiting, completed, disconnected, failed, and terminated. | Must |
| SESS-004 | Allow graceful termination before offering force termination. | Must |
| SESS-005 | Preserve scrollback independently from structured command metadata. | Must |
| SESS-006 | Never claim that a process is persistent unless the background session service confirms ownership. | Must |

### 10.3 Workspaces and layout

| ID | Requirement | Priority |
|---|---|---|
| WORK-001 | Create workspaces from folders, repositories, remote hosts, or blank configurations. | Must |
| WORK-002 | Persist window, tab, split, title, color, working-directory, and session layout. | Must |
| WORK-003 | Restore panes independently and report partial failures. | Must |
| WORK-004 | Pin, rename, duplicate, archive, export, and delete workspaces. | Must |
| WORK-005 | Provide templates for common layouts. | Should |
| WORK-006 | Do not store workspace control files in a repository without explicit consent. | Must |

### 10.4 Shell integration and command records

| ID | Requirement | Priority |
|---|---|---|
| CMD-001 | Support opt-in integration for current versions of zsh, bash, and fish. | Must |
| CMD-002 | Prefer established semantic prompt protocols such as OSC 7 and OSC 133 where available. | Must |
| CMD-003 | Record command text, start/end time, exit status, directory, host, shell, workspace, and session identifiers. | Must |
| CMD-004 | Gracefully fall back to plain terminal behavior when integration is absent or incompatible. | Must |
| CMD-005 | Search command metadata locally with filters for project, host, directory, status, and date. | Must |
| CMD-006 | Make command and output blocks selectable without breaking normal terminal selection. | Must |
| CMD-007 | Allow local retention limits and deletion by workspace, date range, or all history. | Must |

### 10.5 Attention and notifications

| ID | Requirement | Priority |
|---|---|---|
| ATTN-001 | Generate attention items for configured command outcomes and session events. | Must |
| ATTN-002 | Deduplicate repeated events from the same command or session. | Must |
| ATTN-003 | Navigate from an item or notification to its originating workspace and pane. | Must |
| ATTN-004 | Support per-workspace and per-event notification preferences. | Must |
| ATTN-005 | Avoid notifications while the originating pane is focused unless explicitly enabled. | Should |
| ATTN-006 | Detect agent waiting states only when reliable integration or explicit patterns exist; otherwise label the state as inferred. | Must |

### 10.6 Command safety

| ID | Requirement | Priority |
|---|---|---|
| SAFE-001 | Analyze composed commands locally before execution when warnings are enabled. | Must |
| SAFE-002 | Consider command, arguments, working directory, local/remote host, privilege elevation, and configured environment classification. | Must |
| SAFE-003 | Warn on high-confidence destructive patterns while allowing the user to proceed. | Must |
| SAFE-004 | Show the exact command and affected context; never replace the command silently. | Must |
| SAFE-005 | Allow one-time bypass, rule-specific suppression, and complete disablement. | Must |
| SAFE-006 | Treat pasted multiline commands as a distinct risk surface and visibly delimit each command before execution. | Must |

### 10.7 Import and migration

| ID | Requirement | Priority |
|---|---|---|
| IMP-001 | Detect installed iTerm2 and Ghostty configurations without changing them. | Must |
| IMP-002 | Preview importable profiles, themes, fonts, key bindings, and behaviors before applying them. | Must |
| IMP-003 | Report unsupported settings rather than silently dropping them. | Must |
| IMP-004 | Import SSH hosts by parsing include-aware `~/.ssh/config` without copying private keys. | Must |
| IMP-005 | Make every import reversible until the user confirms it. | Must |

## 11. UX Requirements

### 11.1 Visual design

- Quiet, content-first visual hierarchy
- Native vibrancy used sparingly and never at the expense of contrast
- Terminal background and surrounding chrome visually coordinated
- Status communicated through iconography, text, and shape—not color alone
- No oversized dashboard cards or marketing surfaces inside the core application
- Animations short, interruptible, and disabled by Reduce Motion

### 11.2 Keyboard model

- Conventional macOS shortcuts take precedence where they do not conflict with terminal input.
- Terminal applications must receive expected control, option, escape, function, and modifier sequences.
- Every app-level shortcut is discoverable and remappable.
- Conflicts show the current recipient and offer resolution.
- A temporary “send shortcut to terminal” mechanism must exist.

### 11.3 Accessibility

- VoiceOver exposes terminal rows, selection, cursor position, pane identity, and relevant state.
- Standard AppKit or SwiftUI controls are preferred for navigation and settings.
- Custom terminal views implement appropriate `NSAccessibility` roles and actions.
- Full Keyboard Access covers all non-terminal controls.
- Text remains usable at 200% scaling.
- High contrast and Reduce Transparency are respected.
- Notifications and attention states have non-auditory representations.
- Accessibility behavior is included in automated and manual release testing.

## 12. Technical Architecture

### 12.1 Technology choices

- **Language:** Swift 6+
- **Application UI:** SwiftUI with targeted AppKit components
- **Terminal engine:** `libghostty` behind a Nathstar-owned adapter
- **Rendering:** Metal through the terminal engine
- **Concurrency:** Swift Concurrency with isolated session actors
- **Persistence:** SQLite with migrations; thin repository layer owned by Nathstar
- **Secrets:** macOS Keychain
- **Logging:** Unified Logging with privacy annotations
- **Distribution:** Developer ID signed and Apple-notarized `.dmg`

`libghostty` is selected to avoid rebuilding fragile terminal parsing, rendering, font, and protocol behavior. Because its embeddable API may evolve, no UI or domain code may call it directly. `TerminalEngineAdapter` will translate engine-specific events and commands into stable Nathstar types.

### 12.2 Major components

```text
Nathstar.app
├── Application shell
│   ├── Workspace navigation
│   ├── Window/tab/split management
│   ├── Command palette
│   ├── Attention Center
│   └── Settings and onboarding
├── Terminal presentation
│   ├── TerminalEngineAdapter
│   ├── Metal terminal surface
│   ├── Selection and accessibility bridge
│   └── Input/key-routing coordinator
├── Domain services
│   ├── WorkspaceService
│   ├── SessionService
│   ├── CommandRecordService
│   ├── AttentionService
│   ├── SearchService
│   ├── RiskAnalysisService
│   └── ImportService
├── Persistence
│   ├── SQLite database
│   ├── Settings store
│   └── Keychain client
└── NathstarSessionService
    ├── PTY ownership
    ├── Process lifecycle
    ├── bounded scrollback transport
    └── reconnect protocol
```

### 12.3 Process model

The UI application and persistent session service run as separate processes.

- The session service owns PTYs and child processes for sessions explicitly marked persistent.
- The UI connects through a versioned local XPC protocol.
- The protocol exposes narrow operations: create, attach, resize, input, signal, snapshot, and terminate.
- The service authenticates the connecting application through code-signing requirements.
- A UI crash must not automatically terminate persistent child processes.
- Service crashes and protocol mismatches are surfaced clearly; the app must never imply a session is still running without confirmation.

### 12.4 Data model

Core entities:

- `Workspace`: identity, display metadata, root type, root reference, restoration policy
- `WindowLayout`: frame, screen association, selected tab
- `Tab`: title, order, appearance, pane tree
- `Pane`: session reference, profile, initial directory, zoom state
- `Session`: type, shell, host, process identity, persistence mode, lifecycle state
- `CommandRecord`: command, timestamps, exit status, directory, host, session, redacted preview
- `AttentionItem`: type, severity, source, lifecycle, navigation target
- `Profile`: shell, environment policy, appearance, key mapping, integration settings
- `ImportedSetting`: source, source key, mapped value, support status

Terminal scrollback is stored separately from command metadata and governed by its own bounded retention policy.

### 12.5 Shell integration

Shell integration will emit semantic escape sequences identifying:

- Prompt start and end
- Command start and end
- Current working directory
- Exit status
- Host identity when available

Installation must be idempotent, inspectable, and removable. Nathstar should prefer sourcing one clearly marked integration file from the user's shell configuration. Before editing a dotfile, it must show the proposed change and create a timestamped backup. Manual installation instructions must always be available.

## 13. Security and Privacy

### 13.1 Threat model

Nathstar processes untrusted terminal output that may attempt to:

- Trigger unsafe escape-sequence behavior
- Manipulate clipboard contents
- Spoof prompts, hosts, links, or application chrome
- Exfiltrate data through network-enabled features
- Inject control characters into titles or metadata
- Exhaust memory through output volume or image protocols

It also launches commands with the user's privileges and therefore must protect against confused-deputy behavior in automation, imports, links, and plugins.

### 13.2 Required protections

- Treat all terminal output, titles, paths, Git metadata, and remote-host content as untrusted data.
- Bound parser memory, scrollback, image dimensions, and metadata sizes.
- Require confirmation before terminal escape sequences can place data on the system clipboard unless explicitly trusted.
- Sanitize control characters in app chrome and notifications.
- Never expose Keychain material to terminal output, analytics, crash reports, or AI context.
- Mark remote and elevated contexts using trusted app chrome that terminal content cannot imitate.
- Open external URLs only after scheme validation and according to user preferences.
- Disable remote control and extension loading by default.
- Sign and verify update artifacts.

### 13.3 AI privacy rules

AI is not required for version 1.0. When introduced:

- No terminal content is sent to a provider until the user invokes an AI action or explicitly enables scoped automation.
- The UI previews exactly what context will be sent.
- Secrets and configured patterns are redacted locally first.
- Provider, retention implications, and account destination are visible.
- Generated commands are drafts and require explicit execution.
- AI cannot bypass command-risk warnings or approval gates.

### 13.4 Telemetry

- Off by default during development and private beta.
- Public builds ask separately for product analytics and crash reporting.
- Event schemas contain feature actions and performance measures, not command text, output, paths, hostnames, repository names, environment variables, or file contents.
- Users can inspect the categories collected and delete the local analytics queue.

## 14. Performance and Reliability Requirements

| ID | Target |
|---|---|
| PERF-001 | Cold launch to usable prompt: p50 under 1.5 seconds, p95 under 2.5 seconds on the baseline supported Apple Silicon Mac. |
| PERF-002 | Keystroke-to-render latency: p95 under 16 ms under normal local-shell conditions. |
| PERF-003 | Smooth rendering during sustained output without blocking input handling. |
| PERF-004 | Restore a four-pane local workspace to interactive UI within 2 seconds, with reconnection continuing asynchronously. |
| PERF-005 | Search 100,000 command records with common filters in under 200 ms after warm-up. |
| PERF-006 | Idle single-pane UI CPU usage remains below 1% under normal conditions. |
| PERF-007 | Memory growth is bounded during unending output and large inline images. |
| REL-001 | UI crashes do not terminate confirmed persistent sessions. |
| REL-002 | Database writes are transactional and migrations are recoverable from backup. |
| REL-003 | Partial restoration and import failures do not block unrelated work. |

Performance claims must be measured using a documented baseline Mac model and repeatable benchmark corpus.

## 15. Compatibility

### 15.1 Initial support

- macOS 15 or later
- Apple Silicon required for the first private beta
- Intel support evaluated before public 1.0 based on engine, demand, and testing capacity
- zsh, bash, and fish
- Local shells and OpenSSH
- tmux compatibility without requiring Nathstar-specific configuration

### 15.2 Compatibility policy

- Publish supported OS, shell, and architecture versions.
- Test the current and previous major macOS versions once the platform target expands.
- Maintain a compatibility suite for common TUIs, escape sequences, Unicode, keyboard layouts, and shell-integration versions.
- Unsupported configurations must degrade to a normal terminal wherever possible.

## 16. Distribution and Updates

### 16.1 Initial distribution

- Signed and notarized `.dmg` from the official website
- Sparkle or an equivalently mature signed update framework
- Homebrew Cask after stable public availability
- No Mac App Store release for MVP because unrestricted shell, PTY, and filesystem workflows conflict with sandbox expectations

### 16.2 Update requirements

- Verify signatures before installation.
- Provide release notes before restart.
- Never terminate running persistent sessions merely to apply an update.
- Support deferred updates.
- Migrate data transactionally and maintain a rollback-compatible backup when schemas change.

## 17. Testing Strategy

### 17.1 Automated tests

- Unit tests for workspace, layout, attention, risk, redaction, import, and migration logic
- Property and fuzz tests for untrusted metadata and parser boundaries exposed by the adapter
- Integration tests for PTY creation, resizing, signals, disconnects, and service reconnection
- Snapshot tests for deterministic layout and settings surfaces where useful
- Accessibility identifier and navigation tests
- Performance tests for launch, rendering transport, restoration, search, and sustained output

### 17.2 Compatibility corpus

The release suite must cover:

- Shell prompts for zsh, bash, and fish
- tmux, Vim/Neovim, Emacs, `less`, `man`, `top`, and interactive Git tools
- Unicode combining marks, emoji sequences, CJK wide characters, bidirectional-text edge cases, and ligatures
- Bracketed paste and multiline paste
- Mouse and keyboard reporting modes
- Hyperlinks, images, clipboard sequences, and malformed control sequences
- SSH connections with latency, disconnects, and host changes
- High-volume output and unbounded process output

### 17.3 Manual release checklist

- First launch with no existing configuration
- Imports from clean and heavily customized terminal setups
- VoiceOver navigation and terminal reading
- Full Keyboard Access
- Multiple displays, Spaces, Stage Manager, full screen, and display disconnect
- Sleep/wake, network loss, service restart, app crash, and OS restart
- External keyboard layouts and input methods
- Notarization, update signature, installation, and uninstall behavior

## 18. Delivery Plan

### Phase 0: Product validation — 3 to 4 weeks

- Interview 12–15 target users.
- Observe real multi-project and agent workflows.
- Prototype workspace sidebar, terminal canvas, and Attention Center.
- Validate whether project restoration and attention awareness are strong enough to motivate switching.
- Establish measurable baseline workflows in iTerm2, Ghostty, Warp, and WezTerm.

**Exit gate:** At least 8 of 12 target users say they would install a private beta and identify context restoration or attention management as materially better than their current terminal.

### Phase 1: Technical spike — 4 to 6 weeks

- Integrate `libghostty` behind the terminal adapter.
- Prove input, rendering, resizing, clipboard, Unicode, IME, and accessibility basics.
- Implement local PTY lifecycle.
- Prototype XPC session persistence.
- Run compatibility and high-output experiments.

**Exit gate:** Common shells and representative TUIs run reliably; persistent session spike survives UI termination; major engine risks are documented.

### Phase 2: Alpha — 8 to 12 weeks

- Build native app shell, tabs, panes, workspace model, restoration, settings, and command palette.
- Add shell integration and structured command records.
- Add initial Attention Center and notifications.
- Establish database migrations, privacy boundaries, and diagnostics.

**Exit gate:** Internal users can use Nathstar as their primary terminal for one week without a blocking compatibility issue.

### Phase 3: Private beta — 8 weeks

- Add importers, risk warnings, SSH identity, accessibility completeness, and updater.
- Recruit 50–100 target users.
- Measure activation, restoration, reliability, and workflow recovery time.
- Resolve top compatibility and trust issues before expanding scope.

**Exit gate:** Crash-free sessions exceed 99.5%; prompt launch and restoration targets are met; no unresolved critical security issues; at least 35% of beta users remain active in week four.

### Phase 4: Public 1.0

- Signed and notarized release
- Public documentation, privacy policy, security disclosure process, and support workflow
- Homebrew Cask submission
- Compatibility matrix and known-issues page
- Pricing introduced only if it does not compromise local, account-free terminal use

## 19. Release Acceptance Criteria

Version 1.0 is ready only when:

1. A user can install, launch, run their default shell, and uninstall without manual cleanup instructions.
2. Supported shells and the compatibility corpus pass on all advertised macOS versions and architectures.
3. Workspaces restore accurately after normal quit, forced UI termination, and system restart according to documented persistence behavior.
4. The application clearly distinguishes live, reattached, recreated, disconnected, and failed sessions.
5. No core workflow requires an account or network connection.
6. No terminal content, command text, path, hostname, or secret appears in telemetry.
7. VoiceOver and Full Keyboard Access support all primary workflows.
8. Update packages are signed, verified, and recover safely from an interrupted update.
9. Security review covers escape sequences, clipboard behavior, URL handling, XPC authorization, update signing, imports, and AI boundaries.
10. Crash-free session, launch, input latency, memory, and restoration targets are met on the documented baseline hardware.

## 20. Key Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Terminal compatibility is broader than anticipated. | Users abandon the product after one broken workflow. | Use a proven engine, maintain a compatibility corpus, and prioritize terminal correctness over new features. |
| `libghostty` APIs change. | Build instability and recurring integration work. | Isolate the engine behind an adapter, pin tested versions, and budget upgrade work. |
| Persistent sessions introduce service and lifecycle complexity. | Lost processes or misleading state damage trust. | Use explicit state confirmation, XPC protocol versioning, recovery tests, and conservative claims. |
| Shell integration is perceived as invasive. | Users refuse installation or fear dotfile corruption. | Make it optional, preview changes, back up files, support manual installation, and degrade gracefully. |
| Safety warnings become noisy. | Experts disable the feature. | Warn only on high-confidence cases by default and offer transparent, scoped controls. |
| AI positioning overwhelms the core product. | Product becomes another agent wrapper. | Keep AI outside MVP and require the terminal experience to succeed independently. |
| Workspace metadata leaks sensitive names or paths. | Privacy and enterprise adoption suffer. | Local-only defaults, redaction, export previews, and no content telemetry. |
| Native macOS focus narrows the market. | Lower total addressable market. | Treat focus as the initial strategic advantage; revisit other platforms only after product-market fit. |

## 21. Open Product Decisions

These decisions should be resolved during Phase 0 and the technical spike:

1. Should persistence be opt-in per session, default per workspace, or enabled globally?
2. How much command output, if any, should be persisted across restarts by default?
3. Should command records store full command text by default or use a privacy-first limited history mode?
4. Which coding-agent states can be detected reliably without agent-specific plugins?
5. Should initial import support only visual/key settings or also triggers, profiles, and automation?
6. What is the minimum supported Intel Mac configuration, if Intel is supported at all?
7. Which destructive-command categories produce warnings in the default policy?
8. Should exported workspace templates contain commands, and how should secrets be detected and removed?
9. What business model preserves an excellent account-free local terminal while funding continued development?
10. What final product name communicates calm context and Mac-native quality without sounding like an AI wrapper?

## 22. Competitive References

- [Ghostty features](https://ghostty.org/docs/features)
- [Ghostty and libghostty](https://github.com/ghostty-org/ghostty)
- [iTerm2 shell integration](https://iterm2.com/documentation-shell-integration.html)
- [Warp terminal](https://www.warp.dev/terminal)
- [WezTerm](https://wezterm.org/)
- [Apple AppKit](https://developer.apple.com/documentation/appkit)
- [Apple accessibility for AppKit](https://developer.apple.com/documentation/appkit/accessibility-for-appkit)

## 23. Immediate Next Artifacts

The following artifacts should be produced before implementation begins:

1. Interview guide and recruiting screener for target users
2. Competitive workflow benchmark
3. Low-fidelity information architecture and primary-window wireframe
4. Clickable prototype for workspace restoration and Attention Center
5. Terminal-engine technical spike plan
6. Security threat-model document
7. Initial data schema and XPC protocol proposal
8. Alpha milestone backlog with estimates and ownership

