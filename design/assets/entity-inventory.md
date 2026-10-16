# Visual Entity & Screen Inventory

> Generated: 2026-10-15
> Sources: `design/gdd/systems-index.md`; Visual/Audio and UI Requirements sections of `design/gdd/{borrowed-face, downing-and-rescue, first-person-controller, lobby-role-assignment, match-flow, monster-abilities, pings-and-callouts, scare-events, survivor-defense, survivor-objectives}.md`; `design/registry/entities.yaml`; `design/levels/research-facility.md`; `design/art/art-bible.md` (sections 3-6, 8); `design/ux/{hud, results, interaction-patterns}.md`; greybox in `src/core/facility/map_greybox.gd`, `src/core/lobby/character_def.gd`, `assets/levels/research_facility.tscn`.
> Short names: art bible = `art-bible.md`, level doc = `research-facility.md`. Order follows the brief's build order: characters, held items, facility, VFX.
> Greybox today: room shells are BoxMesh (`map_greybox.gd`); survivor looks are placeholder `CharacterDef` entries; no shipped art in `assets/`.

## Entities

| # | Name | Type | Description | Source | Status |
|---|------|------|-------------|--------|--------|
| 1 | Survivor shared body | Character | One skeleton/mesh/proportions (3:4:1 mass, padded jumpsuit, visor or covered mouth); LOD0-2; identical for all 5 so disguise needs no rig change | art-bible §3, §5 | Specced (characters-assets.md) |
| 2 | Survivor look 1 (Bone) | Character | `CharacterLook` .tres: bone `#E6E1D3` suit, hard hat with lamp, one horizontal chest bar | art-bible §5 | Specced (characters-assets.md) |
| 3 | Survivor look 2 (Safety Yellow) | Character | Yellow `#E3B31C` suit, large square backpack, two bars | art-bible §5 | Specced (characters-assets.md) |
| 4 | Survivor look 3 (Cobalt) | Character | Cobalt `#2E63B8` suit, hood + scarf tail, chevron | art-bible §5 | Specced (characters-assets.md) |
| 5 | Survivor look 4 (Rust Orange) | Character | Orange `#C8581E` suit, cross-strap radio with short antenna, three dots | art-bible §5 | Specced (characters-assets.md) |
| 6 | Survivor look 5 (Violet) | Character | Violet `#7B4FA0` suit, shoulder pad + clipboard, plain sleeve band (S5 only in 5-survivor rounds) | art-bible §5; level doc Spawn Points | Specced (characters-assets.md) |
| 7 | Survivor retro-reflective stripe material | Character | Shared stripe mask/material, bright under flashlight, never emissive; copied by disguise | art-bible §5 | Specced (characters-assets.md) |
| 8 | Survivor locomotion animation set | Character | Walk, sprint, crouch-walk, crawl, idle; shaky flashlight hand; borrowed whole by a disguise | first-person-controller V/A; art-bible §5 | Specced (characters-assets.md) |
| 9 | Survivor interaction animations | Character | Interact loop, hold-start/hold-end poses (fake holds identical), hide enter/exit, barricade build | first-person-controller V/A; survivor-objectives; survivor-defense | Specced (characters-assets.md) |
| 10 | Survivor state animations | Character | Shocked stagger, seized/pinned, Downed pose, Call for Help, kneel rescue, stand-up, Eliminated collapse; pose only, no tint | downing-and-rescue V/A; survivor-defense; art-bible §5 | Specced (characters-assets.md) |
| 11 | Shapeshifter true form | Enemy | ~2.4 m, narrow trunk, over-long arms, wet near-black clearcoat, bone-white teeth/ribs/claws, no accessory; own LOD0-2 + materials, same rig family | art-bible §3, §5; monster-abilities; borrowed-face | Specced (characters-assets.md) |
| 12 | True form animations | Enemy | Idle/walk, lunge coil wind-up, lunge hit, miss stumble, stun stagger, takedown pin, reveal facing viewers | monster-abilities V/A; downing-and-rescue; survivor-defense; borrowed-face | Specced (characters-assets.md) |
| 13 | First-person arms (viewmodel) | Character | Shared arms rig at 1024 px/m (XL set) carrying held items; interact and hold poses | art-bible §6, §8 | Specced (characters-assets.md) |
| 14 | Flashlight | Item | Held model + world-visible beam to all players; Bone Flashlight `#F2E6C8`, 14 m, ~40 deg cone; click on/off | survivor-defense V/A; art-bible §4; registry items | Specced (characters-assets.md) |
| 15 | Taser (stun item) | Item | Held model, cartridge count on item, darts and wires; registry `arc_flare` is deprecated, this is its replacement | survivor-defense V/A; registry items | Specced (characters-assets.md) |
| 16 | Taser darts and wires | Item | Projectile pair + wire to target, retracts after fire | survivor-defense V/A | Specced (characters-assets.md) |
| 17 | Env trim sheet: concrete / wall base | Environment | 2048 trim sheet | art-bible §6, §8 | Needed |
| 18 | Env trim sheet: metal / door frames | Environment | 2048 trim sheet | art-bible §6 | Needed |
| 19 | Env trim sheet: glass / mullion | Environment | 2048 trim sheet; thin frames, blue-green tint, see-through at flashlight angle | art-bible §3, §6 | Needed |
| 20 | Env trim sheet: floor markings / pipes | Environment | 2048 trim sheet incl. corridor stripe markings | art-bible §6 | Needed |
| 21 | Tileable: floor tile | Environment | 1024 PBR-lite (albedo/normal/ORM); footstep surface "tile" | art-bible §6; first-person-controller V/A | Needed |
| 22 | Tileable: concrete | Environment | 1024 PBR-lite; footstep surface "concrete" | art-bible §6; first-person-controller V/A | Needed |
| 23 | Tileable: painted block | Environment | 1024 PBR-lite | art-bible §6 | Needed |
| 24 | Tileable: steel plate | Environment | 1024 PBR-lite | art-bible §6 | Needed |
| 25 | Tileable: ceiling panel | Environment | 1024 PBR-lite | art-bible §6 | Needed |
| 26 | Tileable: rubber matting | Environment | 1024 PBR-lite | art-bible §6 | Needed |
| 27 | Tileable: checker plate | Environment | 1024 PBR-lite | art-bible §6 | Needed |
| 28 | Tileable: server rack | Environment | 1024 PBR-lite | art-bible §6 | Needed |
| 29 | Metal grate floor | Environment | Third footstep surface; not in the art bible's tileable list | first-person-controller V/A | Needed |
| 30 | Decal set (stains, cracks, signage) | Environment | 256 static decals, placed once in the level, identical every client/round | art-bible §6 | Needed |
| 31 | Room-name and zone signage | Environment | Short callout-ID signs (A1..C5), evacuation signage; zone colour coding | level doc Zones; art-bible §6 | Needed |
| 32 | Corridor floor stripes | Environment | Solid blue (H-N) and dashed orange (H-S) emissive stripes | level doc Visual Direction; art-bible §4 | Needed |
| 33 | A1 Entry / Decon | Environment | 10x12 spawn room, decon arch landmark (curved), three exits. Greybox BoxMesh | level doc Zones | Needed |
| 34 | A2 Lab Spine | Environment | 3x32 hall, glass walls to A3/A4, three lighting segments. Greybox BoxMesh | level doc Zones | Needed |
| 35 | A3 Wet Lab | Environment | 10x14, benches, glass wall to spine, hiding cabinet | level doc Zones | Needed |
| 36 | A4 Specimen Lab | Environment | 9x12, glass on two sides, lab door into B1 | level doc Zones | Needed |
| 37 | A5 Cold Storage | Environment | 9x10, hiding locker, sealed specimen fridges | level doc Zones; art-bible §6 | Needed |
| 38 | A6 Director's Office | Environment | 10x10, desk dressing, hiding cabinet, two exits | level doc Zones | Needed |
| 39 | A7 Observation Gallery | Environment | 9x10, floor-to-ceiling window down into A4 (landmark) | level doc Zones, Visual Direction | Needed |
| 40 | H-N North Service Corridor | Environment | 48x4, blue stripe, four ~12 m lighting segments | level doc Zones | Needed |
| 41 | H-S South Service Corridor | Environment | 50x4, orange stripe, four segments, camera c2 | level doc Zones | Needed |
| 42 | B1 Server Hall | Environment | 18x16, double height, rack lanes 2-3 m, four entrances | level doc Zones; art-bible §6 | Needed |
| 43 | B2 Power Room | Environment | 18x8, breaker wall | level doc Zones | Needed |
| 44 | B3 Cooling Plant | Environment | 18x8, loud machinery, locker | level doc Zones | Needed |
| 45 | C1 Security Office | Environment | 12x12, monitor wall station, barricadable doors | level doc Zones | Needed |
| 46 | C2 Checkpoint | Environment | 10x14, gate between B and C, archway into C4 | level doc Zones | Needed |
| 47 | C3 Records Archive | Environment | 20x8 | level doc Zones | Needed |
| 48 | C4 Evacuation Hall | Environment | 10x16, final exit, beacon, exit sign | level doc Zones | Needed |
| 49 | C5 Backup Control | Environment | 8x10, backup controls panel, locker | level doc Zones | Needed |
| 50 | Ordinary door (D) | Environment | Openable/closable, shudders in place for slam scare (no swing), burst variant for door-burst scare | level doc Fixtures; scare-events V/A | Needed |
| 51 | Barricadable door (B) | Environment | 5 in Zone C; plank/bar barricade build, strain, break states; shakes per strike | level doc Fixtures; survivor-defense V/A | Needed |
| 52 | Open archway (O) | Environment | Non-door opening (A1~H-S, C2~C4) | level doc Layout | Needed |
| 53 | Glass partition | Environment | Cracks but stays see-through for glass-break scare (sg1-sg3); A2 walls, A7 window | level doc Fixtures; scare-events V/A; art-bible §3 | Needed |
| 54 | Hiding spot: lab cabinet | Prop | 3 (h1-h3), openable door, searched by monster | level doc Fixtures; survivor-defense V/A | Needed |
| 55 | Hiding spot: storage locker | Prop | 3 (h4-h6), same behaviour | level doc Fixtures | Needed |
| 56 | Data drive | Prop | Flat slab with lit edge bar, cyan; carried, dropped (glowing on floor), docked, ejected from terminal | art-bible §3; survivor-objectives V/A; registry items | Needed |
| 57 | Fuse | Prop | Cylinder with two rings; carried and installed | art-bible §3; registry items | Needed |
| 58 | Fuse box | Prop | Tall panel with vertical indicator bar; dark in Low Power, indicator lit on active; install sparks | art-bible §3; level doc Lighting States | Needed |
| 59 | Evacuation terminal (T1-T3) | Prop | Hero: wide screen with top hood, activation display, countdown/pause state, drive dock slots; unique texture set | art-bible §3, §6; survivor-objectives V/A | Needed |
| 60 | Exit door E + chevron frame | Prop | Hero: chevron-framed door, Exit Green light, opens with door cycle; unique texture set | art-bible §3, §6; survivor-objectives V/A | Needed |
| 61 | The Core | Prop | Hero: B1 double-height light column, brightest point on map, pulses on fuse install | level doc Visual Direction; art-bible §6 | Needed |
| 62 | Breaker wall | Prop | Hero: B2 landmark wall, unique texture set | art-bible §6; level doc | Needed |
| 63 | Monitor wall + C1 monitor station | Prop | Hero: surveillance monitors, one feed at a time, monitor glow | art-bible §6; level doc Fixtures | Needed |
| 64 | Backup controls panel | Prop | C5 panel (function open question) | level doc Fixtures | Needed |
| 65 | Backup light switch | Prop | One per room (not corridors/A2); hold to end Blackout, relay clack | level doc Fixtures; monster-abilities V/A | Needed |
| 66 | Surveillance camera (c1-c4) | Prop | Wall/ceiling cameras: B1, H-S, C4, A2 | level doc Fixtures | Needed |
| 67 | Surveillance monitor feed | Prop | Render-to-texture screen; single-client impossible-image frame for scare | level doc Fixtures; scare-events V/A | Needed |
| 68 | PA speaker with light | Prop | Recording scare: speaker light + distorted voice | scare-events V/A | Needed |
| 69 | Lab dressing set | Prop | Benches, abandoned desks, sealed specimen fridges, dead monitors; props below 1.0 m | art-bible §6; level doc Narrative | Needed |
| 70 | Server / power / cooling dressing | Prop | Server racks, cabling, pipes, B3 machinery; cabling is the organic-curve exception | art-bible §3, §6 | Needed |
| 71 | Security dressing | Prop | Checkpoint gate, security log screen, records shelving | level doc Narrative, Zones | Needed |
| 72 | Lab panel lights (Zone A) | Light | Cool green-white `#A9C4B8` ~6500K, low intensity | art-bible §4; level doc Lighting | Needed |
| 73 | Equipment glow (Zone B) | Light | Amber `#D98A2B` ~2700K | art-bible §4 | Needed |
| 74 | Security lights (Zone C) | Light | Red `#B3342E`, low energy, desaturated | art-bible §4 | Needed |
| 75 | Emergency floor strips + exit signage | Light | Faint, always on in every volume incl. Blackout | level doc Lighting States | Needed |
| 76 | Evacuation beacons (amber) | Light | Rotating amber beacons along H-N, H-S, C2 toward C4; steady in reduced-flash | level doc Lighting States; scare-events V/A | Needed |
| 77 | C4 evac beacon (red) | Light | Rotating red, triangle lens cap, spins red on Terminal Activating | art-bible §4; level doc Lighting States | Needed |
| 78 | Alarm strobe | Light | Rate-capped strobe for Alarm scare | scare-events V/A | Needed |
| 79 | Lighting presets (Low Power, Restored, Evacuation, Blackout, Exit Open) | Other | Per-volume states; greybox `lighting_presets.gd` already drives them | level doc Lighting States | Needed |
| 80 | VFX: transformation warp | VFX | 2 s body warp, spatial distortion; silhouette-first end frame | borrowed-face V/A; art-bible §5 | Needed |
| 81 | VFX: reveal flare | VFX | True-form reveal, scaled light flare | scare-events V/A; borrowed-face V/A | Needed |
| 82 | VFX: taser arc | VFX | Short blue arc at target; reduced-flash variant; victim blue edge | survivor-defense V/A | Needed |
| 83 | VFX: stun resisted spark | VFX | Small spark, no stagger (true form) | survivor-defense V/A | Needed |
| 84 | VFX: fuse install sparks | VFX | Sparks at fuse box | survivor-objectives V/A | Needed |
| 85 | VFX: door burst debris and dust | VFX | Door-burst scare | scare-events V/A | Needed |
| 86 | VFX: glass shards | VFX | Glass-break scare | scare-events V/A | Needed |
| 87 | VFX: lunge impact | VFX | Hit on survivor; miss scrape dust | monster-abilities V/A | Needed |
| 88 | VFX: drive/exit glow | VFX | Dropped drive glow, ejected drives, Exit Open green flood | survivor-objectives V/A; level doc Lighting States | Needed |
| 89 | VFX: world progress ring | VFX | World-space bar/ring over objects, hide/barricade, rescue | survivor-objectives V/A; downing-and-rescue V/A | Needed |

