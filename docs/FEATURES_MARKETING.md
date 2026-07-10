# ScryTab — Feature Overview for Marketing & Landing Pages

> **Audience:** Landing page writers, marketing teams, and content designers.
> This document describes what ScryTab does and how its features work **from a user's perspective**, without code references or implementation detail. Use it to write copy, plan feature sections, build comparison tables, or brief designers.

---

## What Is ScryTab?

**ScryTab is a window switcher for macOS.** It replaces the built-in Command-Tab experience with something faster, smarter, and fully customizable. Instead of cycling through apps blindly, ScryTab shows a clean panel of exactly the windows you care about — filtered by Space, screen, app, or whatever rule you set — so you can jump to the right place in a single keystroke or trackpad swipe.

ScryTab is **free, with no trial, no paywall, and no feature tiers.** Every capability described in this document is available to every user from day one.

---

## Core Value Propositions

| Benefit | What it means for users |
|---|---|
| **Speed** | The switcher appears instantly with no animation delay, and the app stays responsive in the background (no App Nap). |
| **Precision** | Per-shortcut filters let users show only what is relevant: current Space, current screen, certain apps, no minimized windows, etc. |
| **Flexibility** | Up to 9 independent shortcut profiles, each with its own filters, appearance, and ordering — so a developer and a designer workflow can live side by side. |
| **Keyboard-first, trackpad-friendly** | Full keyboard navigation, Vim keys, and a dedicated trackpad gesture profile make it feel at home for any input style. |
| **Free forever** | No licensing, activation, payment, or feature gating of any kind. |

---

## Feature Sections

### 1 — Intelligent Window Switching

ScryTab presents a floating panel of your open windows the moment you trigger it. The panel:

- **Appears instantly** with no delay or fade animation.
- **Stays out of your way** — it sits above all other content as a non-activating overlay, so the previously focused window never loses focus when the switcher opens.
- **Shows the right windows** based on per-shortcut filter rules you configure once and forget.
- **Handles edge cases gracefully** — phantom windows (invisible or synthetic macOS windows) are automatically detected and hidden; tabbed windows can appear as one group or as individual entries; windowless apps (running but with no open window) are shown with a clear indicator so you can still switch to or launch them.

> **Copy angle:** "See only what matters. ScryTab strips away noise so you switch to the right window on the first try, every time."

---

### 2 — Multiple Shortcut Profiles

Users can create up to **9 independent keyboard shortcut profiles**. Each profile is a complete, independent configuration:

- **Its own trigger** — any key combination you choose (default: Option-Tab and the key above Tab).
- **Its own filter rules** — which apps, Spaces, screens, and window states to show.
- **Its own appearance** — icon grid or title list, small/medium/large/auto size, light/dark/system theme.
- **Its own ordering** — most recently focused, most recently created, alphabetical, or Space order.
- **Its own release behavior** — switch instantly on key-up, hold the panel open, or open directly in search mode.

Extra profiles beyond the first are added from the Controls settings and can be removed at any time.

> **Copy angle:** "One shortcut for all windows. Another for just your current Space. A third for a specific project's apps. ScryTab adapts to how you actually think."

---

### 3 — Powerful Filtering and Ordering

Each shortcut profile can filter windows by:

- **App scope** — show only the active app's windows, only other apps, or all apps.
- **Space scope** — visible Spaces only, non-visible Spaces only, or all Spaces.
- **Screen scope** — all screens, or just the screen where ScryTab appears.
- **Window state** — choose to show, hide, or push to the end: minimized, hidden, fullscreen, and windowless app entries.
- **Grouping** — collapse tabbed windows into one entry or show them separately; collapse each app down to just its main window.
- **Exceptions** — hide specific apps entirely, hide them only when they have no windows, hide by window title pattern, or suppress ScryTab shortcuts while that app is in front (useful for remote desktop, virtualization, and screen-sharing apps).

Ordering modes:

- **Recently focused** (default, feels like native Command-Tab)
- **Recently created**
- **Alphabetical**
- **Space order**

> **Copy angle:** "Show the windows you use. Hide the ones you don't. ScryTab's filters put you in control."

---

### 4 — Fast In-Panel Search

Type to search from inside the switcher — no extra shortcut needed. Search works across **app names and window titles** simultaneously, with:

