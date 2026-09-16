# Implementation Plan

## Current baseline

The repository already contains a Godot 4.6 playable M1 prototype: eight-direction grid turns, FOV, procedural dungeon floors, inventory/equipment, Wylder/Revenant, S–E grades, weapon scaling, Warming Stone, three common enemy types and a Gladius prototype.

This baseline is retained. We are not rewriting the framework.

## M1.1 — identity pass (current)

Goal: make the existing prototype read as NIGHTREIGN rather than a generic roguelike.

- [x] Lock product/design bible.
- [x] Keep exact one-player-action : one-enemy-action economy.
- [x] Add Night's Tide floor pressure with two encroachment stages.
- [x] Add Gladius phase transition with split echoes.
- [x] Keep Holy interrupt and telegraphed sweep/recovery loop.
- [x] Make launcher scripts work with bundled Godot when present or installed Godot when not.
- [ ] In-engine regression test on Windows Godot 4.6.
- [ ] Tune turn thresholds after a real playthrough.

## M1.2 — combat grammar

- Weapon archetype metadata and UI.
- Great weapon cleave/guard-break.
- Thrust reach.
- Dagger critical/position rule.
- Bow/catalyst explicit ranged targeting.
- Bleed/frost/poison/holy buildup framework.
- Enemy intent markers separate from boss telegraphs.

Exit criterion: changing weapon class changes positioning decisions, not only damage.

## M1.3 — dungeon grammar

- Nightreign-specific room templates layered onto procedural generation.
- Loot rarity and route-weighted drops.
- Chests, field bosses, traps and terrain events.
- One-way expedition pacing and descent confirmation.
- Seed display and deterministic run reproduction.

Exit criterion: three consecutive generated runs produce meaningfully different tactical routes without broken/stuck floors.

## M2 — art/readability

- Replace temporary Wylder/Revenant sprites with original pixel sprites.
- 8-direction idle/move/attack/hit priority set.
- Original Gladius-inspired boss sprite and split-state silhouette.
- Night's Tide shader/tiles, fog, Grace and hit effects.
- Traditional Chinese UI first; Japanese/English data-ready localization.
- Controller navigation.

Exit criterion: screenshots are recognizable as the intended fan game without text labels.

## M3 — run systems

- Runes and level-up decisions.
- Flask/consumable economy.
- Relic effects and pre-run loadout.
- Weapon rarity, enhancement and passive effects.
- Save/resume one active expedition.
- Death/victory recap with seed and build summary.

## M4 — content expansion

Add Nightfarers one at a time through the shared character contract. Add Nightlords one at a time through the boss contract. Each addition must ship with data, gameplay implementation, QA scene and placeholder art before final art.

Initial content target: base roster and base Nightlords, then optional later expansion content.

## M5 — release candidate

- Audio and music pass using original/licensed material only.
- Full settings, remapping, accessibility and window modes.
- Performance and long-session memory regression.
- Portable Windows build without bundling editor/runtime in source control.
- Attribution, fan-project disclaimer and versioned release package.
