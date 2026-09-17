#!/usr/bin/env python3
"""Guarded source patch for the M1.5 Nightreign weapon visual contract."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SPRITES = {
    "longsword": "night-longsword",
    "greatsword": "night-greatsword",
    "uchigatana": "night-katana",
    "rapier": "night-rapier",
    "misericorde": "night-dagger",
    "glintstone_staff": "night-staff",
    "finger_seal": "night-seal",
    "sacred_blade": "night-sacred-blade",
}


def patch_weapon_data() -> None:
    path = ROOT / "assets/nightreign/data/weapon_archetypes.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["revision"] = "M1.5-dedicated-weapon-icons"
    payload["note"] = (
        "Turn-based adaptation metadata. Weapon behavior and dedicated ItemTiles visuals are both "
        "data-driven. Greatswords sweep, daggers burst, thrusting swords reach two cells through "
        "one clear tile, and staff/seal catalysts expose explicit ranged casts."
    )
    payload["sprites"] = SPRITES
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def patch_night_run() -> None:
    path = ROOT / "src/nightreign/expedition/night_run.gd"
    text = path.read_text(encoding="utf-8")
    if "func weapon_sprite_name(id: String) -> StringName:" not in text:
        marker = '''func weapon_archetype(id: String) -> Dictionary:\n\tvar archetype_id := weapon_archetype_id(id)\n\tassert(weapon_profiles.archetypes.has(archetype_id), "Unknown weapon archetype: %s" % archetype_id)\n\treturn weapon_profiles.archetypes[archetype_id]\n'''
        replacement = marker + '''\nfunc weapon_sprite_name(id: String) -> StringName:\n\tassert(weapon_profiles.sprites.has(id), "Missing weapon sprite mapping: %s" % id)\n\treturn StringName(String(weapon_profiles.sprites[id]))\n'''
        if marker not in text:
            raise RuntimeError("NightRun archetype insertion marker drifted")
        text = text.replace(marker, replacement, 1)

    old = '''\t# Reuse a verified upstream sword icon until the item-art pass replaces icons by archetype.\n\titem.sprite_name = ItemFactory.create_item(&"longsword").sprite_name\n'''
    new = '''\titem.sprite_name = weapon_sprite_name(id)\n'''
    if old in text:
        text = text.replace(old, new, 1)
    elif new not in text:
        raise RuntimeError("NightRun weapon sprite assignment marker drifted")
    path.write_text(text, encoding="utf-8")


def patch_weapon_qa() -> None:
    path = ROOT / "tests/weapon_archetypes.gd"
    text = path.read_text(encoding="utf-8")
    if '"sprite": "night-longsword"' not in text:
        replacements = {
            '"longsword": {"archetype": "straight_sword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "single", "casts": false}': '"longsword": {"archetype": "straight_sword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "single", "casts": false, "sprite": "night-longsword"}',
            '"greatsword": {"archetype": "greatsword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "sweep", "casts": false}': '"greatsword": {"archetype": "greatsword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "sweep", "casts": false, "sprite": "night-greatsword"}',
            '"uchigatana": {"archetype": "katana", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "single", "casts": false}': '"uchigatana": {"archetype": "katana", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "single", "casts": false, "sprite": "night-katana"}',
            '"rapier": {"archetype": "thrusting_sword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.PIERCE, "pattern": "thrust", "casts": false}': '"rapier": {"archetype": "thrusting_sword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.PIERCE, "pattern": "thrust", "casts": false, "sprite": "night-rapier"}',
            '"misericorde": {"archetype": "dagger", "item": Item.Type.KNIFE, "skill": Skills.Type.KNIFE, "damage": Damage.Type.PIERCE, "pattern": "burst", "casts": false}': '"misericorde": {"archetype": "dagger", "item": Item.Type.KNIFE, "skill": Skills.Type.KNIFE, "damage": Damage.Type.PIERCE, "pattern": "burst", "casts": false, "sprite": "night-dagger"}',
            '"glintstone_staff": {"archetype": "staff", "item": Item.Type.WAND, "skill": Skills.Type.UTILITY, "damage": Damage.Type.BLUNT, "pattern": "single", "casts": true}': '"glintstone_staff": {"archetype": "staff", "item": Item.Type.WAND, "skill": Skills.Type.UTILITY, "damage": Damage.Type.BLUNT, "pattern": "single", "casts": true, "sprite": "night-staff"}',
            '"finger_seal": {"archetype": "seal", "item": Item.Type.WAND, "skill": Skills.Type.UTILITY, "damage": Damage.Type.BLUNT, "pattern": "single", "casts": true}': '"finger_seal": {"archetype": "seal", "item": Item.Type.WAND, "skill": Skills.Type.UTILITY, "damage": Damage.Type.BLUNT, "pattern": "single", "casts": true, "sprite": "night-seal"}',
            '"sacred_blade": {"archetype": "straight_sword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "single", "casts": false}': '"sacred_blade": {"archetype": "straight_sword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "single", "casts": false, "sprite": "night-sacred-blade"}',
        }
        for old, new in replacements.items():
            if old not in text:
                raise RuntimeError(f"Weapon QA case marker drifted: {old[:40]}")
            text = text.replace(old, new, 1)

    if "var seen_sprite_coords: Dictionary = {}" not in text:
        old = '''\tvar map := _sandbox()\n\tfor weapon_id: String in cases:\n'''
        new = '''\tvar map := _sandbox()\n\tvar seen_sprite_coords: Dictionary = {}\n\tfor weapon_id: String in cases:\n'''
        if old not in text:
            raise RuntimeError("Weapon QA loop marker drifted")
        text = text.replace(old, new, 1)

    if '"dedicated sprite identity " + weapon_id' not in text:
        old = '''\t\tcheck(profile.has("cast") == expected.casts, "cast capability " + weapon_id)\n\t\tcheck(weapon.is_weapon(), "recognized as weapon " + weapon_id)\n'''
        new = '''\t\tcheck(profile.has("cast") == expected.casts, "cast capability " + weapon_id)\n\t\tcheck(weapon.sprite_name == StringName(expected.sprite), "dedicated sprite identity " + weapon_id)\n\t\tvar sprite_coords := ItemTiles.get_coords(weapon.sprite_name)\n\t\tcheck(sprite_coords != Utils.INVALID_POS, "sprite exists in shared ItemTiles atlas " + weapon_id)\n\t\tcheck(not seen_sprite_coords.has(sprite_coords), "weapon sprite coordinate is unique " + weapon_id)\n\t\tseen_sprite_coords[sprite_coords] = weapon_id\n\t\tcheck(weapon.is_weapon(), "recognized as weapon " + weapon_id)\n'''
        if old not in text:
            raise RuntimeError("Weapon QA sprite assertion marker drifted")
        text = text.replace(old, new, 1)

    if '"all Nightreign weapons have unique atlas cells"' not in text:
        old = '''\t\tcheck(NightRun.weapon_description(weapon).contains("Archetype:"), "description exposes archetype " + weapon_id)\n\n\tvar greatsword := NightRun.make_weapon("greatsword")\n'''
        new = '''\t\tcheck(NightRun.weapon_description(weapon).contains("Archetype:"), "description exposes archetype " + weapon_id)\n\n\tcheck(seen_sprite_coords.size() == cases.size(), "all Nightreign weapons have unique atlas cells")\n\n\tvar greatsword := NightRun.make_weapon("greatsword")\n'''
        if old not in text:
            raise RuntimeError("Weapon QA post-loop marker drifted")
        text = text.replace(old, new, 1)
    path.write_text(text, encoding="utf-8")


def patch_gen_items() -> None:
    path = ROOT / "art/gen_items.py"
    text = path.read_text(encoding="utf-8")
    if "from nightreign_weapon_icons import materialize_weapon_icons" not in text:
        marker = "import csv\n"
        if marker not in text:
            raise RuntimeError("gen_items import marker drifted")
        text = text.replace(marker, marker + "from nightreign_weapon_icons import materialize_weapon_icons\n", 1)
    if "materialize_weapon_icons(atlas_path, json_path" not in text:
        marker = '''    with open(json_path, 'w') as f:\n        json.dump(json_data, f, indent=2)\n\n    print(f"Created atlas at {atlas_path}")\n'''
        replacement = '''    with open(json_path, 'w') as f:\n        json.dump(json_data, f, indent=2)\n\n    # Nightreign weapon visuals live in the same authoritative ItemTiles atlas.\n    materialize_weapon_icons(atlas_path, json_path, OUTPUT_DIR / "item_sprites.tres")\n\n    print(f"Created atlas at {atlas_path}")\n'''
        if marker not in text:
            raise RuntimeError("gen_items materializer marker drifted")
        text = text.replace(marker, replacement, 1)
    path.write_text(text, encoding="utf-8")


def patch_m1_workflow() -> None:
    path = ROOT / ".github/workflows/m1-weapon-qa.yml"
    text = path.read_text(encoding="utf-8")
    extra_paths = '''      - art/nightreign_weapon_icons.py\n      - art/gen_items.py\n      - assets/generated/item_sprites.json\n      - assets/generated/item_sprites.png\n      - assets/generated/item_sprites.tres\n'''
    anchor = "      - assets/nightreign/data/weapon_archetypes.json\n"
    if text.count("      - art/nightreign_weapon_icons.py") < 2:
        if text.count(anchor) != 2:
            raise RuntimeError("M1 workflow path marker drifted")
        text = text.replace(anchor, anchor + extra_paths)
    text = text.replace("assert report.get('checks', 0) >= 95", "assert report.get('checks', 0) >= 145")
    path.write_text(text, encoding="utf-8")


def main() -> None:
    patch_weapon_data()
    patch_night_run()
    patch_weapon_qa()
    patch_gen_items()
    patch_m1_workflow()
    print("M1.5 weapon visual source contract patched")


if __name__ == "__main__":
    main()