- **Smart ranking** — exact matches, word prefixes, substrings, acronyms, and fuzzy typo-tolerant matching (Damerau-Levenshtein), all scored and sorted automatically.
- **Highlighted matches** — matching text is highlighted in both app name and window title, including when the match is in the truncated portion of a long title.
- **Three modes** — off, editing (full keyboard control of the search field), and locked (result set frozen; keyboard returns to tile navigation).
- **CJK, emoji, and diacritic support** — works correctly with non-Latin text.
- **Search-first shortcut** — any profile can be set to open directly in search editing mode, skipping the visual panel entirely.
- **Stable anchor** — while searching, the panel anchors to its tallest point so narrowing results shrinks the panel downward rather than jumping around the screen.

> **Copy angle:** "Just start typing. ScryTab finds the window across every open app, typos and all."

---

### 5 — Two Visual Styles

**App Icons** — large app icons arranged in a grid. At a glance, familiar and fast for recognition.

**Titles** — a compact text list showing app name and window title. Better for dense workloads or when many windows from the same app are open.

Both styles support:

- **Size:** Small, Medium, Large, or **Auto** (ScryTab picks the largest size that fits the screen).
- **Theme:** Light, Dark, or System (follows macOS appearance).
- **Title display:** Window title, app name only, or app name + window title.
- **Title truncation:** Start, middle, or end.
- **Status icons:** Optional indicators for minimized, hidden, fullscreen, different-Space, and windowless state.
- **Space number labels:** See which Space each window lives on at a glance.
- **Colored hover circles:** Optional highlight ring on hover.
- **Dock badges:** App notification badges visible directly on tiles.

Appearance settings include a **live animated preview** that cycles the selection highlight through demo tiles once per second — so you see exactly how your chosen style looks before you commit, with no need to open the real switcher. The preview respects your Reduce Motion setting and can be paused manually.

Each shortcut profile can override the global appearance independently, so you can have one profile in App Icons and another in Titles.

> **Copy angle:** "Clean icons for quick recognition. Compact titles for dense workspaces. Switch between them — or use both at once."

---

### 6 — Keyboard Controls

ScryTab is built for keyboard-first users:

- **Arrow key navigation** (optional, can be toggled on/off).
- **Vim-style h/j/k/l navigation** (optional).
- **Key repeat** — hold the trigger or navigation key to cycle continuously.
- **In-switcher actions** — close a window, minimize/deminimize, toggle fullscreen, quit an app, or hide/show an app without leaving the switcher.
- **Cursor follow-focus** — optionally warp the cursor to the focused window after switching (Never / Always / Only on a different screen).
- **Conflict detection** — enabling arrow or Vim navigation automatically detects and offers to unassign conflicting shortcuts.
- **Reserved chord protection** — the shortcut recorder warns if you try to use a macOS system-reserved chord (like ⌘⌥⎋).
- **Escape handling** — if any shortcut uses Escape, ScryTab absorbs it so macOS Game Overlay does not intercept it first.

> **Copy angle:** "Every action, without leaving the keyboard. Switch, close, minimize, quit — all from the switcher."

---

### 7 — Trackpad Gestures

A dedicated gesture profile can trigger the switcher with:

- 3-finger horizontal swipe
- 3-finger vertical swipe
- 4-finger horizontal swipe
- 4-finger vertical swipe

Gesture behavior:

- Mimics native macOS Space-swipe thresholds so it feels familiar.
- Rejects accidental triggers from prior two-finger scrolls.
- While the switcher is open, further swipes navigate selection one row or column at a time.
- Optional **haptic feedback** on trigger and navigation.
- Scroll-wheel input from the trackpad is blocked while gesture switching is active so it does not leak into the front app.

> **Copy angle:** "Swipe to switch. ScryTab brings its full power to trackpad users with the same gesture vocabulary macOS already uses."

---

### 8 — Mouse and Click Support

- **Click to focus** — left-click any tile to switch to it.
- **Middle-click to close** — middle-click a tile to close that window (or quit the app if it is a windowless entry).
- **Click outside to dismiss** — click anywhere outside the panel to close it.
- **Hover selection** — optionally select tiles as the pointer moves over them.
- **Dead zone after keyboard/gesture navigation** — a 25 px pointer dead zone prevents accidental hover changes right after a keyboard or trackpad navigation.
- **Drag and drop** — drag files onto the panel; dragging over a tile selects it after a 2-second hold and drops the file into the target app.

> **Copy angle:** "Fully mouse-friendly. Click, middle-click, drag and drop — ScryTab works the way you do."

---

### 9 — App and Window Actions

From inside the switcher, users can act on any window:

| Action | How |
|---|---|
| Focus window | Release trigger or Enter or left-click |
| Close window | Configurable keyboard shortcut or middle-click |
| Minimize / Deminimize | Configurable keyboard shortcut |
| Toggle fullscreen | Configurable keyboard shortcut |
| Quit app | Configurable keyboard shortcut |
| Hide / Show app | Configurable keyboard shortcut |

