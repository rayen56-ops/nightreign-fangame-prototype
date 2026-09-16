# Phase 01 asset contract

All map coordinates use Vector2i and one actor occupies one 16x16 cell.
Never derive collision, range, vision, pathfinding or occupancy from texture bounds.

Environment and ground items: 16x16 PNG; larger props stay anchored to that grid.
Wylder: 32x32 PNG frames, pivot (16,24) mapped to tile-local (8,16).
Sprite offset is (-8,-8); frame overhang is visual only.

The placeholder atlas is 192x1536. Each animation has eight explicit direction rows:
S, SW, W, NW, N, NE, E, SE. Rows and frame counts are in characters/wylder/visual.tres.
Idle: 2 frames; move/attack/claw: 4; hit: 2; death: 6.
These are rough placeholder variations, not finished animation assets.
Claw frames are reserved and not connected to gameplay.

Change atlas, frame size, pivot and animation metadata through the Resource.
Do not edit world.gd to replace character art. Visual controller never applies actions.
Nearest texture filtering, no pixel-art mipmaps, integer pixel positions.

Reserved directories: environment/, items/, ui/, vfx/, placeholders/.
Keep original assets/generated/ and art/ until replacements have passed validation.

Existing layer mapping is preserved: MapRenderer owns terrain/walls/items/vision;
Game/Actors owns actors; existing effect nodes handle combat effects;
Game/UI is the HUD and modal CanvasLayer. Future touch controls belong in their own
CanvasLayer, independent of world coordinates and desktop HUD.
