# Nightreign character visual contract

T1 uses one fixed visual contract for both selectable characters while keeping combat/grid logic independent from art.

## Runtime contract
- Logical actor footprint remains one 16x16 map cell.
- Character frame size: **48x64 px**.
- Foot pivot inside each frame: **(24,60)**.
- Pivot maps to tile-local **(8,16)**, so the Sprite2D offset is **(-16,-44)**.
- Eight explicit direction rows are required in this order: `S, SW, W, NW, N, NE, E, SE`.
- `shared_direction` must be false.
- Nearest filtering only. Animation art never changes collision, range, pathfinding or occupancy.

## T1 atlas layout
Each generated atlas is **192x2560** (4 columns x 40 rows of 48x64 frames).

| Animation | Direction rows | Frames | Semantics |
| --- | --- | ---: | --- |
| idle | 0-7 | 2 | Idle |
| move | 8-15 | 4 | locomotion |
| melee_attack | 16-23 | 4 | Windup -> Swing/Strum -> Release -> Recover |
| hit | 24-31 | 2 | Hit -> Recover |
| death | 32-39 | 4 | Fall -> Down |

Wylder uses `windup / swing / release / recover` for melee attack. Revenant uses `windup / strum / release / recover`.

## Current art status
`art/build_t1_character_atlas.py` creates the T1 atlases from each character's current identity sprite. This is a reproducible integration placeholder, not the final hand-authored animation pass. The controller/resource contract is intentionally stable so final 48x64 sprite sheets can replace `t1-atlas.png` without touching grid or combat code.

Canonical runtime resources:
- `assets/nightreign/characters/wylder/selectable.tres`
- `assets/nightreign/characters/revenant/selectable.tres`

Generated atlases:
- `assets/nightreign/characters/wylder/t1-atlas.png`
- `assets/nightreign/characters/revenant/t1-atlas.png`

Run `Run-Character-QA.cmd` locally or the T1 Character QA workflow to verify atlas size, pivot, eight directions, attack phases, real menu selection, real game scene and one-cell occupancy.
