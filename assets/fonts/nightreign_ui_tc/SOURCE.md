# Nightreign UI TC font source

The bundled Traditional Chinese HUD font is a **modified subset** built from Noto Sans TC / Noto CJK and is distributed under the SIL Open Font License 1.1 in `OFL.txt`.

Upstream source:
- Project: `notofonts/noto-cjk`
- Pinned commit: `523d033d6cb47f4a80c58a35753646f5c3608a78`
- Input path: `Sans/Variable/TTF/Subset/NotoSansTC-VF.ttf`
- Source family: Noto Sans TC
- Output family: Nightreign UI TC
- Output weight: 400

The subset contains printable ASCII plus the non-ASCII glyphs currently present in:
- `src/nightreign/ui/night_ui_text.gd`
- `src/nightreign/expedition/night_overlay.gd`

Rebuild with `art/build_zh_tw_font_subset.py`. The materializer workflow pins the upstream commit so the source is reproducible.
