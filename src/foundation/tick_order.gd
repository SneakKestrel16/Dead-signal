class_name TickOrder extends RefCounted
## The one place the phase-4 feature order lives (ADR-0005 section 4). Lowest value runs first;
## gaps leave room for later steps. Each step is followed by bus.flush() (see FeatureStep).
## Usage: `server.start_round({TickOrder.SURVIVOR_DEFENSE: defense}, knobs)`.

const MATCH_FLOW_BEGIN := 100
const SURVIVOR_DEFENSE := 200
const BORROWED_FACE := 300
const MONSTER_ABILITIES := 400
const FACILITY_MAP := 450
## ADR-0009 §3 (amends ADR-0005 §4): FacilityLighting, after MonsterAbilities and before Downing. Its own
## slot because Doors already holds FACILITY_MAP (one module per slot).
const FACILITY_LIGHTING := 460
const DOWNING := 500
const HOLDS := 550
## Footsteps (controller story 014): after every speed owner, so it reads this tick's moved bodies.
const FOOTSTEPS := 560
const SURVIVOR_OBJECTIVES := 600
const PINGS_CALLOUTS := 700
const SCARE_EVENTS := 800
const MATCH_FLOW_RESOLVE := 900
