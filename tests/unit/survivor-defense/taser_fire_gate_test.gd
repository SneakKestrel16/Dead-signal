# Story survivor-defense/015: the shipped client's use_item gate (design/gdd/survivor-defense.md rules 7, 8
# and the 0-cartridge edge case; ADR-0014 §1 actions flag). Sends only with a cartridge and an
# actions-allowing context on top; the server still decides every shot.
extends GdUnitTestSuite


func test_gameplay_with_a_cartridge_fires() -> void:
	assert_bool(RoundClient.may_fire(InputContextStack.new(), 1)).is_true()
	assert_bool(RoundClient.may_fire(null, 1)).override_failure_message("no UI (bot client): ungated").is_true()


func test_wheel_overlay_menu_and_modal_block() -> void:
	for ctx: InputContextStack.Ctx in [InputContextStack.Ctx.WHEEL, InputContextStack.Ctx.OVERLAY,
			InputContextStack.Ctx.MENU, InputContextStack.Ctx.MODAL]:
		var s := InputContextStack.new()
		s.push(ctx, null)
		assert_bool(RoundClient.may_fire(s, 2)).override_failure_message(str(ctx)).is_false()
		s.pop(ctx)
		assert_bool(RoundClient.may_fire(s, 2)).is_true()


func test_no_taser_or_no_cartridge_blocks() -> void:
	# -1: no CHARGES entry yet (the shapeshifter's client never gets one); 0: edge case "input ignored".
	assert_bool(RoundClient.may_fire(InputContextStack.new(), -1)).is_false()
	assert_bool(RoundClient.may_fire(InputContextStack.new(), 0)).is_false()
