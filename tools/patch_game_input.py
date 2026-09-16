from pathlib import Path

p = Path("scenes/game/game.gd")
text = p.read_text(encoding="utf-8")

# Publish a marker before any game initialization so browser QA can distinguish
# scene-entry failures from later world/actor failures.
ready_sig = "func _ready() -> void:\n"
ready_marker = (
    "func _ready() -> void:\n"
    "\tif OS.has_feature(\"web\"):\n"
    "\t\tJavaScriptBridge.eval(\"window.__nightreignQA = { ready: false, stage: 'game_ready_entered' };\")\n"
    "\t\tprint(\"NIGHTREIGN_QA_STAGE game_ready_entered\")\n"
)
if "NIGHTREIGN_QA_STAGE game_ready_entered" not in text:
    assert ready_sig in text
    text = text.replace(ready_sig, ready_marker, 1)

# Gameplay input must be read before GUI controls can swallow keyboard events.
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

# Make initialization progress observable from the browser. These markers are QA
# only and have no gameplay effect.
world_anchor = "\t# Initialize the world\n\tWorld.initialize()\n\n\t# Update actors\n"
world_staged = (
    "\t# Initialize the world\n"
    "\tWorld.initialize()\n"
    "\tif OS.has_feature(\"web\"):\n"
    "\t\tJavaScriptBridge.eval(\"window.__nightreignQA = { ready: false, stage: 'world_initialized' };\")\n"
    "\t\tprint(\"NIGHTREIGN_QA_STAGE world_initialized\")\n\n"
    "\t# Update actors\n"
)
if "NIGHTREIGN_QA_STAGE world_initialized" not in text:
    assert world_anchor in text
    text = text.replace(world_anchor, world_staged, 1)

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
\tif not OS.has_feature("web"):
\t\treturn
\tvar payload: Dictionary = {
\t\t"ready": false,
\t\t"stage": "telemetry_entered",
\t\t"last_action": last_action,
\t\t"turn": World.current_turn,
\t\t"has_map": World.current_map != null,
\t\t"has_player": World.player != null,
\t\t"walkable": [],
\t\t"player_actor_visible": false,
\t}
\tif not World.current_map:
\t\tpayload["stage"] = "missing_map"
\t\tJavaScriptBridge.eval("window.__nightreignQA = %s;" % JSON.stringify(payload))
\t\tprint("NIGHTREIGN_QA_STAGE missing_map")
\t\treturn
\tif not World.player:
\t\tpayload["stage"] = "missing_player"
\t\tJavaScriptBridge.eval("window.__nightreignQA = %s;" % JSON.stringify(payload))
\t\tprint("NIGHTREIGN_QA_STAGE missing_player")
\t\treturn
\tvar pos := World.current_map.find_monster_position(World.player)
\tif pos == Utils.INVALID_POS:
\t\tpayload["stage"] = "player_not_on_map"
\t\tJavaScriptBridge.eval("window.__nightreignQA = %s;" % JSON.stringify(payload))
\t\tprint("NIGHTREIGN_QA_STAGE player_not_on_map")
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
\tpayload["ready"] = true
\tpayload["stage"] = "ready"
\tpayload["floor"] = World.current_map.depth
\tpayload["x"] = pos.x
\tpayload["y"] = pos.y
\tpayload["waiting_for_input"] = waiting_for_player_input
\tpayload["walkable"] = walkable
\tpayload["player_actor_visible"] = player_actor != null and player_actor.visible
\tJavaScriptBridge.eval("window.__nightreignQA = %s;" % JSON.stringify(payload))
\tprint("NIGHTREIGN_QA_STAGE ready pos=%s walkable=%s visible=%s" % [pos, walkable, payload["player_actor_visible"]])


func _update_actors() -> void:"""
    text = text.replace(anchor, telemetry, 1)

p.write_text(text, encoding="utf-8")
print("Patched scenes/game/game.gd for robust Web input and staged browser telemetry")
