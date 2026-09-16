class_name GameOverModal
extends Modal

@onready var stats_label: Label = %StatsLabel
@onready var level_label: Label = %LevelLabel


func _ready() -> void:
	super._ready()
	World.game_ended.connect(_on_game_ended)
	_on_game_ended()
	get_node("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/GameOverLabel").text = "NIGHTLORD FELLED" if NightRun.won else "EXPEDITION ENDED"


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)

	if event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		_on_main_menu_button_pressed()
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_on_quit_button_pressed()


func _on_game_ended() -> void:
	# Display final stats
	stats_label.text = (
		"""
	Final Stats:
	HP: %d / %d
	"""
		% [World.player.hp, World.player.max_hp]
	)

	level_label.text = "You made it to depth %d!" % World.max_depth


func _on_main_menu_button_pressed() -> void:
	Modals.close_all_modals()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()

