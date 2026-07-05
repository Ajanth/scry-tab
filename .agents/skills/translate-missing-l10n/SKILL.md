---
name: translate-missing-l10n
description: Translate missing localization strings for this project. Use after adding or changing user-facing Swift text. Refresh the source strings, find missing language entries, preserve format specifiers and macOS terminology, and apply translations through `scripts/l10n/apply_translations.ts`.
---

# Translate Missing Localizations

## Languages

`de, ja, fr, es, zh-CN, pt-BR, nl, ko, it, pl, ar, zh-HK, vi, tr, sv, th, zh-TW, he, id, ru`

English is the source and is handled by the apply script.

## Rules

- Preserve `%@`, `%d`, positional specifiers, `\n`, and `\t`; counts and argument meaning must match.
- Do not translate this project's product name, macOS, Mission Control, Spaces, Dock, or modifier-key names.
- Use Apple's official localized platform terms and concise, neutral macOS phrasing.
- Use source comments only for disambiguation; never include them in output.

## Workflow

1. Refresh:
   ```bash
   bash scripts/l10n/extract_l10n_strings.sh
   ```
2. Parse ordered `(comment, key, value)` entries from `resources/l10n/Localizable.strings`.
3. For each target language, treat absent, empty, or whitespace-only values as missing. Stop and report if none are missing.
4. Translate only source keys, following the rules above.
5. Apply temporary JSON batches:
   ```json
   {
     "fr": { "About %@": "À propos de %@", "Quit": "Quitter" },
     "ja": { "About %@": "%@について" }
   }
   ```
   ```bash
   npx ts-node scripts/l10n/apply_translations.ts /tmp/batch-NN.json
   ```
6. Fix every rejected format-specifier mismatch and rerun the affected languages. The script preserves source order, existing translations, and English source keys while pruning obsolete keys.

## Reporting

Report languages processed, translations merged, intentionally unchanged proper nouns, and corrected rejections.