## UI Screens

| # | Screen Name | Description | Source | Status |
|---|-------------|-------------|--------|--------|
| 1 | Lobby (host/join, players, picker) | Address/port/name form, player list with Ready, rotation queue, C1-C5 character picker with preview, voice toggle, countdown, reject reasons. Greybox `src/ui/lobby/lobby_screen.gd` | lobby-role-assignment UI Requirements | Needed (`/ux-design lobby`) |
| 2 | Results | Round results, stun hits per player, outcome; also read-only Last round view in lobby | Specced (design/ux/results.md) | Specced (design/ux/results.md) |
| 3 | Spectator view | Eliminated-player spectator transition | downing-and-rescue V/A; match-flow | Needed (`/ux-design spectator`) |
| 4 | Accessibility options | Flinch toggle, reduced flash/motion, captions, remap | scare-events UI; hud.md I28/I33; first-person-controller V/A | Needed (`/ux-design`, `design/accessibility-requirements.md` is the content source) |
| 5 | Round-end fade | Fade to results, outcome sting per role | match-flow V/A | Specced (design/ux/results.md) |

## HUD Elements

| # | Element | Description | Source | Status |
|---|---------|-------------|--------|--------|
| 1 | Clock and phase banner | Time remaining top centre, phase under it, urgent colour final 30 s, phase-change banner | match-flow UI/V-A | Specced (design/ux/hud.md I1-I2) |
| 2 | Escape / disconnect feed | HUD feed lines | match-flow UI | Specced (design/ux/hud.md I3) |
| 3 | Objective checklist | Drives x/2, fuses x/2, terminal state, carrier names | survivor-objectives UI | Specced (design/ux/hud.md I4-I5) |
| 4 | World markers | Discovered points, dropped items, Downed marker with bleed ring | survivor-objectives UI; downing-and-rescue UI | Specced (design/ux/hud.md I6, I11) |
| 5 | Progress ring / hold bar | Radial bar around crosshair with cancel cause; world bars | first-person-controller UI; survivor-defense UI | Specced (design/ux/hud.md I7, I13, I17, I30) |
| 6 | Activation countdown | HUD and terminal countdown with pause state | survivor-objectives UI | Specced (design/ux/hud.md I8) |
| 7 | Crosshair and interaction prompt | Minimal dot; action name and key | first-person-controller UI | Specced (design/ux/hud.md I29, I31) |
| 8 | Teammate roster | Healthy / Wounded / Downed / Eliminated states | downing-and-rescue UI | Specced (design/ux/hud.md I10) |
| 9 | Own-state vignette | Full-screen Seized/Downed vignette, bleed-out ring | downing-and-rescue UI | Specced (design/ux/hud.md I12, I14) |
| 10 | Taser cartridge slot | Survivor item slot | survivor-defense UI | Specced (design/ux/hud.md I15) |
| 11 | Monster stun/immunity indicator | Per-tick remaining | survivor-defense UI | Specced (design/ux/hud.md I16) |
| 12 | Face picker and observation progress | Shapeshifter portraits, unlock tick, form + cooldown, transforming progress | borrowed-face UI | Specced (design/ux/hud.md I18-I20) |
| 13 | Ability cooldowns and aim previews | Lunge/False Signal/Blackout cooldowns, placement preview, zone highlight | monster-abilities UI | Specced (design/ux/hud.md I21-I23) |
| 14 | Install alert | Offset circle on monster HUD | survivor-objectives UI/V-A | Specced (design/ux/hud.md I9) |
| 15 | Ping markers | World-space, clamped to edge; colour + glyph by type (location, item, warning) | pings-and-callouts UI | Specced (design/ux/hud.md I24) |
| 16 | Callout wheel and feed | Wheel at centre, last 4 feed lines with arrows, "(not you)" tag | pings-and-callouts UI | Specced (design/ux/hud.md I25-I26) |
| 17 | Rate-limit feedback | "Too fast" tick near crosshair | pings-and-callouts UI | Specced (design/ux/hud.md I27) |
| 18 | Flinch-off substitute pulse | Screen-edge pulse toward scare origin | scare-events UI | Specced (design/ux/hud.md I28) |
| 19 | Audible cue indicators and captions | Lunge wind-up/transform indicators, PA/voice captions | accessibility-requirements via hud.md | Specced (design/ux/hud.md I32-I33) |
| 20 | HUD icon and glyph art set | Item icons, ping glyphs, face portraits; art bible UI section is unwritten | hud.md; art-bible §7 | Needed |

