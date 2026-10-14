## QA Sign-Off Report: Sprint 001
**Date**: 2026-10-13. Reissued after the smoke re-run; the first issue was NOT ASSESSED because there was no launchable build.
**Config**: qa.level standard, team.size individual, automation autonomous. qa-lead drafted this report. The orchestrator checked the verdict against the /team-qa rules and agrees.

### Test Coverage Summary
| Story | Type | Auto Test | Manual QA | Result |
|-------|------|-----------|-----------|--------|
| data-config 001 knob section validation | Logic | PASS `tests/unit/data_config/knob_section_validation_test.gd` | n/a | PASS |
| data-config 002 sections and shipped files | Integration | PASS `tests/integration/data_config/shipped_knobs_test.gd` | n/a | PASS |
| event-catalog 001 server event catalog | Logic | PASS `tests/unit/event_catalog/server_event_catalog_test.gd` | n/a | PASS |
| event-catalog 002 event bus | Logic | PASS `tests/unit/event_catalog/event_bus_test.gd` | n/a | PASS |
| event-catalog 003 state registry | Logic | PASS `tests/unit/event_catalog/state_registry_test.gd` | n/a | PASS |
| event-catalog 004 composition root and tick order | Integration | PASS `tests/integration/event_catalog/tick_order_test.gd` | n/a | PASS |
| network-authority 004 tick runner | Logic | PASS `tests/unit/network/tick_runner_test.gd` | n/a | PASS |
| network-authority 005 input frames and queue | Logic | PASS `tests/unit/network/input_queue_test.gd` | n/a | PASS |
| network-authority 001 host, join, auth | Integration | PASS `tests/integration/network/host_join_auth_test.gd` (20 cases) | n/a | PASS WITH NOTES: not yet verified on two machines over WAN, the reject delay under real latency, NAT and IPv6, or an exported headless build |

- **Suite (2026-10-13)**: 123/123 tests pass in 10 suites, with 0 orphans. The tenth suite is the `/test-setup` scaffold `framework_smoke_test.gd`; no story owns it.
- **Smoke check**: PASS (`production/qa/smoke-2026-10-13.md`). The boot scene launches, and the screenshot is kept at `production/qa/evidence/boot-2026-10-13.png`. All four QA-plan smoke paths are confirmed. Menu, save and performance are N/A for this sprint.

### Bugs Found
| ID | Story | Severity | Status |
|----|-------|----------|--------|
| none | | | |

No bugs are on file (`production/qa/bugs/` does not exist), and none were filed this cycle.

### Verdict: APPROVED WITH CONDITIONS

**Conditions**:
1. Verify NA-1 on a real network before any milestone that needs online play: two machines over WAN, the reject delay under real latency, NAT and IPv6, and an exported headless build. Record it as a playtest or integration pass.
2. Code review was skipped for all 9 stories (lean mode). Either accept that risk or schedule a retroactive review.
3. Menu, session, save and performance become required smoke items in the sprint that adds each system.
4. File any defects under `production/qa/bugs/` with `/bug-report`.

### Next Step
Resolve the conditions before advancing. Carry conditions 1 to 3 into Sprint 2 planning.
