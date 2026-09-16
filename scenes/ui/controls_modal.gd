class_name ControlsModal
extends Modal

@onready var close_button: Button = %CloseButton


func _ready() -> void:
	super._ready()
	close_button.grab_focus()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__nightreignControlsQA = { visible: true };" )


func _exit_tree() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__nightreignControlsQA = { visible: false };" )


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		_close_modal()
		return
	super._unhandled_input(event)


func _on_close_button_pressed() -> void:
	_close_modal()
