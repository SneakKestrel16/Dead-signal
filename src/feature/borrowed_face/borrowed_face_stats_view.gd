class_name BorrowedFaceStatsView extends RefCounted
## Round stats owned by Borrowed Face (StateKeys.STATS_BORROWED_FACE, ADR-0011 §1-2). Getters only.
## This base reads zero: the contract Borrowed Face's stats story subclasses (holding the module
## weakly), and what MatchFlow reads while no view is registered.


## Form changes the shapeshifter made.
func get_form_changes() -> int:
	return 0
