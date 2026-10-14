## Technical Debt Register
Last updated: 2026-10-13
Total items: 4 | Estimated total effort: S + S + M + S

| ID | Category | Description | Files | Effort | Impact | Priority | Status | Added | Sprint |
|----|----------|-------------|-------|--------|--------|----------|--------|-------|--------|
| TD-001 | Architecture | 10 NetKnobs have no number in any ADR (input_queue_cap, max_seq_ahead, starvation_high, starvation_low, slack_ticks, port, max_clients, auth_timeout, payload size cap, ENet timeout), so they have no field. Add the field and value when network-authority stories 001, 003 and 005 settle them — from data-config/story-002 | src/foundation/data_config/net_knobs.gd, data/knobs/net.tres | S | Med | — | Open | 2026-10-13 | Backlog |
| TD-002 | Architecture | 4 FacilityKnobs fields wait on ADR-0009's spike (light_fade_s, max_shadowed_omni, max_shadowed_spot, max_shadowed_flashlights, feed_resolution): only max_flashes_per_s ships — from data-config/story-002 | src/foundation/data_config/facility_knobs.gd, data/knobs/facility.tres | S | Low | — | Open | 2026-10-13 | Backlog |
| TD-003 | Test | Shipped knob numbers are not compared with the GDD default column, so a typo inside a field's range passes; the GDD coverage test also lacks the reverse check (every field traces to a GDD or ADR) and a per-GDD row minimum — from data-config/story-002 code review | tests/integration/data_config/shipped_knobs_test.gd | M | Med | — | Open | 2026-10-13 | Backlog |
| TD-004 | Dependency | No export_presets.cfg in the repo (gitignored repo-wide); the data/knobs include filter is documented in the README and verified only in a scratch export. Add a test that parses a preset, or un-ignore a project preset — from data-config/story-002 | src/foundation/data_config/README.md | S | Med | — | Open | 2026-10-13 | Backlog |
