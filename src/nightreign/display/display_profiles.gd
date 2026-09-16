extends Node
## Display changes never write to World or gameplay resources.
enum Profile { DESKTOP_STANDARD, DESKTOP_PET, MOBILE_FUTURE }
const LOGICAL_SIZE := Vector2i(576, 324)
var current_profile: Profile = Profile.DESKTOP_STANDARD

func _ready() -> void:
	apply_profile(Profile.DESKTOP_PET if "--pet" in OS.get_cmdline_user_args() else Profile.DESKTOP_STANDARD)
	get_window().size_changed.connect(_keep_aspect)

func apply_profile(profile: Profile) -> void:
	current_profile = profile
	var window := get_window()
	window.content_scale_size = LOGICAL_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_factor = 1.0
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	window.min_size = LOGICAL_SIZE
	window.unresizable = profile == Profile.DESKTOP_PET
	if profile != Profile.MOBILE_FUTURE:
		window.size = LOGICAL_SIZE * (1 if profile == Profile.DESKTOP_PET else 2)

func _keep_aspect() -> void:
	if current_profile == Profile.DESKTOP_STANDARD:
		var window := get_window()
		var unit := maxi(36, roundi(window.size.x / 16.0))
		var target := Vector2i(unit * 16, unit * 9)
		if window.size != target:
			window.size = target

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("display_profile"):
		apply_profile(Profile.DESKTOP_STANDARD if current_profile == Profile.DESKTOP_PET else Profile.DESKTOP_PET)
		get_viewport().set_input_as_handled()
