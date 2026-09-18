class_name NightUiFont
extends RefCounted

const PRIMARY_FONT_PATH := "res://assets/fonts/pixel_operator/PixelOperator.ttf"
const CJK_FONT_PATH := "res://assets/fonts/nightreign_ui_tc/NightreignUITC-Regular.ttf"

static var _cached: FontVariation


static func bundled_cjk_font() -> Font:
	return load(CJK_FONT_PATH) as Font


static func hud_font() -> FontVariation:
	if _cached != null:
		return _cached

	var primary := load(PRIMARY_FONT_PATH) as Font
	var cjk := bundled_cjk_font()
	var variation := FontVariation.new()
	variation.base_font = primary

	var fallbacks: Array[Font] = []
	if cjk != null:
		fallbacks.append(cjk)
	else:
		push_error("Bundled Traditional Chinese HUD font is missing: %s" % CJK_FONT_PATH)
	variation.fallbacks = fallbacks
	_cached = variation
	return _cached
