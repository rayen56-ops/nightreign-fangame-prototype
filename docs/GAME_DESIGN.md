# NIGHTREIGN Grid Roguelike — Game Design Bible

## Product vision

A single-player turn-based dungeon crawler inspired by classic Mystery Dungeon design and the decision density of *Diavolo no Daibouken*, translated into the identity of *ELDEN RING NIGHTREIGN*.

The target feeling is not “Elden Ring with the action removed.” It is: every tile is a combat decision, every item can change the run, and every Nightfarer still feels recognizably like that character after real-time actions are translated into turns, ranges, telegraphs, cooldowns and positioning.

This is a non-commercial fan prototype. Game code and pixel assets are original or permissively licensed. Do not import or redistribute extracted commercial game assets.

## Core pillars

1. **One action, one world response.** A successful player action advances exactly one turn. Every active enemy then receives one action opportunity. Opening menus, cancelling targeting and illegal actions consume no turn.
2. **Nightfarers are builds, not skins.** Each character has a passive, Character Skill and Ultimate Art that changes routing and combat priorities.
3. **Loot rewrites the run.** Weapons have no hard stat requirements. S/A/B/C/D/E grades and weapon scaling determine efficiency, so any Nightfarer can use anything but natural pairings remain obvious.
4. **Boss attacks are puzzles on the grid.** Nightlords use visible threat cells, multi-turn attacks, recovery windows, phase changes and weaknesses. Damage should rarely arrive without a readable cause.
5. **Night closes in.** Exploration cannot become infinite safe farming. Each non-boss floor gradually falls to Night's Tide, shrinking the safe area and forcing commitment.
6. **Low-cost art, high-fidelity atmosphere.** Small pixel sprites, strong silhouettes, cold ruins, black-violet night, gold grace, ember-orange boss effects, fog and restrained animation. Readability beats sprite detail.

## Turn model

A turn is consumed by successful movement, melee attacks, pickups, equipment changes, item use, Character Skills, Ultimate Arts, resting/waiting and other deliberate world actions.

A turn is not consumed by inventory inspection, character/status inspection, targeting cancellation, invalid movement or failed skill use.

Enemy order is deterministic inside a turn. Randomness is used for generation and loot, not to hide basic combat rules.

## Run structure

### Vertical slice

Character select → Floor 1 exploration → Floor 2 pressure escalation → Floor 3 Nightlord arena → victory/death result → character select.

### Full target

A full expedition is structured as three escalating “nights.” Each night contains multiple procedural exploration floors and ends with a major encounter. Terrain themes, loot tables, enemy families and Night's Tide timing vary by route. The final night ends in a Nightlord.

Backtracking is not a primary strategy. The game should reward descending and adaptation rather than clearing every tile.

## Night's Tide

Non-boss floors have a floor-local turn clock.

- Calm: full floor is safe.
- Encroaching Night: an outer band becomes Night's Tide.
- Deep Night: the safe region contracts again.

Standing in the Tide damages the player at end of turn. The safe center is biased toward the descent/goal so pressure naturally pushes the expedition forward. Boss floors disable the Tide and replace time pressure with boss mechanics.

The exact thresholds are balance data, not lore constants.

## Character model

Displayed attributes use grades only: VIG, MND, END, STR, DEX, INT, FAI, ARC = S/A/B/C/D/E.

Internal grade score: E=1, D=2, C=3, B=4, A=5, S=6.

No weapon has an equip requirement. Weapon scaling converts relevant grades into bonus damage. HP, cooldowns, durations and Ultimate charge remain numeric because the player needs exact tactical information.

### Wylder vertical-slice identity

- Passive: Sixth Sense prevents one lethal hit, refreshed at Grace.
- Character Skill: Claw Shot, line target. Pulls normal enemies or pulls Wylder toward large targets.
- Ultimate Art: Onslaught Stake, high single-target damage plus adjacent blast.
- Natural loot preference: STR/DEX physical weapons, but all equipment remains legal.

### Revenant vertical-slice identity

- Passive: Necromancy may briefly raise defeated enemies as allied spirits.
- Character Skill: Summon Spirit cycles family summons with different combat profiles.
- Ultimate Art: Immortal March prevents allied deaths briefly and empowers summons.
- Natural loot preference: FAI/INT tools and seals.

Future Nightfarers must follow the same contract: passive + Character Skill + Ultimate Art + grade profile + preferred but non-mandatory loot.

## Weapon model

Each weapon record contains:

- archetype
- base power
- scaling grades by attribute
- affinity/damage identity
- optional status buildup
- optional special rule

First implementation keeps basic attacks deterministic. Later archetypes add grid identity: heavy weapons gain cleave or guard-break; thrust weapons gain reach; daggers gain position/critical advantages; bows and catalysts use explicit targeting; shields alter incoming damage and facing.

Item names and mechanical references may pay homage to NIGHTREIGN/ELDEN RING, but production art must be original pixel work or permissively licensed placeholders.

## Dungeon content

Generation uses connected rooms and corridors, FOV/fog of war, stairs, item placements and enemy pockets. Themes should eventually include ruined Limveld-style camps, castles, mines, forests, catacombs and special shifted terrain while preserving a single-tile tactical grid.

Rooms exist to create encounter shapes, not decorative dead space. Corridors create line control, retreats and ambushes. Special terrain must affect decisions: doors, hazards, breakable/temporary blockers, healing zones and later elevation/terrain variants.

## Enemy model

Small enemies should be mechanically legible in one sentence. Examples:

- Soldier: closes distance and strikes normally.
- Wolf: low HP, faster pressure through pack placement rather than extra free turns.
- Skeletal Militiaman: durable lane blocker; later version gains revival logic.

Enemy difficulty should come from combinations and positioning before raw HP inflation.

## Nightlord model

Every Nightlord needs:

- at least three readable attacks
- at least two phases or a major state change
- one recovery/opening rule
- one exploitable weakness or interrupt rule
- one signature mechanic that survives the transition from action game to grid tactics

### Gladius vertical slice

Phase 1 uses a telegraphed flame sweep and recovery opening. Holy-aligned hits build an interrupt. At half health Gladius performs a one-time split, creating two temporary hunt echoes and increasing pressure. This is an adaptation, not a frame-accurate recreation of the original boss.

## Economy and progression

Run economy uses Runes as temporary expedition value. Long-term unlocks, relic loadouts and meta progression are later milestones. The first playable goal is strong run-to-run loot decisions, not grinding permanent stats.

## Visual direction

Logical gameplay tiles remain small and readable. Characters target roughly 48–64 px source work, bosses 96–128 px, displayed at integer scale. The game can use fewer colors per asset but should not use a generic bright fantasy palette.

Palette hierarchy:

- environment: charcoal, desaturated blue-gray, dark moss
- night/tide: black-violet, cold blue
- grace/holy: muted gold
- danger/boss: ember orange and blood red
- UI: near-black panels, parchment-gold focus, restrained cyan accents

Animation budget prioritizes anticipation, impact and silhouette changes. A three-frame readable attack is better than a twelve-frame muddy one.

## Production rules

- Keep gameplay data external and data-driven where practical.
- Do not hard-code a new character by copying the entire expedition controller.
- Every major mechanic receives a deterministic QA scenario before content multiplication.
- Do not expand to all Nightfarers/Nightlords until the Wylder vertical slice is fun from title screen to result screen.
- Preserve upstream MIT attribution for the Godot roguelike framework.
