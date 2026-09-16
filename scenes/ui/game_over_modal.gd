class_name GameOverModal
extends Modal

@onready var stats_label: Label = %StatsLabel
@onready var level_label: Label = %LevelLabel
@onready var retry_button: Button = %RetryButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()
	_on_game_ended()
	get_node("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/GameOverLabel").text = "NIGHTLORD FELLED" if NightRun.won else "EXPEDITION ENDED"
	retry_button.grab_focus()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__nightreignGameOverQA = { visible: true };" )


func _exit_tree() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__nightreignGameOverQA = { visible: false };" )


func _unhandled_input(event: InputEvent) -> void:
	# A game-over screen must never close back onto a dead, input-locked run.
	if event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		_on_retry_button_pressed()
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_on_main_menu_button_pressed()


func _on_overlay_clicked(_event: InputEvent) -> void:
	# Intentionally ignore outside clicks. Closing this modal without changing
	# scenes strands the player in World.game_over with all gameplay input locked.
	pass


func _on_game_ended() -> void:
	stats_label.text = (
		"""
	Final Stats:
	HP: %d / %d
	"""
		% [World.player.hp, World.player.max_hp]
	)
	level_label.text = "You made it to depth %d!" % World.max_depth


func _change_scene(path: String) -> void:
	get_tree().paused = false
	Modals.close_all_modals()
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Failed to leave game-over screen for %s (error %s)" % [path, error])


func _on_retry_button_pressed() -> void:
	_change_scene("res://scenes/game/game.tscn")


func _on_main_menu_button_pressed() -> void:
	_change_scene("res://scenes/menu/main_menu.tscn")
