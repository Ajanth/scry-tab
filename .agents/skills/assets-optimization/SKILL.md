---
name: assets-optimization
description: Audit and optimize image assets shipped with this project. Use when adding or replacing images, reducing bundle size, or auditing resources. Keep custom vectors as stripped PDFs, SF Symbols in the bundled font subset, raster artwork as visually verified HEIC, and the app icon as ICNS.
---

# Asset Optimization

## Inventory

```bash
find resources -type f \( -iname '*.pdf' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' -o -iname '*.svg' -o -iname '*.icns' \) \
  -exec ls -la {} \; | awk '{printf "%8d  %s\n", $5, $9}' | sort -k2
```

| Source content | Right format | Why |
|---|---|---|
| Custom vector design (Figma/Sketch/Illustrator) | **PDF** | macOS 10.13 doesn't accept SVG; PDF is the universal vector container AppKit reads natively. |
| SF Symbol | Bundled `SF-Pro-Text-Regular.otf` subset | Reuse `Symbols` and `NSImage.fromSymbol`. |
| Photographic or screenshot-heavy artwork | **HEIC** | Use q50 initially and verify visually. |
| Tiny pixel-precise UI sprite | **PNG @2x** | Keep only when PDF overhead is larger. |
| App icon (the macOS bundle one) | **`.icns`** | Required by `CFBundleIconFile`. |

## Vector PDFs

```bash
python3 scripts/assets/optimize_figma_pdf.py resources/icons/menubar/your-icon.pdf
```

The script removes unused Figma metadata, structure, and color profiles. Render every changed PDF and inspect it:

```bash
for f in resources/icons/menubar/*.pdf; do
  sips -s format png "$f" --out "/tmp/$(basename $f .pdf).png" -Z 300 >/dev/null 2>&1
done
```

## SF Symbols

To add a new SF Symbol:

1. Copy the symbol character from SF Symbols.app.
2. Add it to `Symbols` in `src/switcher/main-window/TileFontIconView.swift`.
3. Add it to the `--text=` argument in `scripts/assets/subset_font.sh`.
4. Run `bash scripts/assets/subset_font.sh`. It reads `/Library/Fonts/SF-Pro-Text-Regular.otf` (installed by SF Symbols.app — a standard developer prerequisite) and writes the regenerated subset to `resources/SF-Pro-Text-Regular.otf`. Picks up Apple's latest glyph refinements automatically.
5. Use `NSImage.fromSymbol` or `TileFontIconView`; do not add per-symbol PDFs.

## Raster Artwork

```bash
sips -Z 1000 -s format heic -s formatOptions 50 input.png --out output.heic
bash scripts/assets/encode_heic.sh ~/Desktop 1000 50
```

The 1000-pixel longest edge matches the 500-point illustration display at @2x. Before replacing resources, decode the most demanding output and compare it with the source using an available local image inspection tool:

```bash
sips -s format png /tmp/heic-out/sample.heic --out /tmp/sample-decoded.png >/dev/null 2>&1
```

Reject banding, soft text, halos, or color shifts. Retry at q60 or q65 when q50 is visibly degraded. Do not claim visual equivalence without inspection.

## Project Registration

When an extension changes or a file is added or removed, update all corresponding entries in the Xcode project's `project.pbxproj`:

1. `PBXBuildFile`
2. `PBXFileReference`, including `lastKnownFileType` and `path`
3. The parent `PBXGroup`
4. `PBXResourcesBuildPhase`

Use new 24-character uppercase hex IDs for new entries. Remove all four entries for deleted assets.

## Verify and Report

- Inspect `ai/build.sh`, copy its complete non-comment command sequence, resolve script-relative paths against `ai/build.sh`, and run the commands directly in order.
- Do not launch the app or open/control a browser unless explicitly requested. Report any unverified in-app appearance as a gap.
- Report file-by-file and total size deltas, encoder settings, visual results, and intentionally unchanged assets.
