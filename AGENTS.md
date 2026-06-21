# AtonementRail Notes

- This is a small WoW Retail addon. Keep changes scoped to `Core.lua`, `Options.lua`, `AtonementRail.toc`, and docs unless a feature genuinely needs more files.
- The `barSkin` option is intentionally limited to simple built-in UI rendering. `paddedBorder` means a 2px inset plus a subtle border; do not use external mask textures for this style.
- Preserve the classic style as the default so existing users keep the original compact bars unless they opt in.
- After changing options or saved variables, keep reset defaults, migration logic, README text, and option labels aligned.
