from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str, marker: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text:
        print(f"already patched: {path.relative_to(ROOT)} [{marker}]")
        return
    count = text.count(old)
    if count != 1:
        raise RuntimeError(
            f"expected exactly one source block for {marker} in {path.relative_to(ROOT)}, found {count}"
        )
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    print(f"patched: {path.relative_to(ROOT)} [{marker}]")


def patch_night_run() -> None:
    path = ROOT / "src" / "nightreign" / "expedition" / "night_run.gd"
    replace_once(
        path,
        'var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/nightreign/data/expedition.json"))\nvar cooldown: int = 0',
        'var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/nightreign/data/expedition.json"))\nvar weapon_profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/nightreign/data/weapon_archetypes.json"))\nvar cooldown: int = 0',
        "load weapon archetype data",
    )

    old_make_weapon = '''func make_weapon(id: String) -> Item:\n\tvar entry: Dictionary = data.weapons[id]\n\tvar item := Item.new(true)\n\titem.set_meta("night_weapon", id)\n\titem.name = entry.name\n\titem.type = Item.Type.SWORD\n\titem.skill_type = Skills.Type.SWORD\n\titem.damage = [1, int(entry.base)]\n\titem.damage_types = [Damage.Type.SLASH]\n\t# Reuse a verified upstream sword icon until the art pass replaces item icons.\n\titem.sprite_name = ItemFactory.create_item(&"longsword").sprite_name\n\titem._mass = 0.0\n\treturn item\n'''
    new_make_weapon = '''func weapon_archetype_id(id: String) -> String:\n\tassert(data.weapons.has(id), "Unknown Nightreign weapon: %s" % id)\n\tassert(weapon_profiles.weapons.has(id), "Missing weapon archetype mapping: %s" % id)\n\treturn String(weapon_profiles.weapons[id])\n\nfunc weapon_archetype(id: String) -> Dictionary:\n\tvar archetype_id := weapon_archetype_id(id)\n\tassert(weapon_profiles.archetypes.has(archetype_id), "Unknown weapon archetype: %s" % archetype_id)\n\treturn weapon_profiles.archetypes[archetype_id]\n\nfunc _item_type_from_name(type_name: String) -> int:\n\tmatch type_name:\n\t\t"SWORD": return Item.Type.SWORD\n\t\t"KNIFE": return Item.Type.KNIFE\n\t\t"WAND": return Item.Type.WAND\n\tpush_error("Unsupported Nightreign item type: %s" % type_name)\n\treturn Item.Type.MELEE\n\nfunc _skill_type_from_name(type_name: String) -> int:\n\tmatch type_name:\n\t\t"SWORD": return Skills.Type.SWORD\n\t\t"KNIFE": return Skills.Type.KNIFE\n\t\t"UTILITY": return Skills.Type.UTILITY\n\tpush_error("Unsupported Nightreign skill type: %s" % type_name)\n\treturn Skills.Type.NONE\n\nfunc _damage_type_from_name(type_name: String) -> int:\n\tmatch type_name:\n\t\t"SLASH": return Damage.Type.SLASH\n\t\t"PIERCE": return Damage.Type.PIERCE\n\t\t"BLUNT": return Damage.Type.BLUNT\n\tpush_error("Unsupported Nightreign damage type: %s" % type_name)\n\treturn Damage.Type.BLUNT\n\nfunc make_weapon(id: String) -> Item:\n\tvar entry: Dictionary = data.weapons[id]\n\tvar archetype_id := weapon_archetype_id(id)\n\tvar archetype: Dictionary = weapon_archetype(id)\n\tvar item := Item.new(true)\n\titem.set_meta("night_weapon", id)\n\titem.set_meta("night_archetype", archetype_id)\n\titem.set_meta("night_affinity", String(entry.affinity))\n\titem.name = entry.name\n\titem.type = _item_type_from_name(String(archetype.item_type))\n\titem.skill_type = _skill_type_from_name(String(archetype.skill_type))\n\titem.damage = [1, int(entry.base)]\n\titem.damage_types = [_damage_type_from_name(String(archetype.damage_type))]\n\t# Reuse a verified upstream sword icon until the item-art pass replaces icons by archetype.\n\titem.sprite_name = ItemFactory.create_item(&"longsword").sprite_name\n\titem._mass = 0.0\n\treturn item\n'''
    replace_once(path, old_make_weapon, new_make_weapon, "data-driven weapon construction")

    old_damage_tail = '''\treturn roundi(total) + item.enhancement\n\nfunc weapon_description(item: Item) -> String:\n'''
    new_damage_tail = '''\treturn roundi(total) + item.enhancement\n\nfunc weapon_damage_type(item: Item) -> int:\n\tif item == null or not item.has_meta("night_weapon"):\n\t\treturn Damage.Type.BLUNT\n\tvar profile: Dictionary = weapon_archetype(String(item.get_meta("night_weapon")))\n\treturn _damage_type_from_name(String(profile.damage_type))\n\nfunc weapon_description(item: Item) -> String:\n'''
    replace_once(path, old_damage_tail, new_damage_tail, "weapon damage profile helper")

    old_description = '''\treturn "Scaling: %s\\nAffinity: %s\\nYour attack: %d\\nNo stat requirement." % [", ".join(parts), entry.affinity, weapon_damage(item)]\n'''
    new_description = '''\tvar profile: Dictionary = weapon_archetype(String(item.get_meta("night_weapon")))\n\treturn "Archetype: %s\\nScaling: %s\\nAffinity: %s\\nYour attack: %d\\nNo stat requirement." % [profile.label, ", ".join(parts), entry.affinity, weapon_damage(item)]\n'''
    replace_once(path, old_description, new_description, "weapon description archetype")

    replace_once(
        path,
        '''func resolve_melee(attacker: Monster, defender: Monster) -> Combat.MeleeAttackResult:\n\tvar result := Combat.MeleeAttackResult.new()\n\tvar amount := 4\n\tif attacker == World.player:\n\t\tvar weapon := attacker.equipment.get_equipped_item(Equipment.Slot.MELEE)\n\t\tamount = weapon_damage(weapon)\n''',
        '''func resolve_melee(attacker: Monster, defender: Monster) -> Combat.MeleeAttackResult:\n\tvar result := Combat.MeleeAttackResult.new()\n\tvar amount := 4\n\tvar resolved_damage_type := Damage.Type.SLASH\n\tif attacker == World.player:\n\t\tvar weapon := attacker.equipment.get_equipped_item(Equipment.Slot.MELEE)\n\t\tamount = weapon_damage(weapon)\n\t\tresolved_damage_type = weapon_damage_type(weapon)\n''',
        "deterministic melee damage type",
    )
    replace_once(
        path,
        '\tresult.damage_type = Damage.Type.SLASH\n\tresult.killed = result.damage >= defender.hp',
        '\tresult.damage_type = resolved_damage_type\n\tresult.killed = result.damage >= defender.hp',
        "resolved melee damage type",
    )


