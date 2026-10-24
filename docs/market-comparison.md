# How Nathstar Compares to Other Terminals in the Market

The modern macOS terminal landscape is split into two camps:
1. **Minimalist GPU Emulators** (**Ghostty**, **Alacritty**, **Kitty**) that are fast and standards-compliant, but treat every shell as an isolated, stateless text grid with no built-in project organization, port management, environment variable sync, or AI assistance.
2. **Cloud-Tethered "Block" Terminals** (**Warp**) that offer modern input editing and AI, but require cloud accounts/telemetry by default and replace standard terminal rendering with a proprietary UI model.

**Nathstar bridges both worlds**: it is a 100% local-first, zero-telemetry, MIT-licensed native macOS terminal with a real VT100/xterm + 120Hz Metal GPU engine **plus** project workspaces, silent live `.env` injection, a live port/process manager, pre-execution blast-radius safety, click-to-move-cursor, and bring-your-own local/cloud AI.

---

## 1. Feature-by-Feature Comparison Matrix

| Capability | **Nathstar** | **Warp** | **Ghostty** | **iTerm2** | **WezTerm / Kitty** | **cmux** |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Open Source (MIT) & Zero Telemetry** | ✅ Yes | ❌ Proprietary / Cloud | ✅ Yes | ✅ Yes (GPLv2) | ✅ Yes | ✅ Yes |
| **Works 100% Offline Without Login** | ✅ Yes | ⚠️ Limited | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Project Workspaces Sidebar (`Projects` / `Personal` / `Others`)** | ✅ Built-in, Collapsible & Customizable | ❌ No | ❌ No | ⚠️ Profiles only | ❌ No | ✅ Workspace-focused |
| **Silent Live Env Var Injection (`SIGUSR1` without terminal clutter)** | ✅ **Unique to Nathstar** | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No |
| **One-Click `.env` Import/Export + Portable `.nathstar/manifest.json`** | ✅ Built-in | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No |
| **Live Port & Process Manager Tab (`Open`, `Focus Pane`, `Kill -9`)** | ✅ Built-in (`Ports` tab) | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No |
| **Pre-Execution Blast-Radius Safety Analyzer (`Safe-Run`)** | ✅ Built-in | ⚠️ Basic | ❌ No | ⚠️ Regex triggers | ❌ No | ❌ No |
| **Click-to-Move Cursor in Long Commands (Works in any zsh prompt)** | ✅ Built-in (`OSC 133` + Wrapped-Line Fallback) | ✅ Yes | ⚠️ `OSC 133` only | ⚠️ `⌥-Click` | ⚠️ `OSC 133` only | ❌ No |
| **Pull Active Terminal Line into Native Text Editor (`⌘E`)** | ✅ Built-in | ✅ Native input | ❌ No | ⚠️ Composer popover | ❌ No | ❌ No |
| **IDE Autocomplete (Git Branches, Paths, History, Snippets)** | ✅ Built-in (`Tab ⇥`) | ✅ Yes | ❌ No | ⚠️ Basic history | ❌ No | ❌ No |
| **Command Blocks with Duration, Output Inspector & Re-run** | ✅ Built-in Ribbon | ✅ Full-screen blocks | ❌ No | ⚠️ Marks only | ❌ No | ❌ No |
| **Local Ollama AI Auto-Discovery + Streaming BYOK (OpenAI/Claude)** | ✅ Built-in | ❌ Cloud subscription | ❌ No | ⚠️ Plugin required | ❌ No | ❌ No |
| **One-Click "Explain & Fix" Banner on Non-Zero Exit Code** | ✅ Built-in | ✅ Yes | ❌ No | ❌ No | ❌ No | ❌ No |
| **Zero-Permission Global `Double-Tap ⌃` & Quake Visor Mode** | ✅ Built-in | ⚠️ Standard hotkey | ✅ Quick Terminal | ✅ Hotkey Window | ❌ External tool | ❌ No |
| **120Hz Metal GPU Shader Rendering** | ✅ Built-in | ✅ Metal | ✅ Metal | ✅ Metal | ✅ OpenGL/Metal | ✅ Yes |

---

## 2. Deep-Dive: Why Nathstar Is Different

### 2.1 vs. Warp
- **Privacy & Ownership**: Warp was built around a cloud account, team sharing, and metered AI credits. Nathstar is **100% local-first and open-source (MIT)**. Your commands, environment variables, and paths never leave your Mac unless you explicitly send a prompt to your own AI endpoint.
- **First-Class Local Ollama Support**: Nathstar natively queries your local Ollama server (`http://127.0.0.1:11434/api/tags`), populates your installed local models in a one-click picker, and streams responses token-by-token—for free and completely offline.
- **Uncompromised Terminal Compatibility**: Because Nathstar runs a true PTY grid (`SwiftTerm`) at the core and layers the **Command Blocks Ribbon** and **`Safe-Run` Composer** around it, full-screen TUIs (`nvim`, `htop`, `lazygit`, `tmux`, `claude`, `codex`) never break or fight a custom block-editor DOM.

### 2.2 vs. Ghostty, Kitty, and Alacritty
- **Context & Operations Built In**: Minimalist GPU terminals give you a fast blank canvas, but leave you to manually track which tab is running port `:3000`, which pane failed a build 10 minutes ago, or which `.env` variables are loaded.
- Nathstar gives you **120Hz Metal GPU rendering** *plus*:
  - An **Attention Center** that alerts you when long-running commands finish or fail across any background workspace.
  - A **Live Ports & Processes (`⇧⌘P`)** tab that maps every listening port (`:3000`, `:5173`, `:8080`) and child process back to the terminal pane that started it, with one-click **Kill** or **Open in Browser**.
  - **Quick Links & File Paths (`⇧⌘L`)** and **In-Terminal Regex Search (`⌘F`)** without needing `tmux` copy-mode scripts.

### 2.3 vs. iTerm2
- **Modern Ergonomics Without 500 Settings Pages**: iTerm2 is legendary, but its preferences dialog accumulated over two decades of legacy options. Nathstar provides a clean, modern macOS SwiftUI interface where **Projects / Personal / Others**, **SSH Hosts**, **Themes**, **Snippets**, **Manifests**, and **AI Chat** work out of the box.
- **Silent Live Environment Variable Sync**: In iTerm2, changing an environment variable requires either restarting the session or pasting `export KEY=VALUE` into the terminal. Nathstar's `SIGUSR1` + `ZDOTDIR` integration injects updated variables into running shells **silently in the background**.

### 2.4 vs. cmux / tmux
- **No Arcane Key Chords Required**: Multiplexers like `tmux` require memorizing `Ctrl+B` prefix chords and configuring `.tmux.conf` just to split panes or persist sessions. Nathstar provides native macOS split panes (`⌘D` / `⇧⌘D`), pane zoom (`⇧⌘⏎`), drag-and-drop tabs, scrollback snapshot restoration, and an optional single-toggle **Background `tmux` Multiplexer Mode** in Settings when you want processes to survive across `⌘Q`.
