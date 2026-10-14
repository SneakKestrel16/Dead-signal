class_name MapPassage extends Resource
## One edge of the level doc's connectivity graph: a door, a barricadable door, an open archway, an
## open corridor junction or the final exit (research-facility.md "Connectivity Graph").
## Values come only from the map file (data/maps/).

const DOOR := &"door"
const BARRICADABLE := &"barricadable"
const ARCHWAY := &"archway"
const OPEN := &"open"
const EXIT := &"exit"

@export var id: StringName
## The two rooms it joins (connectivity-graph node names); `b` is &"Outside" for the exit.
@export var a: StringName
@export var b: StringName
## DOOR, BARRICADABLE, ARCHWAY, OPEN or EXIT.
@export var kind: StringName
## Centre of the opening at floor level.
@export var position: Vector3
## Clear width of the opening in metres.
@export var width_m: float
## Area a door leaf sweeps; a close is rejected while a capsule overlaps it (ADR-0007 §8). Zero size
## for openings without a leaf.
@export var swing_box: AABB


## True for a door that opens and closes (DOOR or BARRICADABLE): a map interactable (ADR-0008 §2).
func is_door() -> bool:
	return kind == DOOR or kind == BARRICADABLE
