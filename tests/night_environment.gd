extends Node

var checks := 0
var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("M2 ENVIRONMENT QA %s: %s" % ["PASS" if value else "FAIL", label])


func terrain_of(type: int) -> Terrain:
	var terrain := Terrain.new()
	terrain.type = type
	return terrain


func obstacle_of(type: int) -> Obstacle:
	var obstacle := Obstacle.new()
	obstacle.type = type
	return obstacle


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	var floor_tile := NightEnvironmentVisuals.FLOOR_TILE

	# Every floor-like terrain gets a visible base tile before semantic decoration.
	for type in [
		Terrain.Type.DUNGEON_FLOOR,
		Terrain.Type.DUNGEON_FLOOR_GRATE,
		Terrain.Type.DUNGEON_HOLE,
		Terrain.Type.DUNGEON_DOOR_OPEN,
		Terrain.Type.DUNGEON_DOOR_CLOSED,
	]:
		check(
			NightEnvironmentVisuals.ground_tile_for(type) == floor_tile,
			"floor-like terrain %s receives a visible base tile" % Terrain.Type.keys()[type]
		)
	check(NightEnvironmentVisuals.ground_tile_for(Terrain.Type.EMPTY) == &"", "empty terrain does not fake a floor")
	check(NightEnvironmentVisuals.ground_tile_for(Terrain.Type.DUNGEON_WALL) == &"", "wall remains wall-renderer owned")
	check(NightEnvironmentVisuals.ground_tile_for(Terrain.Type.DUNGEON_WALL_VENTED) == &"", "vented wall remains wall-renderer owned")

	check(NightEnvironmentVisuals.semantic_kind(terrain_of(Terrain.Type.DUNGEON_FLOOR)) == NightEnvironmentVisuals.KIND_FLOOR, "normal floor has floor semantics")
	check(NightEnvironmentVisuals.semantic_kind(terrain_of(Terrain.Type.DUNGEON_WALL)) == NightEnvironmentVisuals.KIND_WALL, "wall has wall semantics")
	check(NightEnvironmentVisuals.semantic_kind(terrain_of(Terrain.Type.DUNGEON_WALL_VENTED)) == NightEnvironmentVisuals.KIND_WALL, "vented wall shares wall silhouette treatment")
	check(NightEnvironmentVisuals.semantic_kind(terrain_of(Terrain.Type.DUNGEON_FLOOR_GRATE)) == NightEnvironmentVisuals.KIND_GRATE, "grated floor gets grate semantics")
	check(NightEnvironmentVisuals.semantic_kind(terrain_of(Terrain.Type.DUNGEON_HOLE)) == NightEnvironmentVisuals.KIND_HOLE, "hole gets explicit hazard semantics")
	check(NightEnvironmentVisuals.semantic_kind(terrain_of(Terrain.Type.DUNGEON_DOOR_OPEN)) == NightEnvironmentVisuals.KIND_DOOR_OPEN, "open terrain door stays readable")
	check(NightEnvironmentVisuals.semantic_kind(terrain_of(Terrain.Type.DUNGEON_DOOR_CLOSED)) == NightEnvironmentVisuals.KIND_DOOR_CLOSED, "closed terrain door stays readable")

	var ordinary_floor := terrain_of(Terrain.Type.DUNGEON_FLOOR)
	check(NightEnvironmentVisuals.semantic_kind(ordinary_floor, obstacle_of(Obstacle.Type.STAIRS_UP)) == NightEnvironmentVisuals.KIND_GRACE, "stairs up become the expedition Site of Grace marker")
	check(NightEnvironmentVisuals.semantic_kind(ordinary_floor, obstacle_of(Obstacle.Type.STAIRS_DOWN)) == NightEnvironmentVisuals.KIND_DESCENT, "stairs down become an unmistakable descent marker")
	check(NightEnvironmentVisuals.semantic_kind(ordinary_floor, obstacle_of(Obstacle.Type.DOOR_OPEN)) == NightEnvironmentVisuals.KIND_DOOR_OPEN, "open obstacle door overrides floor semantics")
	check(NightEnvironmentVisuals.semantic_kind(ordinary_floor, obstacle_of(Obstacle.Type.DOOR_CLOSED)) == NightEnvironmentVisuals.KIND_DOOR_CLOSED, "closed obstacle door overrides floor semantics")

	check(NightEnvironmentVisuals.interaction_label(NightEnvironmentVisuals.KIND_GRACE) == "賜福", "grace label is concise Traditional Chinese")
	check(NightEnvironmentVisuals.interaction_label(NightEnvironmentVisuals.KIND_DESCENT) == "下一層", "descent label explains progression")
	check(NightEnvironmentVisuals.interaction_label(NightEnvironmentVisuals.KIND_DOOR_OPEN) == "開啟的門", "open door has readable label")
	check(NightEnvironmentVisuals.interaction_label(NightEnvironmentVisuals.KIND_DOOR_CLOSED) == "關閉的門", "closed door has readable label")
	check(NightEnvironmentVisuals.interaction_label(NightEnvironmentVisuals.KIND_GRATE) == "格柵地板", "grate has readable label")
	check(NightEnvironmentVisuals.interaction_label(NightEnvironmentVisuals.KIND_HOLE) == "坑洞", "hole has readable label")

	for kind in [
		NightEnvironmentVisuals.KIND_GRACE,
		NightEnvironmentVisuals.KIND_DESCENT,
		NightEnvironmentVisuals.KIND_DOOR_OPEN,
		NightEnvironmentVisuals.KIND_DOOR_CLOSED,
	]:
		check(NightEnvironmentVisuals.is_high_priority(kind), "%s is a high-priority navigation landmark" % kind)
	check(not NightEnvironmentVisuals.is_high_priority(NightEnvironmentVisuals.KIND_FLOOR), "ordinary floor is not promoted over gameplay")
	check(not NightEnvironmentVisuals.is_high_priority(NightEnvironmentVisuals.KIND_GRATE), "grate remains secondary terrain")
	check(not NightEnvironmentVisuals.is_high_priority(NightEnvironmentVisuals.KIND_HOLE), "hole is readable without pretending to be an interaction target")

	var grace_color := NightEnvironmentVisuals.accent_color(NightEnvironmentVisuals.KIND_GRACE)
	var descent_color := NightEnvironmentVisuals.accent_color(NightEnvironmentVisuals.KIND_DESCENT)
	var door_color := NightEnvironmentVisuals.accent_color(NightEnvironmentVisuals.KIND_DOOR_CLOSED)
	var hole_color := NightEnvironmentVisuals.accent_color(NightEnvironmentVisuals.KIND_HOLE)
	check(grace_color != descent_color, "grace and descent use distinct accents")
	check(grace_color != door_color, "grace does not visually collapse into a door")
	check(descent_color != door_color, "descent does not visually collapse into a door")
	check(hole_color.get_luminance() < grace_color.get_luminance(), "hole reads darker than golden grace")

	var renderer := MapRenderer.new()
	renderer.initialize_tile_layers()
	check(renderer.night_environment_layer != null, "MapRenderer owns the Nightreign semantic environment layer")
	check(renderer.night_environment_layer is NightEnvironmentOverlay, "semantic environment layer uses the dedicated overlay")
	check(renderer.obstacle_layer.get_index() < renderer.night_environment_layer.get_index(), "semantic layer sits above inherited obstacle sprites")
	check(renderer.night_environment_layer.get_index() < renderer.item_layer.get_index(), "items remain above semantic terrain markers")
	check(renderer.is_wall_like(terrain_of(Terrain.Type.DUNGEON_WALL)), "ordinary wall participates in wall topology")
	check(renderer.is_wall_like(terrain_of(Terrain.Type.DUNGEON_WALL_VENTED)), "vented wall now participates in wall topology")
	renderer.free()

	var report := {
		"checks": checks,
		"failures": failures,
		"landmarks": ["grace", "descent", "door_open", "door_closed"],
		"secondary_terrain": ["grate", "hole"],
		"layer_contract": "terrain/decor -> obstacle -> night_environment -> items -> vision",
	}
	FileAccess.open("res://docs/M2_ENVIRONMENT_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M2 ENVIRONMENT QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
