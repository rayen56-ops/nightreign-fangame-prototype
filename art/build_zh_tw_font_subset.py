#!/usr/bin/env python3
"""Build the compact Traditional Chinese HUD font bundled with the Web build.

Source font: Noto Sans TC / Noto CJK, SIL OFL 1.1.
The output is renamed because it is a modified/subsetted font.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ASCII = "".join(chr(i) for i in range(0x20, 0x7F))
EXTRA_GLYPHS = "，。！？：「」『』（）【】％／△□"


def collect_text(paths: list[Path]) -> str:
    chars = set(ASCII + EXTRA_GLYPHS)
    for path in paths:
        text = path.read_text(encoding="utf-8")
        chars.update(ch for ch in text if ord(ch) >= 0x80)
    return "".join(sorted(chars))


def rename_font(font: TTFont) -> None:
    replacements = {
        1: "Nightreign UI TC",
        2: "Regular",
        4: "Nightreign UI TC Regular",
        6: "NightreignUITC-Regular",
        16: "Nightreign UI TC",
        17: "Regular",
    }
    for record in font["name"].names:
        replacement = replacements.get(record.nameID)
        if replacement is None:
            continue
        try:
            record.string = replacement.encode(record.getEncoding())
        except Exception:
            record.string = replacement.encode("utf-16-be")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--text-source", action="append", type=Path, required=True)
    args = parser.parse_args()

    glyph_text = collect_text(args.text_source)
    font = TTFont(args.source)
    if "fvar" in font:
        font = instantiateVariableFont(font, {"wght": 400}, inplace=False)

    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    options.notdef_glyph = True
    options.recommended_glyphs = True

    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text=glyph_text)
    subsetter.subset(font)
    rename_font(font)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    font.save(args.output)

    # Reopen the artifact and guarantee every requested character survived.
    check = TTFont(args.output)
    cmap = {cp for table in check["cmap"].tables for cp in table.cmap}
    missing = sorted(ord(ch) for ch in glyph_text if ord(ch) not in cmap)
    if missing:
        rendered = "".join(chr(cp) for cp in missing)
        raise SystemExit(f"subset is missing glyphs: {rendered}")

    print(
        f"Built {args.output} with {len(set(glyph_text))} codepoints "
        f"({args.output.stat().st_size} bytes)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
