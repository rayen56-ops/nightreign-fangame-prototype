extends Control

# Browser QA can enter gameplay without guessing canvas coordinates.
# A normal Web/desktop launch still shows this menu.
func _ready() -> void:
	if not OS.has_feature("web"):
		return
	var search := String(JavaScriptBridge.eval("window.location.search || ''"))
	var qa_autostart := search.find("qa=1") >= 0
	print("NIGHTREIGN_QA_MENU search=%s autostart=%s" % [search, qa_autostart])
	JavaScriptBridge.eval("window.__nightreignMenuQA = { ready: true, qa: %s, search: %s };" % [str(qa_autostart).to_lower(), JSON.stringify(search)])
	if qa_autostart:
		set_meta("nightreign_qa_autostart", true)
		call_deferred("_on_play_button_pressed")

func _start_character(id: String) -> void:
	CharacterCatalog.select_character(id)
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _on_play_button_pressed() -> void:
	_start_character("wylder")

func _on_revenant_button_pressed() -> void:
	_start_character("revenant")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
