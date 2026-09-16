from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Expected patch target not found in {path}: {old[:120]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


# Keep the original generator's global RNG behavior. World reseeds that global stream
# to a floor+retry seed immediately before constructing each dungeon. Only the private
# RNGs that previously escaped that seed are made explicit.
base = Path("src/map_generators/base_generator.gd")
text = base.read_text(encoding="utf-8")
old = "var debug_splits: Array[Split] = []\n"
new = """var debug_splits: Array[Split] = []\n\n# Seed inherited from DungeonGenerator for the private room-placement RNG.\nvar deterministic_generation_seed: int = 1\n"""
if new not in text:
    if old not in text:
        raise SystemExit("Base generator seed insertion point missing")
    text = text.replace(old, new, 1)

# The staged T0 source intentionally creates this RNG without a seed. Seed only this
# local stream, and leave global randi/randf/shuffle calls unchanged.
old_rng_seeded = "\tvar rng := RandomNumberGenerator.new()\n\trng.seed = randi()\n"
old_rng_plain = "\tvar rng := RandomNumberGenerator.new()\n"
new_rng = """\tvar rng := RandomNumberGenerator.new()\n\t# Independent deterministic room-placement stream.\n\trng.seed = deterministic_generation_seed + 1013904223\n"""
if new_rng not in text:
    if old_rng_seeded in text:
        text = text.replace(old_rng_seeded, new_rng, 1)
    elif old_rng_plain in text:
        text = text.replace(old_rng_plain, new_rng, 1)
    else:
        raise SystemExit("Private room RNG target missing")
base.write_text(text, encoding="utf-8")


dungeon = Path("src/map_generators/dungeon_generator.gd")
old_setup = """\t# Initialize Dice RNG\n\tDice.set_seed()\n\n\tvar depth: int = params.get(\"depth\", 1)\n\tvar attempts := 50\n\tvar map: Map\n\n\twhile attempts > 0:\n\t\tmap = _initialize_empty_map(width, height, depth)\n\t\t_rng = RandomNumberGenerator.new()\n\t\tDice._rng = _rng\n"""
new_setup = """\tvar depth: int = params.get(\"depth\", 1)\n\tvar generation_seed: int = int(params.get(\"generation_seed\", 1))\n\tdeterministic_generation_seed = generation_seed\n\n\tvar attempts := 50\n\tvar map: Map\n\tvar internal_attempt := 0\n\n\twhile attempts > 0:\n\t\tmap = _initialize_empty_map(width, height, depth)\n\t\t# Preserve the original shared Dice/feature RNG, but seed it from the floor.\n\t\t_rng = RandomNumberGenerator.new()\n\t\t_rng.seed = generation_seed + 1664525 + internal_attempt * 69069\n\t\tDice._rng = _rng\n\t\tinternal_attempt += 1\n"""
replace_once(dungeon, old_setup, new_setup)

# Leave rooms.shuffle(), directions.shuffle(), randi() and randf() unchanged. World has
# already seeded Godot's global RNG with the floor+retry seed before generator creation.

# A closed door is an operable obstacle, so it counts as traversable for the T0
# connectivity contract even though it is not immediately walkable.
world = Path("src/world.gd")
text = world.read_text(encoding="utf-8")
old_route = """\t\t\tif not map.get_cell(next).is_walkable():\n\t\t\t\tcontinue\n\t\t\tseen[next] = true\n"""
new_route = """\t\t\tvar next_cell := map.get_cell(next)\n\t\t\tvar contract_walkable := next_cell.is_walkable()\n\t\t\tif (\n\t\t\t\tnot contract_walkable\n\t\t\t\tand next_cell.terrain\n\t\t\t\tand next_cell.terrain.is_walkable()\n\t\t\t\tand next_cell.obstacle\n\t\t\t\tand next_cell.obstacle.type == Obstacle.Type.DOOR_CLOSED\n\t\t\t):\n\t\t\t\tcontract_walkable = true\n\t\t\tif not contract_walkable:\n\t\t\t\tcontinue\n\t\t\tseen[next] = true\n"""
replace_once(world, old_route, new_route)

print("Applied minimal deterministic RNG patch and operable-door connectivity rule.")
