class_name NightControllerDriver
extends Node

var _left_axes := Vector2.ZERO
var _stick_armed := true


func _game() -> Node:
	var overlay := get_parent()
	return overlay.get_parent() if overlay != null else null


func _can_accept_gameplay_input(game: Node) -> bool:
	if game == null or World.game_over or Modals.has_visible_modals():
		return false
	return bool(game.get("waiting_for_player_input"))


func _submit_action(game: Node, action: BaseAction) -> void:
	if game == null or action == null:
		return
	get_viewport().set_input_as_handled()
	game.set("waiting_for_player_input", false)
	game.call("_handle_player_action", action)


func _context_action() -> BaseAction:
	var map := World.current_map
	if map == null or World.player == null:
		return null
	var pos := map.find_monster_position(World.player)
	if pos == Utils.INVALID_POS:
		return null
	var obstacle := map.get_obstacle(pos)
	if obstacle != null:
		if obstacle.type == Obstacle.Type.STAIRS_DOWN:
			return PlayerMoveDownstairsAction.new()
		if obstacle.type == Obstacle.Type.STAIRS_UP:
			return PlayerMoveUpstairsAction.new()
	var items := map.get_items(pos)
	if items.is_empty():
		return null
	var selections: Array[ItemSelection] = []
	for item: Item in items:
		selections.append(ItemSelection.new(item, item.quantity))
	return PlayerPickupAction.new(selections)


func _ability_action(kind: String) -> BaseAction:
	if kind == "flask" or kind == "grace":
		return NightAbilityAction.new(kind)
	if CharacterCatalog.selected_id == "revenant":
		return NightAbilityAction.new(kind)
	var direction := NightRun.facing.sign()
	if direction == Vector2i.ZERO:
		direction = Vector2i.UP
	return NightAbilityAction.new(kind, direction)


func _cast_action() -> BaseAction:
	var target := NightControllerInput.facing_cast_target(World.current_map, World.player, NightRun.facing)
	if target == Utils.INVALID_POS:
		return null
	return PlayerFireAction.new(target)


func _handle_command(game: Node, command: StringName) -> void:
	var direction := NightControllerInput.command_direction(command)
	if direction != Vector2i.ZERO:
		_submit_action(game, PlayerAttackMoveAction.new(direction))
		return
	match command:
		&"interact":
			_submit_action(game, _context_action())
		&"skill":
			_submit_action(game, _ability_action("skill"))
		&"ultimate":
			_submit_action(game, _ability_action("ultimate"))
		&"flask":
			_submit_action(game, _ability_action("flask"))
		&"cast":
			_submit_action(game, _cast_action())
		&"wait":
			_submit_action(game, PlayerRestAction.new())
		&"grace":
			_submit_action(game, _ability_action("grace"))
		&"inventory":
			get_viewport().set_input_as_handled()
			Modals.toggle_inventory(InventoryModal.Tab.INVENTORY)
		&"equipment":
			get_viewport().set_input_as_handled()
			Modals.toggle_inventory(InventoryModal.Tab.EQUIPMENT)


func _handle_stick_motion(game: Node, event: InputEventJoypadMotion) -> void:
	if event.axis == JOY_AXIS_LEFT_X:
		_left_axes.x = event.axis_value
	elif event.axis == JOY_AXIS_LEFT_Y:
		_left_axes.y = event.axis_value
	else:
		return
	if NightControllerInput.is_neutral(_left_axes):
		_stick_armed = true
		return
	if not _stick_armed:
		return
	var direction := NightControllerInput.axis_direction(_left_axes)
	if direction == Vector2i.ZERO:
		return
	_stick_armed = false
	_submit_action(game, PlayerAttackMoveAction.new(direction))


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	var game := _game()
	if not _can_accept_gameplay_input(game):
		return
	if event is InputEventJoypadMotion:
		_handle_stick_motion(game, event as InputEventJoypadMotion)
		return
	var button := event as InputEventJoypadButton
	if not button.pressed:
		return
	var command := NightControllerInput.button_command(button.button_index)
	if command != &"":
		_handle_command(game, command)
