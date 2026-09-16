#!/usr/bin/env python3
"""Fast standard-library T0 gate. Runs without Godot and rejects structural regressions."""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []
checks = 0

def check(value: bool, label: str) -> None:
    global checks
    checks += 1
    print(f"T0 STATIC {'PASS' if value else 'FAIL'}: {label}")
    if not value:
        failures.append(label)

def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")

cfg = json.loads(read("assets/nightreign/data/expedition.json"))
curve = cfg.get("floor_progression", {})
check(curve.get("total_floors") == 20, "data declares 20 floors")
check(curve.get("boss_floor") == 20, "data declares floor 20 boss arena")
check(curve.get("milestones") == [5, 10, 15], "difficulty milestones are 5/10/15")

world_plan = read("src/world_plan.gd")
check("const TOTAL_FLOORS := 20" in world_plan, "WorldPlan exposes TOTAL_FLOORS=20")
check("const FINAL_FLOOR := 20" in world_plan, "WorldPlan exposes FINAL_FLOOR=20")
check("for depth in range(1, TOTAL_FLOORS + 1)" in world_plan, "WorldPlan builds floor graph programmatically")
check("LevelType.ARENA if depth == FINAL_FLOOR" in world_plan, "only final floor is selected as arena by plan")

night_run = read("src/nightreign/expedition/night_run.gd")
for symbol in [
    "floor_enemy_count", "floor_hp_multiplier", "floor_damage_multiplier",
    "floor_elite_chance", "night_threshold", "boss_floor"
]:
    check(f"func {symbol}" in night_run, f"NightRun exposes {symbol}")
check('map.depth == boss_floor() - 1' in night_run, "boss-prep Holy guarantee occurs on floor 19")
check('map.depth >= boss_floor()' in night_run, "final arena excludes Night's Tide")

milestones = curve["milestones"]
def mcount(depth: int) -> int:
    return sum(depth >= m for m in milestones)
def enemy_count(depth: int) -> int:
    c = curve["enemy_count"]
    return min(c["max"], c["base"] + ((depth - 1)//2)*c["per_two_floors"] + mcount(depth)*c["milestone_bonus"])
def hp(depth: int) -> float:
    c = curve["hp_multiplier"]
    return c["base"] + max(0, depth-1)*c["per_floor"]
def damage(depth: int) -> float:
    c = curve["damage_multiplier"]
    return c["base"] + max(0, depth-1)*c["per_floor"]
def elite(depth: int) -> float:
    c = curve["elite"]
    return min(c["max_chance"], c["base_chance"] + max(0,depth-1)*c["per_floor"] + mcount(depth)*c["milestone_bonus"])
def tide(depth: int, idx: int) -> int:
    c = cfg["night_tide"]
    return max(c["minimum_thresholds"][idx], c["thresholds"][idx] - max(0,depth-1)*c["threshold_reduction_per_floor"][idx])

prev = None
for depth in range(1, 20):
    state = (enemy_count(depth), hp(depth), damage(depth), elite(depth), tide(depth,0), tide(depth,1))
    check(state[0] >= 1 and state[4] < state[5], f"floor {depth:02d} curve is internally valid")
    if prev:
        check(state[0] >= prev[0], f"floor {depth:02d} enemy budget is monotonic")
        check(state[1] >= prev[1] and state[2] >= prev[2], f"floor {depth:02d} stat pressure is monotonic")
        check(state[3] >= prev[3], f"floor {depth:02d} elite pressure is monotonic")
        check(state[4] <= prev[4] and state[5] <= prev[5], f"floor {depth:02d} tide deadline never becomes easier")
    prev = state
check(enemy_count(19) > enemy_count(1), "deep floors have a larger enemy budget")
check(hp(19) > hp(1) and damage(19) > damage(1), "deep-floor enemies are materially stronger")
check(tide(19,0) < tide(1,0), "deep floors face earlier Night's Tide")

# Coarse balance sanity: T0 should become harder without turning common enemies into
# damage sponges before the later progression systems exist.
grades = cfg["grades"]
scaling = cfg["scaling"]
def weapon_damage(weapon_id: str, character_id: str = "wylder") -> int:
    weapon = cfg["weapons"][weapon_id]
    character = cfg["characters"][character_id]
    total = float(weapon["base"])
    for stat, grade in weapon["scaling"].items():
        total += grades[character["grades"][stat]] * scaling[grade]
    return round(total)
start_damage = weapon_damage(cfg["characters"]["wylder"]["starting_weapon"])
check(start_damage >= 8, "starting melee damage is viable")
for enemy_id in ["wolf", "soldier", "skeleton"]:
    base_enemy = cfg["enemies"][enemy_id]
    early_hits = (round(base_enemy["hp"] * hp(1)) + start_damage - 1) // start_damage
    deep_hits = (round(base_enemy["hp"] * hp(19)) + start_damage - 1) // start_damage
    elite_deep_hp = round(base_enemy["hp"] * hp(19) * curve["elite"]["hp_multiplier"])
    elite_hits = (elite_deep_hp + start_damage - 1) // start_damage
    check(1 <= early_hits <= 3, f"{enemy_id} floor-1 time-to-kill is sane")
    check(2 <= deep_hits <= 4, f"{enemy_id} floor-19 time-to-kill remains tactical")
    check(elite_hits <= 5, f"{enemy_id} elite does not become a damage sponge")
    deep_damage = round(base_enemy["damage"] * damage(19) * curve["elite"]["damage_multiplier"])
    check(deep_damage < cfg["characters"]["wylder"]["hp"] * 0.2, f"{enemy_id} elite cannot delete >20% max HP in one basic hit")

check((ROOT / ".github/workflows/t0-qa.yml").exists(), "GitHub runtime QA workflow exists")
check((ROOT / "tests/t0_core.gd").exists(), "Godot twenty-floor runtime suite exists")

# Source resource integrity. Only inspect actual load/preload/resource path syntax;
# output filenames and commented legacy examples are not dependencies.
patterns = [
    re.compile(r'(?:preload|load)\(\s*["\'](res://[^"\']+)["\']\s*\)'),
    re.compile(r'path=["\'](res://[^"\']+)["\']'),
]
missing: set[str] = set()
for path in ROOT.rglob("*"):
    if not path.is_file() or path.suffix.lower() not in {".gd", ".tscn", ".tres", ".godot"}:
        continue
    if ".godot" in path.parts:
        continue
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    text = "\n".join(line for line in lines if not line.lstrip().startswith("#"))
    for pattern in patterns:
        for ref in pattern.findall(text):
            rel = ref[6:]
            if not (ROOT / rel).exists():
                missing.add(f"{path.relative_to(ROOT)} -> {ref}")
check(not missing, "all loaded res:// dependencies resolve")
if missing:
    failures.extend(sorted(missing))

report = {
    "stage": "T0-static",
    "checks": checks,
    "failures": failures,
    "curve_samples": {
        str(d): {
            "enemy_count": enemy_count(d),
            "hp_multiplier": round(hp(d), 3),
            "damage_multiplier": round(damage(d), 3),
            "elite_chance": round(elite(d), 3),
            "tide": [tide(d,0), tide(d,1)],
        } for d in [1,5,10,15,19]
    }
}
(ROOT / "docs" / "T0_STATIC_QA.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))
sys.exit(0 if not failures else 1)
