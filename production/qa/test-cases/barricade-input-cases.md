# Test cases: SD-14 barricade input (secondary interact)

**Story**: `production/epics/survivor-defense/story-014-barricade-input.md` | **Type**: Integration | **Gate**: BLOCKING
**Evidence**: automated. There is no evidence page.

Every AC is proven by automated tests. No manual case is needed:

- AC1, the alt bit resolves to Barricade, Remove or Break, and the door toggle otherwise: `hold_service_start_test.gd`.
- AC2, barricade, remove and break over real ENet: `tests/integration/match-flow/client_round_scene_test.gd::test_interact_alt_barricades_removes_and_breaks_while_interact_toggles`.
- AC3, the toggle on the press tick: the same integration test. This is server-side only, because the client draws no door state yet.
- AC4, byte cap and bit validation: `input_queue_test.gd`.

Open for the designer (AD-219), not a test: whether G is the right binding, and whether an alt press with no alt hold should fall back to interact.
