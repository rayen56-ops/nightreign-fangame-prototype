#!/usr/bin/env python3
"""Materialize dedicated 16x16 Nightreign weapon icons into the shared item atlas.

This deliberately keeps the existing ItemTiles pipeline authoritative. Existing sprite
coordinates never move; Nightreign icons are appended to unused atlas cells and the
TileSet resource is rebuilt from the JSON coordinate contract.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Callable

from PIL import Image, ImageDraw

TILE_SIZE = 16
ATLAS_PATH = Path("assets/generated/item_sprites.png")
JSON_PATH = Path("assets/generated/item_sprites.json")
TRES_PATH = Path("assets/generated/item_sprites.tres")
TILESET_UID = "uid://ddw73pjo8youv"

OUTLINE = (27, 30, 38, 255)
STEEL_DARK = (86, 96, 111, 255)
STEEL = (184, 196, 211, 255)
STEEL_LIGHT = (235, 241, 246, 255)
WOOD = (103, 72, 48, 255)
WOOD_LIGHT = (151, 105, 63, 255)
GOLD_DARK = (137, 99, 38, 255)
GOLD = (220, 173, 73, 255)
HOLY = (255, 229, 128, 255)
GLINT = (91, 176, 255, 255)
GLINT_LIGHT = (181, 224, 255, 255)
VIOLET = (151, 116, 230, 255)


def _canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def _longsword() -> Image.Image:
    image, d = _canvas()
    d.line((4, 13, 6, 11), fill=OUTLINE, width=3)
    d.line((3, 11, 7, 11), fill=GOLD_DARK, width=2)
    d.line((6, 10, 12, 4), fill=OUTLINE, width=3)
    d.line((6, 10, 12, 4), fill=STEEL, width=1)
    d.point((13, 3), fill=STEEL_LIGHT)
    d.point((5, 13), fill=WOOD_LIGHT)
    return image


def _greatsword() -> Image.Image:
    image, d = _canvas()
    d.line((3, 14, 5, 12), fill=WOOD, width=3)
    d.line((2, 12, 7, 12), fill=GOLD_DARK, width=2)
    d.polygon([(5, 11), (7, 12), (14, 4), (13, 2), (11, 3)], fill=OUTLINE)
    d.polygon([(7, 10), (8, 10), (13, 4), (12, 4)], fill=STEEL)
    d.point((13, 3), fill=STEEL_LIGHT)
    return image


def _katana() -> Image.Image:
    image, d = _canvas()
    d.line((3, 14, 6, 11), fill=WOOD, width=3)
    d.line((4, 11, 7, 12), fill=GOLD_DARK, width=1)
    d.line([(6, 10), (8, 8), (11, 6), (13, 3)], fill=OUTLINE, width=3)
    d.line([(6, 10), (8, 8), (11, 6), (13, 3)], fill=STEEL_LIGHT, width=1)
    d.point((12, 3), fill=STEEL)
    return image


def _rapier() -> Image.Image:
    image, d = _canvas()
    d.line((4, 14, 6, 12), fill=WOOD, width=2)
    d.ellipse((3, 10, 7, 14), outline=GOLD, width=1)
    d.line((3, 11, 8, 11), fill=GOLD_DARK, width=1)
    d.line((6, 10, 13, 3), fill=OUTLINE, width=2)
    d.line((6, 10, 13, 3), fill=STEEL_LIGHT, width=1)
    d.point((14, 2), fill=STEEL_LIGHT)
    return image


def _dagger() -> Image.Image:
    image, d = _canvas()
    d.line((4, 13, 6, 11), fill=WOOD, width=3)
    d.line((3, 11, 7, 11), fill=GOLD_DARK, width=2)
    d.polygon([(6, 10), (8, 11), (12, 6), (11, 5)], fill=OUTLINE)
    d.line((7, 10, 11, 6), fill=STEEL_LIGHT, width=1)
    return image


def _staff() -> Image.Image:
    image, d = _canvas()
    d.line((4, 14, 10, 5), fill=OUTLINE, width=3)
    d.line((5, 13, 10, 5), fill=WOOD_LIGHT, width=1)
    d.polygon([(10, 1), (13, 4), (10, 7), (7, 4)], fill=VIOLET)
    d.polygon([(10, 2), (12, 4), (10, 5), (9, 4)], fill=GLINT)
    d.point((10, 3), fill=GLINT_LIGHT)
    return image


def _seal() -> Image.Image:
    image, d = _canvas()
    d.ellipse((3, 3, 12, 12), fill=GOLD_DARK, outline=OUTLINE, width=1)
    d.ellipse((5, 5, 10, 10), outline=HOLY, width=1)
    d.line((7, 4, 8, 11), fill=HOLY, width=1)
    d.line((4, 7, 11, 8), fill=GOLD, width=1)
    for point in ((7, 2), (13, 7), (7, 13), (2, 7)):
        d.point(point, fill=HOLY)
    return image


def _sacred_blade() -> Image.Image:
    image, d = _canvas()
    for point in ((12, 2), (14, 5), (10, 4), (8, 7), (5, 10)):
        d.point(point, fill=HOLY)
    d.line((4, 14, 6, 12), fill=WOOD, width=3)
    d.line((3, 11, 8, 12), fill=GOLD, width=2)
    d.line((6, 10, 12, 4), fill=OUTLINE, width=3)
    d.line((6, 10, 12, 4), fill=HOLY, width=1)
    d.point((13, 3), fill=STEEL_LIGHT)
    return image


ICON_BUILDERS: dict[str, Callable[[], Image.Image]] = {
    "night-longsword": _longsword,
    "night-greatsword": _greatsword,
    "night-katana": _katana,
    "night-rapier": _rapier,
    "night-dagger": _dagger,
    "night-staff": _staff,
    "night-seal": _seal,
    "night-sacred-blade": _sacred_blade,
}


def _next_free_coord(
    occupied: set[tuple[int, int]], atlas_width: int, atlas_height: int
) -> tuple[int, int]:
    cols = atlas_width // TILE_SIZE
    rows = atlas_height // TILE_SIZE
    max_index = -1
    for x, y in occupied:
        max_index = max(max_index, (y // TILE_SIZE) * cols + (x // TILE_SIZE))
    for index in range(max_index + 1, cols * rows):
        coord = ((index % cols) * TILE_SIZE, (index // cols) * TILE_SIZE)
        if coord not in occupied:
            return coord
    for index in range(cols * rows):
        coord = ((index % cols) * TILE_SIZE, (index // cols) * TILE_SIZE)
        if coord not in occupied:
            return coord
    raise RuntimeError("Item atlas has no free 16x16 cells for Nightreign weapon icons")


def _write_tileset(path: Path, coords: set[tuple[int, int]]) -> None:
    lines = [
        f'[gd_resource type="TileSet" format=3 uid="{TILESET_UID}"]',
        "",
        '[ext_resource type="Texture2D" path="res://assets/generated/item_sprites.png" id="1"]',
        "",
        '[sub_resource type="TileSetAtlasSource" id="Atlas"]',
        'texture = ExtResource("1")',
        f"texture_region_size = Vector2i({TILE_SIZE}, {TILE_SIZE})",
    ]
    for x, y in sorted(coords, key=lambda c: (c[1], c[0])):
        lines.append(f"{x // TILE_SIZE}:{y // TILE_SIZE}/0 = 0")
    lines.extend(
        [
            "",
            "[resource]",
            f"tile_size = Vector2i({TILE_SIZE}, {TILE_SIZE})",
            'sources/0 = SubResource("Atlas")',
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def materialize_weapon_icons(
    atlas_path: Path = ATLAS_PATH,
    json_path: Path = JSON_PATH,
    tres_path: Path = TRES_PATH,
) -> dict[str, list[int]]:
    atlas = Image.open(atlas_path).convert("RGBA")
    payload = json.loads(json_path.read_text(encoding="utf-8"))
    if int(payload.get("spriteSize", 0)) != TILE_SIZE:
        raise RuntimeError("Nightreign item icons require a 16x16 shared item atlas")

    sprites: dict[str, list[int]] = payload["sprites"]
    icon_names = set(ICON_BUILDERS)
    occupied = {
        (int(coord[0]), int(coord[1]))
        for name, coord in sprites.items()
        if name not in icon_names
    }

    for name, builder in ICON_BUILDERS.items():
        current = sprites.get(name)
        if current is not None:
            coord = (int(current[0]), int(current[1]))
            if coord in occupied:
                raise RuntimeError(f"Nightreign icon coordinate collision for {name}: {coord}")
        else:
            coord = _next_free_coord(occupied, atlas.width, atlas.height)
        occupied.add(coord)
        sprites[name] = [coord[0], coord[1]]
        atlas.paste(builder(), coord)

    atlas.save(atlas_path, "PNG")
    json_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    _write_tileset(tres_path, {tuple(map(int, c)) for c in sprites.values()})
    return {name: sprites[name] for name in ICON_BUILDERS}


def main() -> None:
    coords = materialize_weapon_icons()
    print("Materialized Nightreign weapon icons:")
    for name, coord in coords.items():
        print(f"  {name}: {coord}")


if __name__ == "__main__":
    main()
