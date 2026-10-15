extends GdUnitTestSuite
## BUG-0008: RoundClient.push_reduced_motion sets the setting on every HUD child that has the property
## (and skips the rest).


func test_push_sets_every_presenter_with_the_property_and_skips_others() -> void:
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	var cues := EdgeCues.new(Knobs.load_all(), Transform3D.IDENTITY.translated, func() -> bool: return true)
	var plain := Control.new()
	layer.add_child(cues)
	layer.add_child(plain)
	RoundClient.push_reduced_motion(layer, true)
	assert_bool(cues.reduced_motion).is_true()
	RoundClient.push_reduced_motion(layer, false)
	assert_bool(cues.reduced_motion).is_false()
