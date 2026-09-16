# T0 Core Architecture Contract

T0 is complete only when the game can support a full twenty-floor run without content-specific hacks.

## Runtime contract

- Exactly 20 floors in a single expedition.
- Floors 1–19 are procedurally generated dungeons; floor 20 is the Nightlord arena.
- Every generated dungeon must contain the required stairs and a walkable route between entrance and descent. Invalid generation is rejected and regenerated automatically, up to eight outer retries in addition to the generator's own validation.
- A successful player action advances exactly one global turn and gives each enemy one action opportunity. Rejected actions consume zero time.
- Returning to an already generated floor preserves its state; floors are generated only on first visit.
- Fixed seed reproduces sampled floor topology; a different seed must change at least one sampled floor.

## Difficulty contract

Difficulty is driven by several small monotonic pressures rather than a single HP multiplier:

- enemy budget rises from 5 on floor 1 to a cap of 14 in the deep floors;
- HP rises 3% per floor for scalable common enemies;
- common enemy damage rises 1.5% per floor;
- elite chance rises gradually and receives milestone steps on floors 5, 10 and 15, capped at 18%;
- rune rewards rise with depth so risk and reward scale together;
- Night's Tide begins earlier on deeper floors but never before the configured safety minimum;
- floor 19 guarantees a Holy weapon option so the final prototype Nightlord weakness is not dependent on pure RNG.

Bosses can opt out of generic floor scaling and use bespoke tuning. T1/T2 content expansion must use this contract rather than hard-code per-floor exceptions.

## Validation gates

`tools/validate_t0.py` is the fast structural gate and must pass before runtime testing.

`Run-T0-QA.cmd` runs the static gate, imports the project with Godot 4.6, executes `tests/t0_core.tscn`, rejects SCRIPT ERROR output and fails if any runtime check fails.

GitHub Actions runs the same two-layer gate on every push and pull request to `main`.
