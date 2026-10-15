class_name HandleMirror extends HandleTable
## One viewer's handles, presented as another's (ADR-0004 §8): a spectator receives the stream projected
## for the survivor it watches, so event projection runs as that survivor while every handle lookup
## uses the spectator's own handles. Only the lookups projection uses (has, handle_for) are mirrored:
## pass a mirror to EventBatch.build only. Projections call handle_for only after has(), so it issues
## nothing (an issue here would queue its INTRODUCE after this tick's take()).
## Usage: `EventBatch.build(tick, watched, events, sounds, pos, HandleMirror.new(handles, spectator), monster)`

var _table: HandleTable
var _viewer: int


func _init(table: HandleTable, viewer: int) -> void:
	super()
	_table = table
	_viewer = viewer


## The mirrored viewer's handle for `body`, issuing one when new (`_as` is ignored).
func handle_for(_as: int, body: int) -> int:
	return _table.handle_for(_viewer, body)


## True while the mirrored viewer holds a live handle for `body` (`_as` is ignored).
func has(_as: int, body: int) -> bool:
	return _table.has(_viewer, body)