def patch_melee_action() -> None:
    path = ROOT / "src" / "actions" / "melee_action.gd"
    replace_once(
        path,
        '''\t# Resolve combat\n\tvar combat_result := Combat.resolve_melee_attack(actor, target_monster)\n''',
        '''\t# The Nightreign adaptation uses deterministic damage for the player, expedition enemies,\n\t# and Revenant family summons. Unrelated upstream actors keep the original resolver.\n\tvar uses_nightreign_rules := actor == World.player or actor.has_meta("night_enemy") or actor.has_meta("family")\n\tvar combat_result := (\n\t\tNightRun.resolve_melee(actor, target_monster)\n\t\tif uses_nightreign_rules\n\t\telse Combat.resolve_melee_attack(actor, target_monster)\n\t)\n''',
        "wire deterministic Nightreign melee",
    )
    replace_once(
        path,
        '''\t\tif target_monster != World.player:\n\t\t\ttarget_monster.drop_everything()\n\t\t\tmap.find_and_remove_monster(target_monster)\n''',
        '''\t\tif target_monster != World.player:\n\t\t\tif target_monster.has_meta("night_enemy"):\n\t\t\t\tNightRun.on_killed(target_monster)\n\t\t\ttarget_monster.drop_everything()\n\t\t\tmap.find_and_remove_monster(target_monster)\n''',
        "award Nightreign melee kills",
    )


def patch_item() -> None:
    path = ROOT / "src" / "item.gd"
    replace_once(
        path,
        '''\t\t\tType.HAMMER,\n\t\t\tType.MELEE,\n\t\t\tType.THROWABLE,\n''',
        '''\t\t\tType.HAMMER,\n\t\t\tType.MELEE,\n\t\t\tType.WAND,\n\t\t\tType.THROWABLE,\n''',
        "treat catalysts as weapons",
    )


def main() -> None:
    patch_night_run()
    patch_melee_action()
    patch_item()


if __name__ == "__main__":
    main()