## Audio

| # | Name | Type (SFX / Music / Ambient) | Description | Source | Status |
|---|------|------------------------------|-------------|--------|--------|
| 1 | Footsteps per survivor | SFX | Per-survivor set, three surface variants (concrete, metal grate, tile); disguise uses target's set | first-person-controller V/A | Specced (characters-assets.md) |
| 2 | Sprint breathing | SFX | Layer heard only by the sprinting player | first-person-controller V/A | Specced (characters-assets.md) |
| 3 | Interact loops | SFX | Per-type loop; quiet variant for fake holds | survivor-objectives V/A | Specced (characters-assets.md) |
| 4 | Fuse install | SFX | Loud spatialized install sound | survivor-objectives V/A | Specced (characters-assets.md) |
| 5 | Monster install alert cue | SFX | Monster-only | survivor-objectives V/A | Specced (characters-assets.md) |
| 6 | Drive clatter | SFX | Drive dropped | survivor-objectives V/A | Specced (characters-assets.md) |
| 7 | Generator spin-up | SFX | Power restored | survivor-objectives V/A | Specced (characters-assets.md) |
| 8 | Terminal activation tone | SFX | Rising tone, stalls when paused; activation loop | survivor-objectives V/A; level doc Audio | Specced (characters-assets.md) |
| 9 | Drive eject clunk | SFX | Mechanical eject | survivor-objectives V/A | Specced (characters-assets.md) |
| 10 | Exit door alarm and cycle | SFX | Alarm on open, door cycle on extraction | survivor-objectives V/A; match-flow V/A | Specced (characters-assets.md) |
| 11 | Transformation distortion | SFX | Spatial distortion within 15 m | borrowed-face V/A | Specced (characters-assets.md) |
| 12 | Reveal sting | SFX | True-form reveal stinger | borrowed-face V/A; scare-events V/A | Specced (characters-assets.md) |
| 13 | Face-unlock tick | SFX | Quiet UI tick, monster only | borrowed-face V/A | Specced (characters-assets.md) |
| 14 | Takedown struggle | SFX | Loud directional struggle cue | downing-and-rescue V/A | Specced (characters-assets.md) |
| 15 | Stun crack and release gasp | SFX | Commit cancelled by stun | downing-and-rescue V/A | Specced (characters-assets.md) |
| 16 | Collapse and heartbeat | SFX | Downed; heartbeat slows toward bleed-out end | downing-and-rescue V/A | Specced (characters-assets.md) |
| 17 | Call for Help cry | SFX | Directional voice cry | downing-and-rescue V/A | Needed |
| 18 | Rescue effort loop and relief cue | SFX | Quiet effort loop, short relief on rescued | downing-and-rescue V/A | Needed |
| 19 | Eliminated final sting | SFX | Distinct; respects reduced volume | downing-and-rescue V/A | Needed |
| 20 | Flashlight click | SFX | On/off | survivor-defense V/A | Needed |
| 21 | Taser pop and crackle | SFX | Cartridge pop then electric crackle; dull fizz on resist | survivor-defense V/A | Needed |
| 22 | Stun pain / shock grunt | SFX | Monster pain cry in true form; survivor grunt while disguised | survivor-defense V/A | Needed |
| 23 | Hide creak and breathing | SFX | Soft creak; breathing/creak every 5 s on long hide | survivor-defense V/A | Needed |
| 24 | Search door rattle | SFX | Monster opens spot | survivor-defense V/A | Needed |
| 25 | Barricade hammering and bangs | SFX | Build hammering, loud break bangs | survivor-defense V/A; level doc Audio | Needed |
| 26 | Lunge wind-up cue | SFX | Distinct, 20 m, directional | monster-abilities V/A | Needed |
| 27 | Lunge hit and miss scrape | SFX | Hit sound; miss scrape | monster-abilities V/A | Needed |
| 28 | False Signal sound bank | SFX | Chosen sound at placed point | monster-abilities V/A | Needed |
| 29 | Blackout power-cut thunk and relay clack | SFX | Power-cut on Blackout, relay clack on backup switch | monster-abilities V/A; scare-events V/A | Needed |
| 30 | Ping ticks | SFX | Soft positional tick; sharper warning tone; local "too fast" click | pings-and-callouts V/A | Needed |
| 31 | Callout voice lines | SFX | Authored lines per callout, one voice set per displayed identity (5 sets) | pings-and-callouts V/A; lobby-role-assignment | Needed |
| 32 | Door slam, burst impact, glass break | SFX | Scare anchors at origin | scare-events V/A | Needed |
| 33 | Alarm, recording voice, monitor static | SFX | Positional alarm; distorted voice from speaker; static at monitor | scare-events V/A | Needed |
| 34 | Emergency alarm loop and PA | SFX | Evacuation mode alarm loop with PA countdown | scare-events V/A; match-flow V/A | Needed |
| 35 | Phase and outcome stings | SFX | Subtle Investigation tone, Evacuation alarm sting, ticking final 30 s, win/loss round-end sting per role, escape door sound | match-flow V/A | Needed |
| 36 | Zone A ambience | Ambient | Fluorescent hum, dripping, ventilation ticks; cabinet/glass tap SFX | level doc Audio | Needed |
| 37 | Zone B ambience | Ambient | Server fans; B3 machinery loud enough to mask footsteps | level doc Audio | Needed |
| 38 | Zone C ambience | Ambient | Low security tone, monitor buzz | level doc Audio | Needed |
| 39 | Evacuation alarm bed | Ambient | Facility-wide alarm bed (owned by M4 audio pass) | level doc Audio | Needed |
| 40 | Music | Music | None in scope: level doc lists "None (greybox)" for every zone and defers Evacuation music to the M4 audio pass | level doc Audio | Not in scope (no music row) |
