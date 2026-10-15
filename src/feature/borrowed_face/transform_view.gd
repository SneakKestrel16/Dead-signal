class_name TransformView extends RefCounted
## Read-only view of the Transforming flag (StateKeys.TRANSFORMING; borrowed-face.md rule 8; ADR-0005 §3),
## registered by BorrowedFace.setup. Readers: Monster Abilities (no ability while Transforming, Lunge
## needs true form), the Controller (walk-only, interaction rejected), Pings, Survivor Defense.
## Getters only (state_registry_test scans every *_view.gd). Holds the module weakly; after it is
## freed the view reads true form, not transforming.
## Usage: `var v := registry.view(StateKeys.TRANSFORMING, TransformView) as TransformView`

var _bf: WeakRef


func _init(bf: BorrowedFace) -> void:
	_bf = weakref(bf)


## True while a transformation is in progress.
func get_transforming() -> bool:
	var bf := _bf.get_ref() as BorrowedFace
	return bf.transforming() if bf != null else false


## Target form of the transformation in progress; meaningless when not transforming.
func get_target() -> int:
	var bf := _bf.get_ref() as BorrowedFace
	return bf.transform_target() if bf != null else BorrowedFace.TRUE_FORM


## Current form: BorrowedFace.TRUE_FORM or the copied survivor's id. Inference: carried here so the
## Lunge gate reads one view; StateKeys.SHAPESHIFTER_FORM (story 007) is its own row, and Monster
## Abilities may read that instead once it exists.
func get_form() -> int:
	var bf := _bf.get_ref() as BorrowedFace
	return bf.form() if bf != null else BorrowedFace.TRUE_FORM
