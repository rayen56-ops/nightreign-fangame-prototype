from pathlib import Path

p = Path("scenes/game/game.gd")
text = p.read_text(encoding="utf-8")

if "func _unhandled_input(event: InputEvent) -> void:" in text:
    text = text.replace(
        "func _unhandled_input(event: InputEvent) -> void:",
        "func _input(event: InputEvent) -> void:",
        1,
    )
assert "func _input(event: InputEvent) -> void:" in text

modal = "\tif Modals.has_visible_modals():\n"
echo_guard = "\tif event is InputEventKey and event.echo:\n\t\treturn\n\n"
if echo_guard not in text:
    assert modal in text
    text = text.replace(modal, echo_guard + modal, 1)

if "var action := await _check_player_input()" in text:
    text = text.replace(
        "var action := await _check_player_input()",
        "var action := await _check_player_input(event)",
        1,
    )

old_sig = "func _check_player_input() -> BaseAction:"
new_sig = "func _check_player_input(event: InputEvent) -> BaseAction:"
if old_sig in text:
    start = text.index(old_sig)
    end = text.index("\n\nfunc _handle_player_action(", start)
    region = text[start:end].replace(old_sig, new_sig, 1)
    region = region.replace("Input.is_action_just_pressed(", "event.is_action_pressed(")
    text = text[:start] + region + text[end:]
assert new_sig in text

if '_publish_web_qa("ready")' not in text:
    anchor = "\t# Update actors\n\t_update_actors()\n\n\nfunc _process"
    assert anchor in text
    text = text.replace(
        anchor,
        "\t# Update actors\n\t_update_actors()\n\t_publish_web_qa(\"ready\")\n\n\nfunc _process",
        1,
    )

if "func _publish_web_qa(" not in text:
    anchor = "\t# Ready for next input\n\twaiting_for_player_input = true\n\n\nfunc _update_actors() -> void:"
    assert anchor in text
    telemetry = """\t# Ready for next input
\twaiting_for_player_input = true
\t_publish_web_qa("action")


func _publish_web_qa(last_action: String = "") -> void:
\tif not OS.has_feature("web") or not World.current_map or not World.player:
\t\treturn
\tvar pos := World.current_map.find_monster_position(World.player)
\tif pos == Utils.INVALID_POS:
\t\treturn
\tvar walkable: Array[String] = []
\tvar directions := {
\t\t"w": Vector2i.UP,
\t\t"d": Vector2i.RIGHT,
\t\t"s": Vector2i.DOWN,
\t\t"a": Vector2i.LEFT,
\t\t"q": Vector2i.UP + Vector2i.LEFT,
\t\t"e": Vector2i.UP + Vector2i.RIGHT,
\t\t"z": Vector2i.DOWN + Vector2i.LEFT,
\t\t"c": Vector2i.DOWN + Vector2i.RIGHT,
\t}
\tfor key: String in directions:
\t\tvar delta: Vector2i = directions[key]
\t\tvar target := pos + delta
\t\tif not World.current_map.is_in_bounds(target):
\t\t\tcontinue
\t\tvar cell := World.current_map.get_cell(target)
\t\tif cell.is_walkable() and World.current_map.get_monster(target) == null:
\t\t\twalkable.append(key)
\tvar player_actor := get_tree().get_first_node_in_group("player")
\tvar payload := JSON.stringify({
\t\t"ready": true,
\t\t"turn": World.current_turn,
\t\t"floor": World.current_map.depth,
\t\t"x": pos.x,
\t\t"y": pos.y,
\t\t"waiting_for_input": waiting_for_player_input,
\t\t"last_action": last_action,
\t\t"walkable": walkable,
\t\t"player_actor_visible": player_actor != null and player_actor.visible,
\t})
\tJavaScriptBridge.eval("window.__nightreignQA = %s;" % payload)


func _update_actors() -> void:"""
    text = text.replace(anchor, telemetry, 1)

p.write_text(text, encoding="utf-8")
print("Patched scenes/game/game.gd for robust Web input and browser telemetry")
