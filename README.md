# Nathstar

**The Native macOS Terminal Workspace for Projects, Context, Live Operations, and Private AI.**

[![License: MIT](https://img.shields.io/badge/License-MIT-cyan.svg)](LICENSE)
[![Platform: macOS 15+](https://img.shields.io/badge/Platform-macOS%2015%2B%20(Apple%20Silicon)-blue.svg)](Package.swift)
[![Swift: 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](Package.swift)



Nathstar is a local-first, zero-telemetry macOS terminal built with **Swift 6**, **SwiftUI**, **AppKit**, and **Metal**. Unlike traditional terminal emulators that treat every window as a disposable shell buffer, Nathstar organizes your command-line work around **Project Workspaces**, **Command Blocks**, **Silent Live Environment Sync**, **Live Port & Process Management**, **Pre-Execution Blast-Radius Safety**, and **Local/Cloud Streaming AI**.

![Nathstar Feature Tour](docs/screenshots/nathstar-showcase.gif)


<!-- BEGIN LATEST DOWNLOAD BUTTON -->
[![Download DMG FIle](https://custom-icon-badges.demolab.com/badge/-Download-blue?style=for-the-badge&logo=download&logoColor=white "Download zip")](https://github.com/satinath-nit/Nathstar/releases/download/v1.0/Nathstar-arm64.dmg)
<!-- END LATEST DOWNLOAD BUTTON -->

---

## Visual Tour & Feature Highlights

### 1. Project Workspaces, Collapsible Sidebar Sections, Split Panes & Command Blocks
![Project Workspaces & Command Blocks](docs/screenshots/01-workspace-overview.png)

### 2. Streaming Local & Cloud AI, One-Click Error Recovery & Inline `⌘I` Command Generator
![Streaming AI Assistant & Error Fix](docs/screenshots/02-ai-assistant-and-error-fix.png)

### 3. Live Port & Process Manager (`Ports` Tab · `⇧⌘P`)
![Live Ports & Processes Manager](docs/screenshots/03-live-ports-and-processes.png)

### 4. Silent Live Environment Sync (`SIGUSR1`), `.env` Export & Project Manifests
![Silent Live Environment Sync & Project Manifests](docs/screenshots/04-manifest-and-silent-env.png)

### 5. In-Terminal Regex Search (`⌘F`), Quick Links (`⇧⌘L`), Click-to-Position Cursor & `Tab ⇥` Autocomplete
![Search, Quick Links, Click-to-Cursor & Autocomplete](docs/screenshots/05-search-links-and-autocomplete.png)

### 6. 8 Built-In Color Themes, 120Hz Metal GPU Pipeline & `⌘K` Command Palette
![Themes & Command Palette](docs/screenshots/06-themes-and-command-palette.png)

---

## Why Nathstar?

Most terminals force you to choose between speed (**Ghostty / Alacritty**), window management (**iTerm2 / WezTerm**), or cloud-tethered AI and modern input editing (**Warp**). Nathstar brings the best of all of them into a single, 100% local-first macOS application with no mandatory login or telemetry:

- **Click-to-Position Cursor & Native Command Editing (`⌘E`)**: Click (or `⌥-Click`) directly on any character in a long or wrapped terminal command to move the shell cursor there immediately—or press `⌘E` to pull your active terminal line into the bottom multi-line macOS text editor with full selection, undo, and IDE-style autocomplete.
- **Silent Live Environment & `.env` Sync**: Add or edit `KEY=VALUE` variables in the UI and inject them into running `zsh` sessions **silently in the background** via `SIGUSR1`—without printing `export KEY=VALUE` into your scrollback or restarting your shell.
- **Live Port & Process Manager (`⇧⌘P`)**: A dedicated **Ports** tab in the right panel that maps listening TCP ports (`:3000`, `:5173`, `:8080`) and active child processes back to the exact workspace and terminal pane that spawned them, with one-click **Open in Browser**, **Focus Pane**, **Kill (`SIGTERM`)**, and **Kill -9 (`SIGKILL`)**.
- **Zero-Telemetry Streaming AI (`⇧⌘I` & `⌘I`)**: Native support for local **Ollama** (with automatic installed-model discovery), **OpenAI**, **Anthropic (Claude)**, and any **OpenAI-compatible endpoint** (LM Studio, Groq, OpenRouter, vLLM). Includes token-by-token streaming, `⌘I` inline natural-language-to-`zsh` translation, and one-click **"Explain & Fix with AI"** when a command exits non-zero.
- **Pre-Execution Blast-Radius Analyzer (`Safe-Run`)**: Inspects commands for high-risk patterns (`git push --force`, `rm -rf` from root, `curl | sudo bash`) *before* execution.
- **Zero-Permission Global Hotkey (`Double-Tap ⌃`) & Quake Visor Mode**: Summon or hide Nathstar from any application by double-tapping `⌃` (Control) or pressing `⌃` + `` ` ``—powered by hardware modifier polling that works out of the box without requiring macOS Accessibility permissions.

📖 **Deep-Dive Documentation:**
- [Complete Feature Guide](docs/features.md)
- [System Architecture & Internals](docs/architecture.md)
- [Market Comparison (vs. Warp, Ghostty, iTerm2, Kitty, WezTerm, cmux)](docs/market-comparison.md)

---

## Key Features at a Glance

| Category | Capabilities |
|---|---|
| **Workspace & Sidebar** | Customizable & collapsible **Projects**, **Personal**, **Others**, and **SSH Hosts** sections; drag-and-drop workspace categorization; auto-expanding hover rail when unpinned (`⇧⌘S`). |
| **Terminal & Rendering** | True PTY sessions via vendored `SwiftTerm`; optional **120Hz Metal GPU shader pipeline**; 8 curated 16-color ANSI themes (Nathstar Midnight, Catppuccin Mocha, Tokyo Night, Dracula, Rosé Pine, Solarized Dark, GitHub Dark, Nord); configurable cursor styles & background opacity. |
| **Command Blocks & Editing** | Warp-style **Command Blocks Ribbon** with millisecond/second duration badges, exit codes, output inspector, one-click Re-run, Copy Output, and AI analysis; click-to-move-cursor in prompt; `⌘E` pull-to-composer. |
| **IDE Autocomplete & Snippets** | Live `Tab ⇥` autocomplete in the `Safe-Run` composer combining **Git branches**, **file/folder paths**, **Command Blocks**, **parameterized Snippets (`{{port}}`)**, and **`~/.zsh_history`**. |
| **Search & Quick Links** | In-terminal scrollback search (`⌘F`) with case-sensitive & regex modes; Quick Links & File Path detector (`⇧⌘L`) that opens URLs in the browser and `file.swift:line:col` directly in VS Code. |
| **Live Operations** | **Attention Center** for long-running/failed commands; **Project Manifests** (`.nathstar/manifest.json`) for multi-pane service orchestration; **Live Ports & Processes** (`⇧⌘P`) with one-click kill; scrollback restore & optional background `tmux` persistence across `⌘Q`. |

---

## Local Development Setup

### Prerequisites

- **Hardware**: Apple Silicon Mac (`arm64`)
- **OS**: macOS 15 (Sequoia) or later
- **Toolchain**: Swift 6.0+ (Xcode 16+ or macOS Command Line Tools)

All third-party dependencies (`SwiftTerm`) are vendored locally under `Vendor/SwiftTerm`, so **builds work 100% offline with zero external network fetches**.

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/nathstar.git
cd nathstar
```

### 2. Run Core Checks & Debug Build

The verification script builds and runs the `NorthstarCoreChecks` test suite (covering the blast-radius analyzer, pane tree operations, atomic state persistence, `.nathstar/manifest.json` & `.env` round-tripping, AI endpoint resolution, theme palettes, SSH config parsing, regex scrollback search, autocomplete ranking, and port/process mapping) and then compiles the debug application:

```bash
./scripts/check.sh
```

> **SDK Override Note:** If your Mac has multiple Command Line Tools / Xcode SDKs installed, `scripts/toolchain.sh` automatically selects a compatible SDK. You can override it explicitly at any time:
> ```bash
> NATHSTAR_SDK_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk ./scripts/check.sh
> ```

### 3. Run in Development Mode

```bash
source scripts/toolchain.sh
run_swift run Nathstar
```

### 4. Package Release `.app` and `.dmg` Installer

To compile an optimized Release binary, bundle `release/Nathstar.app` (including app icons and Metal shaders), sign it with an ad-hoc signature, and generate a compressed disk image (`release/Nathstar-0.1.0-arm64.dmg`):

```bash
./scripts/package-macos.sh
```

Run the automated live-PTY smoke test against the packaged `.app`:

```bash
./scripts/smoke-test-app.sh
```

To install the freshly built app into `/Applications` locally:

```bash
rm -rf /Applications/Nathstar.app && cp -R release/Nathstar.app /Applications/Nathstar.app
open /Applications/Nathstar.app
```

---

## Code Signing & Notarization for Public Releases

Local builds use an ad-hoc signature (`codesign --sign -`). When distributing outside your own Mac, sign with an Apple **Developer ID Application** certificate and notarize with `notarytool`:

```bash
codesign --force --deep --options runtime --timestamp \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  release/Nathstar.app

xcrun notarytool submit release/Nathstar-0.1.0-arm64.dmg \
  --keychain-profile nathstar-notary --wait

xcrun stapler staple release/Nathstar-0.1.0-arm64.dmg
```

---

## Keyboard Shortcuts

| Action | Shortcut |
|---|---|
| **Global Summon / Quake Visor Toggle** | `Double-Tap ⌃` (Control) or `⌃` + `` ` `` |
| **Open / Focus Nathstar Window** | `⌘T` |
| **Command Palette** | `⌘K` |
| **New Terminal Tab** | `⌘N` |
| **Open Folder as Workspace** | `⌘O` |
| **Split Pane Vertically / Horizontally** | `⌘D` / `⇧⌘D` |
| **Equalize Split Panes** | `⇧⌘=` |
| **Zoom / Maximize Focused Split Pane** | `⇧⌘⏎` |
| **Close Focused Split Pane** | `⇧⌘W` |
| **Close Window (Keep PTYs Alive)** | `⌘W` |
| **Quit Nathstar** | `⌘Q` |
| **Find in Terminal Scrollback** | `⌘F` |
| **Quick Links & File Paths Bar** | `⇧⌘L` |
| **Inline AI Command Generator** | `⌘I` |
| **Pull Active Terminal Line into Composer** | `⌘E` |
| **Insert Composer Text into Terminal Prompt** | `⇧⏎` |
| **Run Composer Command (Safe-Run)** | `⌘⏎` |
| **Accept Autocomplete Suggestion** | `Tab ⇥` |
| **Pin / Collapse Left Sidebar** | `⇧⌘S` |
| **Toggle Attention Center** | `⇧⌘A` |
| **Live Ports & Processes Tab** | `⇧⌘P` |
| **Toggle AI Assistant Chat Panel** | `⇧⌘I` |
| **Project Manifest & `.env` Sheet** | `⇧⌘E` |

---

## Project Structure

```text
Nathstar/
├── Package.swift                 # Swift 6 package manifest (NorthstarCore, Nathstar, NorthstarCoreChecks)
├── LICENSE                       # MIT License
├── README.md                     # Quickstart & developer overview
├── Resources/
│   ├── Info.plist                # macOS bundle metadata
│   └── NorthstarIcon-1024.png    # App icon asset
├── scripts/
│   ├── toolchain.sh              # SDK & Swift toolchain resolver
│   ├── check.sh                  # Runs NorthstarCoreChecks + debug build
│   ├── package-macos.sh          # Builds Release .app bundle & .dmg installer
│   └── smoke-test-app.sh         # Verifies live PTY session startup in packaged .app
├── Sources/
│   ├── NorthstarCore/            # Pure domain logic, models, parsers, AI client, safety & state store
│   │   ├── Models.swift          # Workspaces, panes, themes, snippets, SSH parser, buffer scanner, autocomplete, port scanner
│   │   ├── AIClient.swift        # Streaming & non-streaming client for Ollama, OpenAI, Anthropic, Custom APIs
│   │   ├── CommandRiskAnalyzer.swift # Pre-execution blast-radius safety rules
│   │   ├── EnvironmentCapsule.swift  # .nathstar/manifest.json & .env loader/exporter/inspector
│   │   └── StateStore.swift      # Atomic JSON persistence in ~/Library/Application Support/Nathstar
│   ├── NorthstarApp/             # Native macOS SwiftUI + AppKit + Carbon UI layer
│   │   ├── NorthstarApp.swift    # App entry point, single-window controller, global Double-Tap ⌃ monitor, Quake visor
│   │   ├── AppModel.swift        # @MainActor observable state coordinator
│   │   ├── RootView.swift        # Sidebar, TabStrip, ContextBar, PaneNodeView, Search/Links/AI bars, CommandComposer
│   │   ├── TerminalHost.swift    # SwiftTerm bridge, ZDOTDIR silent env & OSC 133 shim, Metal toggle
│   │   ├── AttentionPanel.swift  # Right panel: Attention alerts, inline Manifest/Env editor, Live Ports & Processes
│   │   ├── AIChatPanelView.swift # Streaming AI chat with one-click Run/Insert & terminal output attachment
│   │   ├── CapsulePanel.swift    # Full Project Manifest & .env management sheet
│   │   ├── CommandPaletteView.swift # ⌘K searchable command, snippet, SSH, theme, and workspace launcher
│   │   └── SettingsView.swift    # General, AI, Terminal (Themes/Fonts/Metal), Snippets, and Privacy settings
│   └── NorthstarCoreChecks/      # Fast executable verification suite
├── Tests/
│   └── NorthstarCoreTests/       # XCTest suite for NorthstarCore
├── Vendor/
│   └── SwiftTerm/                # Vendored VT100/xterm + Metal terminal engine with click-to-cursor enhancements
└── docs/
    ├── architecture.md           # Deep-dive system architecture & data flow
    ├── features.md               # Comprehensive guide to every Nathstar feature
    ├── market-comparison.md      # Detailed comparison vs. Warp, Ghostty, iTerm2, Kitty, WezTerm & cmux
    └── product-spec.md           # Product vision & design principles
```

---

## Contributing

Contributions, bug reports, and feature requests are welcome!

1. Fork the repository and create a feature branch (`git checkout -b feat/my-feature`).
2. Add or update verification checks in `Sources/NorthstarCoreChecks/main.swift`.
3. Run `./scripts/check.sh` and `./scripts/smoke-test-app.sh` to verify everything compiles and passes.
4. Open a Pull Request.

---

## License

Nathstar is open-source software licensed under the [MIT License](LICENSE).

It includes a vendored and enhanced copy of [SwiftTerm](Vendor/SwiftTerm/LICENSE) by Miguel de Icaza (MIT License).
