#!/usr/bin/env python3
from pathlib import Path


def main() -> None:
    # Restore the ActorAction/BaseAction API accidentally replaced in AttackMoveAction.
    Path("src/actions/attack_move_action.gd").write_text(
        """class_name AttackMoveAction
extends ActorAction

var direction: Vector2i


func _init(p_actor: Monster, dir: Vector2i) -> void:
\tsuper(p_actor)
\tdirection = dir


func _execute(map: Map, result: ActionResult) -> bool:
\tif not super(map, result):
\t\treturn false

\tvar current_pos := map.find_monster_position(actor)
\tif current_pos == Utils.INVALID_POS:
\t\tpush_error(\"AttackMoveAction actor is not present on the current map: %s\" % actor)
\t\treturn false

\tif actor.has_status_effect(StatusEffect.Type.CONFUSED):
\t\tdirection = Utils.ALL_DIRECTIONS.pick_random()

\tif actor.has_status_effect(StatusEffect.Type.PARALYZED):
\t\tif actor == World.player:
\t\t\tresult.message = \"You are paralyzed!\"
\t\t\tresult.message_level = LogMessages.Level.TERRIBLE
\t\telse:
\t\t\tresult.message = \"%s tries to move but is paralyzed!\" % actor.name
\t\t\tresult.message_level = LogMessages.Level.BAD
\t\treturn true

\tif actor == World.player:
\t\tNightRun.facing = direction

\tvar new_pos := current_pos + direction
\tif not map.is_in_bounds(new_pos):
\t\treturn false

\tvar target := map.get_monster(new_pos)
\tif target and target.has_meta(\"family\"):
\t\tresult.message = \"Your family occupies that tile.\"
\t\treturn false

\tif target:
\t\tvar melee := MeleeAction.new(actor, direction)
\t\treturn melee._execute(map, result)

\tvar move := MoveAction.new(actor, direction)
\treturn move._execute(map, result)


func _to_string() -> String:
\treturn \"AttackMoveAction(actor: %s, direction: %s)\" % [actor, direction]
""",
        encoding="utf-8",
    )

    # Vector2i.ZERO is a valid grid coordinate. INVALID_POS is the missing sentinel.
    move_path = Path("src/actions/move_action.gd")
    move = move_path.read_text(encoding="utf-8")
    old_guard = (
        "\tvar current_pos: Vector2i = map.find_monster_position(actor)\n"
        "\tif not current_pos:\n"
        "\t\treturn false"
    )
    new_guard = (
        "\tvar current_pos: Vector2i = map.find_monster_position(actor)\n"
        "\tif current_pos == Utils.INVALID_POS:\n"
        "\t\tpush_error(\"MoveAction actor is not present on the current map: %s\" % actor)\n"
        "\t\treturn false"
    )
    if old_guard in move:
        move = move.replace(old_guard, new_guard, 1)
    assert "if current_pos == Utils.INVALID_POS:" in move

    old_new_pos = (
        "\tvar new_pos: Vector2i = current_pos + direction\n\n"
        "\t# Check if target position is walkable"
    )
    new_new_pos = (
        "\tvar new_pos: Vector2i = current_pos + direction\n"
        "\tif not map.is_in_bounds(new_pos):\n"
        "\t\treturn false\n\n"
        "\t# Check if target position is walkable"
    )
    if new_new_pos not in move:
        assert old_new_pos in move
        move = move.replace(old_new_pos, new_new_pos, 1)
    move_path.write_text(move, encoding="utf-8")

    # Same sentinel/bounds hardening for direct melee actions.
    melee_path = Path("src/actions/melee_action.gd")
    melee = melee_path.read_text(encoding="utf-8")
    melee = melee.replace(
        "\tvar current_pos := map.find_monster_position(actor)\n\tif not current_pos:\n\t\treturn false",
        "\tvar current_pos := map.find_monster_position(actor)\n\tif current_pos == Utils.INVALID_POS:\n\t\treturn false",
        1,
    )
    target_anchor = "\tvar target_pos := current_pos + direction\n\n\t# Handle monster collision"
    target_fixed = (
        "\tvar target_pos := current_pos + direction\n"
        "\tif not map.is_in_bounds(target_pos):\n"
        "\t\treturn false\n\n"
        "\t# Handle monster collision"
    )
    if target_fixed not in melee:
        assert target_anchor in melee
        melee = melee.replace(target_anchor, target_fixed, 1)
    melee_path.write_text(melee, encoding="utf-8")

    # T0 generation contract must guarantee an immediately executable exit from spawn.
    world_path = Path("src/world.gd")
    world = world_path.read_text(encoding="utf-8")
    if "func _has_immediate_player_egress(" not in world:
        route_anchor = "\n\nfunc _has_walkable_route(map: Map, start: Vector2i, goal: Vector2i) -> bool:"
        assert route_anchor in world
        helper = """

func _has_immediate_player_egress(map: Map, spawn: Vector2i) -> bool:
\tif spawn == Utils.INVALID_POS:
\t\treturn false
\tfor direction: Vector2i in Utils.ALL_DIRECTIONS:
\t\tvar target := spawn + direction
\t\tif not map.is_in_bounds(target):
\t\t\tcontinue
\t\tvar cell := map.get_cell(target)
\t\tif cell.is_walkable() and map.get_monster(target) == null:
\t\t\treturn true
\treturn false
"""
        world = world.replace(route_anchor, helper + route_anchor, 1)

    contract_anchor = (
        "\tif plan.down_destination == \"\" and down != Utils.INVALID_POS:\n"
        "\t\treturn false\n"
    )
    contract_check = (
        "\tif up != Utils.INVALID_POS and not _has_immediate_player_egress(map, up):\n"
        "\t\treturn false\n"
    )
    if contract_check not in world:
        assert contract_anchor in world
        world = world.replace(contract_anchor, contract_anchor + contract_check, 1)
    world_path.write_text(world, encoding="utf-8")

    # Normal users still see the menu. Browser QA can enter gameplay using ?qa=1.
    menu_path = Path("scenes/menu/main_menu.gd")
    menu = menu_path.read_text(encoding="utf-8")
    if "nightreign_qa_autostart" not in menu:
        old = (
            "# Uncomment this to test the game immediately after running\n"
            "# func _ready() -> void:\n"
            "# \tcall_deferred(\"_on_play_button_pressed\")\n"
        )
        new = (
            "# Browser QA can enter gameplay without guessing canvas coordinates.\n"
            "# A normal Web/desktop launch still shows this menu.\n"
            "func _ready() -> void:\n"
            "\tif OS.has_feature(\"web\"):\n"
            "\t\tvar search := String(JavaScriptBridge.eval(\"window.location.search\"))\n"
            "\t\tif \"qa=1\" in search:\n"
            "\t\t\tset_meta(\"nightreign_qa_autostart\", true)\n"
            "\t\t\tcall_deferred(\"_on_play_button_pressed\")\n"
        )
        assert old in menu
        menu = menu.replace(old, new, 1)
    menu_path.write_text(menu, encoding="utf-8")

    # Permanent Web gate must use the QA-only entry path.
    preview_path = Path(".github/workflows/web-preview.yml")
    preview = preview_path.read_text(encoding="utf-8")
    preview = preview.replace(
        "http://127.0.0.1:4173/game/'",
        "http://127.0.0.1:4173/game/?qa=1'",
    )
    preview_path.write_text(preview, encoding="utf-8")

    print("T0 core repair applied")


if __name__ == "__main__":
    main()
