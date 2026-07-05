# Appearance inspector column — handoff context

## Goal

Move the Appearance **style preview** (App Icons vs Titles) into a **dedicated right column** on the Appearance settings page, Loop-style. Keep the style choice as a **chip/segmented control** in the left column; the right column shows **only** the selected illustration. Preview is **static for now** (no animation yet).

**Do not copy** Loop’s blue preview rectangle, radial menu, or live snap preview — only the **inspector column layout and transparent surface feel**.

---

## Loop reference (SwiftUI + Luminare)

| File | What to read |
|------|----------------|
| `/Users/ajanth/development/area-51/macos-apps/boilerplates/Loop/Loop/Settings Window/SettingsContentView.swift` | Three-column `LuminareDividedStack`: sidebar 230pt, center pane 390pt, **inspector 520pt** with `.padding(12)`. Inspector is `Color.clear.overlay { … }` — **no** `.luminareBackground()` on the column itself. |
| `/Users/ajanth/development/area-51/macos-apps/boilerplates/Loop/Loop/Settings Window/SettingsWindowManager.swift` | Window host: near-clear background + SkyLight blur behind the whole settings window. |
| `/Users/ajanth/development/area-51/macos-apps/boilerplates/Loop/Loop/Window Action Indicators/Preview Window/PreviewView.swift` | **Inner preview card** only: `VisualEffectView(.hudWindow, .behindWindow)` + accent gradient + borders. This is content *inside* the inspector, not the column chrome. |
| `/Users/ajanth/development/area-51/macos-apps/boilerplates/Loop/Loop/Utilities/VisualEffectView.swift` | AppKit `NSVisualEffectView` wrapper used by preview cards. |

**Loop pattern to translate:** left/center panes are material-backed; **right inspector column is transparent** over the window blur. Preview artwork sits inside that column with optional inner blur/material — not another opaque settings group.

---

## Scry-tab — current implementation

| File | Role |
|------|------|
| `src/preferences/settings-window/tabs/appearance/AppearanceTab.swift` | **Primary edit target.** `AppearanceStylePreviewPane`, `makeView()` two-column layout, style segmented control, preview update. |
| `src/preferences/settings-window/SettingsWindow.swift` | `contentWidth = 710`; section scroll/stack hosts tab content. |
| `src/preferences/settings-window/TableGroupView.swift` | Grouped left-column panels (`surfacePlateau` rows). |
| `src/preferences/settings-window/LabelAndControl.swift` | `makeSegmentedControl` → `DesignSystemSegmentedControl`. |
| `src/preferences/MacroPreferences.swift` | `AppearanceStylePreference` (`.appIcons`, `.titles`); HEIC asset names `app_icons`, `titles`. |
| `src/kit/design-system/surfaces/DesignSystemSurfaces.swift` | `DesignSystemMaterialView` (menu material + tint, `.behindWindow`). |
| `src/kit/design-system/controls/DesignSystemControls.swift` | `DesignSystemControlStyler.styleSurface` / `refreshSurface` → opaque `surfacePlateau`. |
| `src/kit/design-system/tokens-and-appearance/DesignSystem.swift` | Surface roles, metrics. |
| `src/kit/ImageTextButtonView.swift` | **Old** style tiles (replaced by segmented control; still used elsewhere). |
| `src/preferences/settings-window/tabs/appearance/CustomizeStyleSheet.swift` | `IllustratedImageThemeView.loadIllustration` — reuse for preview images. |

### Layout today (`AppearanceTab.makeView`)

```
NSView container (plain, width = SettingsWindow.contentWidth = 710)
├── leftColumn: TableGroupSetView (appearanceControlsWidth = 430), pinned top/leading/bottom
│   ├── appearance controls TableGroupView (subtitle + row panel)
│   └── multiple screens TableGroupView   ← must stay here, not full width
└── previewPane: AppearanceStylePreviewPane (width = 268, spacing = 12)
    ├── top == appearanceView.tableStackViews[0].top (the row panel, not leftColumn's subtitle)
    ├── bottom == leftColumn.bottom
    └── centered NSImageView (illustration)
```

A plain `NSView` (not `NSStackView`) hosts the split: the preview pane's top must line up with
`appearanceView`'s row panel specifically, not `leftColumn`'s own frame top (which sits above that
panel's subtitle text). A stack view's `.top` alignment can only match sibling frames, so it can't
express "align with this descendant" without fighting a manual constraint — hence explicit
leading/top/bottom constraints instead. `makeAppearanceControlsView` now returns `TableGroupView`
(not `NSView`) so `makeView` can reach its `tableStackViews[0]` anchor.

Style control: segmented `appearanceStyle` row; `updatePreview` on change.

### Known gaps vs Loop (still not perfect)

1. **Inspector surface** — `AppearanceStylePreviewPane` uses `DesignSystemControlStyler.styleSurface(self)` (opaque `surfacePlateau` + border). Loop’s inspector **column** is clear; only inner preview content gets blur. Current pane reads like a third grouped settings card, not a translucent inspector.
2. **Proportions** — preview column is 268pt vs Loop’s 520pt inspector; may feel cramped or too “card-like”.
3. ~~**Height** — `previewPane.heightAnchor.constraint(equalTo: leftColumn.heightAnchor)` ties to left content only; may not match section/window vertical rhythm if section grows.~~ **Fixed** — pane top now pins to `appearanceView.tableStackViews[0].topAnchor` and bottom to `leftColumn.bottomAnchor`, so both panels start and end at the same y regardless of subtitle height/wrapping.
4. **Animation** — style switch is instant image swap; Loop uses `luminareAnimation` / `AnimationConfiguration.previewWindow` (out of scope unless requested).
5. **Visual QA** — build passes; top-alignment fix verified against the reported screenshot and by re-deriving the constraint math; in-app look still not launched/screenshotted by the agent.

---

## Constraints (mandatory)

- Read `.agents/skills/swift-appkit-development/SKILL.md` and `references/ui-design-standard.md` before editing.
- AppKit only (Swift 5.8, macOS 10.13). No SwiftUI.
- Reuse design system; **extend shared primitives** if a transparent inspector surface is missing — do not add feature-local RGB/alpha/materials.
- Window material already comes from `DesignSystemWindowContentView` / `DesignSystemMaterialView`.
- Run `graphify update .` after Swift changes; verify with `ai/build.sh` command sequence.

---

## Suggested next step

Replace `styleSurface` on the **column container** with a transparent or material-backed inspector primitive (likely `DesignSystemMaterialView` with clear/minimal tint, or a new shared “inspector pane” surface if needed). Keep the illustration as inner content. Preserve: left column width math, segmented style control, `Multiple screens` in left column only, static preview swap on selection.
