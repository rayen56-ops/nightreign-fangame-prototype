# T1 asset contract

All map coordinates use Vector2i and one actor occupies one 16x16 cell.
Never derive collision, range, vision, pathfinding or occupancy from texture bounds.

Environment and ground items remain on the existing 16x16 world grid; larger props stay anchored to that grid.

## Character frames
Wylder and Revenant use 48x64 PNG frames with pivot (24,60), mapped to tile-local (8,16).
The runtime Sprite2D offset is (-16,-44). Frame overhang is visual only.
Eight direction rows are explicit and ordered S, SW, W, NW, N, NE, E, SE.

The T1 integration atlas is 192x2560. Rows are:
- 0-7 idle, 2 frames
- 8-15 move, 4 frames
- 16-23 melee attack, 4 frames
- 24-31 hit, 2 frames
- 32-39 death, 4 frames

Melee animation timing is semantic rather than decorative:
- Wylder: Windup -> Swing -> Release -> Recover
- Revenant: Windup -> Strum -> Release -> Recover
After Recover, the visual controller returns to Idle. Gameplay resolution remains owned by the existing action system.

`art/build_t1_character_atlas.py` materializes reproducible integration atlases from the current character identity sprites. These atlases prove sizing, anchoring, direction and animation plumbing; they are not final authored art. Final sprite sheets may replace `t1-atlas.png` as long as this contract and animation metadata are preserved.

Change atlas, frame size, pivot and animation metadata through `NightreignCharacterVisual` resources.
Do not edit world.gd to replace character art. The visual controller never applies actions.
Nearest texture filtering, no pixel-art mipmaps, integer pixel positions.

Canonical runtime resources are each character's `selectable.tres`. The generated `t1-atlas.png` beside it is the current atlas source.

Reserved directories: environment/, items/, ui/, vfx/, placeholders/.
Keep original assets/generated/ and art/ until replacements have passed validation.

Existing layer mapping is preserved: MapRenderer owns terrain/walls/items/vision;
Game/Actors owns actors; existing effect nodes handle combat effects;
Game/UI is the HUD and modal CanvasLayer. Future touch controls belong in their own CanvasLayer, independent of world coordinates and desktop HUD.
