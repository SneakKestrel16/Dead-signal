class_name StateKeys extends RefCounted
## Registry keys for StateRegistry (ADR-0005): one constant per row of the state table in
## design/gdd/systems-index.md, section "Read-only replicated state", in table order.
## Usage: `registry.view(StateKeys.DOOR_STATE, DoorStateView)`.

## Row "Shapeshifter form".
const SHAPESHIFTER_FORM := &"shapeshifter_form"
## Row "Transforming flag".
const TRANSFORMING := &"transforming"
## Row "Takedown eligibility".
const TAKEDOWN_ELIGIBILITY := &"takedown_eligibility"
## Row "Player positions and life states".
const PLAYER_POSITIONS_LIFE_STATES := &"player_positions_life_states"
## Row "`blackout_able` per lighting volume".
const BLACKOUT_ABLE := &"blackout_able"
## Row "Lighting state per volume".
const LIGHTING_STATE := &"lighting_state"
## Row "Door open/closed state".
const DOOR_STATE := &"door_state"
## Row "Barricade state".
const BARRICADE_STATE := &"barricade_state"
## Row "Hidden and item-use state".
const HIDDEN_ITEM_USE := &"hidden_item_use"
## Row "Lunge state".
const LUNGE_STATE := &"lunge_state"
## Row "Committing state".
const COMMITTING_STATE := &"committing_state"
## Row "Shock/stun lock".
const SHOCK_STUN_LOCK := &"shock_stun_lock"
## Row "Movement modifiers".
const MOVEMENT_MODIFIERS := &"movement_modifiers"
## Row "Camera flinch toggle".
const CAMERA_FLINCH_TOGGLE := &"camera_flinch_toggle"
## Row "View offset".
const VIEW_OFFSET := &"view_offset"
## Row "Player roster".
const PLAYER_ROSTER := &"player_roster"
## Row "Round stats `stats.downing`".
const STATS_DOWNING := &"stats_downing"
## Row "Round stats `stats.abilities`".
const STATS_ABILITIES := &"stats_abilities"
## Row "Round stats `stats.defense`".
const STATS_DEFENSE := &"stats_defense"
## Row "Round stats `stats.borrowed_face`".
const STATS_BORROWED_FACE := &"stats_borrowed_face"
## Row "Round stats `stats.objectives`".
const STATS_OBJECTIVES := &"stats_objectives"
## Row "Round stats `stats.match`".
const STATS_MATCH := &"stats_match"
