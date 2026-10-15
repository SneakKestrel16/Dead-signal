# Story survivor-defense/011: the placeholder audio sink that plays the shock cues and the server's
# positional sounds (hide_enter, hide_exit, hide_cue; survivor-defense.md Visual/Audio Requirements).
# No audio assets exist: every sound is the same placeholder beep, recorded for checks.
extends GdUnitTestSuite


func test_sound_entries_play_at_their_position_and_bad_ones_are_dropped() -> void:
	var a: PlaceholderAudio = auto_free(PlaceholderAudio.new())
	a.on_sound(5, {"pos": Vector3(1, 0, 2), "set": HidingSpots.ENTER_SOUND})
	a.on_sound(5, {"pos": "x", "set": HidingSpots.EXIT_SOUND})
	a.on_sound(5, {"pos": Vector3.ZERO})
	a.play_at(HidingSpots.CUE_SOUND, Vector3(3, 0, 0))
	assert_array(a.played).is_equal([[HidingSpots.ENTER_SOUND, Vector3(1, 0, 2)],
			[HidingSpots.CUE_SOUND, Vector3(3, 0, 0)]])
	assert_int(a.rejected).is_equal(2)
	assert_int(a.get_child_count()).is_equal(2)
	assert_object((a.get_child(0) as AudioStreamPlayer3D).stream).is_not_null()


func test_played_log_is_capped() -> void:
	var a: PlaceholderAudio = auto_free(PlaceholderAudio.new())
	for i in PlaceholderAudio.LOG_CAP + 5:
		a.play_at(&"hide_cue", Vector3(i, 0, 0))
	assert_int(a.played.size()).is_equal(PlaceholderAudio.LOG_CAP)
	assert_array(a.played[-1]).is_equal([&"hide_cue", Vector3(PlaceholderAudio.LOG_CAP + 4, 0, 0)])
