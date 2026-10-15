class_name BorrowedFaceRoundStatsView extends BorrowedFaceStatsView
## Borrowed Face's live round stats under StateKeys.STATS_BORROWED_FACE (story match-flow/014, ADR-0011
## §1-2), registered by BorrowedFace.setup. Getters only. Holds the module weakly; after it is freed reads 0.

var _bf: WeakRef


func _init(bf: BorrowedFace) -> void:
	_bf = weakref(bf)


func get_form_changes() -> int:
	var bf := _bf.get_ref() as BorrowedFace
	return bf.form_changes() if bf != null else 0
