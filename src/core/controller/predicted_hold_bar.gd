class_name PredictedHoldBar extends ProgressBar
## The owner's predicted hold bar (ADR-0008 §8; first-person-controller.md Acceptance Criteria, Feel).
## Greybox: the final look belongs to the HUD epic. Client side only; HoldService is the one timer, and
## this bar never feeds anything back (manifest: owner_timed_hold).
## It appears on the press tick when the local target query found a target, so it does not wait a
## round trip. Until the server acknowledges the press seq it advances one tick per physics tick. The
## first own snapshot whose seq acknowledges the press decides: no hold (or a hold on another
## interactable) hides it with the value it had, so a rejection never shows server progress; a hold
## sets it to the server's elapsed ticks plus the frames sent since that seq. Release hides it at once
## (the server stops every hold on release, ADR-0008 §3).
## Usage, once per physics tick on the owner's client:
##   bar.advance(frame, local_target_found, target_duration_s)   # after OwnerPredictor.predict(frame)
##   bar.on_snapshot(predictor.last_own)                      # own entry of the newest snapshot

var _ticks_per_s: int
var _was_down := false
var _active := false
## Net id the press targeted, or -1 for a body target (a handle the server resolves: any hold matches).
var _net_id := -1
var _press_seq := 0
var _last_seq := 0
var _elapsed := 0
var _duration := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE ## gotchas.md: a STOP control at the centre eats look
	show_percentage = false
	max_value = 1.0
	step = 0.0
	visible = false


## Reads the tick rate that converts the target's duration_s to ticks (Knobs.ticks).
func setup(knobs: Knobs) -> void:
	_ticks_per_s = knobs.net.sim_tick_hz


## One physics tick: `f` is the frame just predicted (seq stamped). On a rising edge, `target_found` and
## `duration_s` describe what the local target query found; an instant (duration 0) shows no bar.
func advance(f: InputFrame, target_found: bool, duration_s: float) -> void:
	if not f.interact:
		_was_down = false
		_hide()
		return
	if not _was_down:
		_was_down = true
		_hide()
		var ticks := roundi(duration_s * _ticks_per_s)
		if target_found and ticks > 0:
			_active = true
			_net_id = -1 if f.target_is_body else f.interact_target
			_press_seq = f.seq
			_elapsed = 0
			_duration = ticks
	if _active:
		_last_seq = f.seq
		_elapsed += 1
		_show()


## Applies the own snapshot entry ({seq, hold_net_id, hold_elapsed_ticks}). Entries that do not yet
## acknowledge the press are ignored.
func on_snapshot(own: Dictionary) -> void:
	if not _active or own.is_empty() or own.seq < _press_seq:
		return
	var held: int = own.get("hold_net_id", -1)
	if held < 0 or (_net_id >= 0 and held != _net_id):
		_hide()
		return
	_elapsed = own.hold_elapsed_ticks + maxi(_last_seq - own.seq, 0)
	_show()


func _show() -> void:
	value = minf(float(_elapsed) / _duration, 1.0)
	visible = true


func _hide() -> void:
	_active = false
	visible = false