Focusing a window on another Space crosses Space boundaries automatically. Minimized windows are deminimized before being raised.

> **Copy angle:** "Don't just switch — act. Close, minimize, quit, and more, all without touching the app."

---

### 10 — Exceptions (Per-App Rules)

The Exceptions settings tab lets users create per-app rules:

- **Always hide** — the app never appears in the switcher.
- **Hide when no window** — the app is hidden when it has no open windows (the default for Finder).
- **Hide by window title** — hide specific windows by title pattern, with support for multiple patterns per app.
- **Ignore shortcuts when frontmost** — ScryTab's global shortcuts are suppressed while the app is in front.

Built-in presets cover common cases: Screen Sharing, Microsoft Remote Desktop, TeamViewer, VirtualBox, Parallels, Citrix, VMware Fusion, UTM, NICE DCV.

Exceptions can be added by picking from running apps or browsing for an app on disk.

> **Copy angle:** "Tell ScryTab what to ignore. Rules for Finder, remote desktop, and any app you name."

---

### 11 — Settings Search

The Settings window includes a **live search bar** that filters all settings sections and highlights matching controls. Typing any term — even partially or with a typo — surfaces the relevant control across Appearance, Controls, General, and Exceptions instantly.

> **Copy angle:** "Can't find a setting? Just type. ScryTab's settings search finds it in milliseconds."

---

### 12 — General & System Integration

- **Start at login** — one toggle; no helper app or daemon required.
- **Menubar item** — quick access to Show, Settings, updates, and feedback; icon style can be outlined, filled, or colored, or hidden entirely.
- **Language support** — 21 languages including Arabic, Chinese (Simplified, Traditional, HK), French, German, Japanese, Korean, Russian, Spanish, and more.
- **Export / Import / Reset settings** — move your configuration between Macs or reset to defaults in one click.
- **Automatic and manual updates** — powered by Sparkle; choose manual checks, periodic checks, or auto-install. Update checks include app version, macOS version, architecture, and language for relevant release notes.
- **Crash reporting** — opt-in (Ask, Always, or Never). Crash reports include a debug profile; network access is enabled only when a report is sent.
- **Feedback** — built-in form for bug reports and suggestions, with a link to existing discussions and a pre-send update check to ensure reports are filed against the latest version.
- **Restores native Command-Tab** — if ScryTab owns the Command-Tab chord, it suppresses the native switcher while active and restores it cleanly on quit or crash.
- **macOS 26 (Sequoia) ready** — uses Liquid Glass panel background on macOS 26+; falls back to the standard visual-effect material on earlier releases.

---

### 13 — CLI Access (Power Users)

ScryTab exposes a local command-line interface for automation and scripting:

- `--list` — JSON list of window IDs and titles.
- `--detailed-list` — extended per-window JSON (app name, bundle ID, Space indexes, focus/creation order, flags, position, size).
- `--focus=<id>` — focus a window by ID.
- `--focusUsingLastFocusOrder=<index>` — focus by recency rank.
- `--show=<shortcutIndex>` — programmatically show the switcher for any shortcut profile.

> **Copy angle:** "Scriptable. Automatable. ScryTab fits into any power-user workflow."

---

## Frequently Misunderstood Points

| Point | Clarification |
|---|---|
| **Accessibility permission** | ScryTab requires only Accessibility. It never requests Screen Recording. Accessibility is needed to focus, raise, close, minimize, and inspect windows. |
| **Completely free** | No trial period, no locked features, no in-app purchase. The full feature set is available immediately. |
| **Not an extension** | ScryTab is a standalone macOS app with a menubar item, not a Safari/browser extension. |
| **Works across all Spaces** | By default the switcher shows windows from all Spaces. Per-shortcut filters can limit this to visible Spaces or the current Space only. |
| **Tabbed windows** | Tabbed windows (e.g., Safari tabs as window groups) can appear as one unified entry or as individual windows — user's choice. |

---

## Positioning One-Liners

Choose the one that fits the context:

- *"The window switcher macOS should have shipped with."*
- *"Switch windows in one keystroke, not five."*
- *"Command-Tab, rebuilt for how you actually work."*
- *"Every window, filtered your way, at a gesture."*
- *"Free. No trial. Just fast."*

---

*This document is generated from the technical product inventory (`PRODUCT_FEATURE_INVENTORY.md`) and should be updated whenever the inventory changes.*
