extends Node


enum Profile { DESKTOP_STANDARD, DESKTOP_PET, MOBILE_FUTURE }

const LOGICAL_SIZE := Vector2i(576, 324)

var current_profile: Profile = Profile.DESKTOP_STANDARD


func _ready() -> void:
	apply_profile(
		Profile.DESKTOP_PET
		if "--pet" in OS.get_cmdline_user_args()
		else Profile.DESKTOP_STANDARD
	)

	# A Web export's physical canvas belongs to the browser/export shell.
	# Rewriting Window.size from Godot creates a resize feedback loop and
	# can leave the logical viewport offset inside the HTML canvas.
	if not OS.has_feature("web"):
		get_window().size_changed.connect(_keep_aspect)


func apply_profile(profile: Profile) -> void:
	current_profile = profile

	var window := get_window()
	window.content_scale_size = LOGICAL_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_factor = 1.0
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER

	# Browser CSS/export policy controls the physical canvas size. We only
	# keep the 576x324 logical game resolution on Web.
	if OS.has_feature("web"):
		return

	window.min_size = LOGICAL_SIZE
	window.unresizable = profile == Profile.DESKTOP_PET

	if profile == Profile.DESKTOP_PET:
		window.size = LOGICAL_SIZE
	elif profile == Profile.DESKTOP_STANDARD:
		window.size = LOGICAL_SIZE * 2


func _keep_aspect() -> void:
	if OS.has_feature("web") or current_profile != Profile.DESKTOP_STANDARD:
		return

	var window := get_window()
	var unit := maxi(36, roundi(window.size.x / 16.0))
	var target := Vector2i(unit * 16, unit * 9)
	if window.size != target:
		window.size = target
