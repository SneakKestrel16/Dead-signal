# Epic: Pings & Callouts

> **Layer**: Feature
> **GDD**: design/gdd/pings-and-callouts.md
> **Architecture Module**: Pings & Callouts (`docs/architecture/architecture.md` Feature layer)
> **Status**: Ready
> **Stories**: 9 stories, see the Stories table below

## Overview

This epic gives survivors a way to share information without voice chat. A ping puts a short-lived marker on a point, an object or a player. A callout plays one of eight authored voice lines from the speaker's position and adds a line to a text feed. Every ping and callout is a client request that the server validates (alive, not blocked, rate limit, range, line of sight). The server attaches the sender's displayed identity from the disguise state, never from the client. A disguised shapeshifter can use the same tools, and its fakes look exactly like the real thing on the wire and on screen, so a ping is evidence, not proof. The module owns ping tokens, callout cooldowns, markers and identity attribution. Proximity voice (TR-pings-007, TR-pings-010) is optional and its transport is undecided; this epic stories only the voice rules that need no transport (no rule requires voice), and leaves the transport post-MVP.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Authoritative simulation, tick rate and input | Pings and callouts are client intents; the server validates and owns all state | HIGH |
| ADR-0004: Replication scope and information hiding | Per-recipient filtering; no real/fake tag on the wire | HIGH |
| ADR-0005: Event catalog, state registry and tick order | Presentation messages per recipient; reads `AbilityUsed`, disguise state | HIGH |
| ADR-0006: Data-driven configuration | Rate limits, ranges, lifetimes as knobs | MEDIUM |
| ADR-0013: Spatial audio pipeline | Callout lines positional with wall attenuation; voice bus | MEDIUM |
| ADR-0014: UI and input focus | Ping input, marker and feed presentation | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-pings-001 | Server-validated request (alive, state, rate, 40 m range, LOS); sender identity from server-side disguise state | ADR-0002, ADR-0004 (inferred; registry untraced) |
| TR-pings-002 | Per-recipient filtering: survivors, monster only with LOS to target, spectators mirror; rejected ping to monster gives no signal | ADR-0004 (inferred; registry untraced) |
| TR-pings-003 | Token bucket (3, 2 s refill), callout cooldown 3 s, per-line repeat block 8 s; reconnect keeps bucket; fakes touch no limit state | ❌ No ADR |
| TR-pings-004 | 8 callout lines, voice set per character, 25 m (Need rescue 40 m), positional audio, feed + arrow to survivors, audio only to monster | ADR-0014 ✅ |
| TR-pings-005 | Marker types, static, max 2 per sender, 8 s lifetime, through walls with direction and distance; pingable-object registry | ADR-0014 ✅ |
| TR-pings-006 | Fake callout parity; "(not you)" mark; no real/fake tag on the wire | ❌ No ADR |
| TR-pings-007 | Optional proximity voice rules; no rule may require voice | ADR-0013 ✅ |
| TR-pings-008 | Blocking states (true form, transforming, shock lock, hidden peek, Downed subset, Seized) | ❌ No ADR |
| TR-pings-009 | Display identity from disguise state; duplicates shown, not merged | ❌ No ADR |
| TR-pings-010 | Voice transport undecided; post-MVP | ❌ No ADR (deferred) |

Untraced requirements are informational at `workflow: standard`. The ADR column's "inferred" rows are the orchestrator's reading of which accepted ADR governs them; the TR registry does not list them yet.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/pings-and-callouts.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Ping module, request validation and token bucket | Logic | Complete | ADR-0002 |
| 002 | Sender-state gating for pings and callouts | Logic | Ready | ADR-0005 |
| 003 | Callout acceptance limits and attached item ping | Logic | Ready | ADR-0002 |
| 004 | Ping recipients and per-peer delivery | Integration | Ready | ADR-0004 |
| 005 | Marker lifecycle: static position, lifetime and max active | Logic | Ready | ADR-0014 |
| 006 | Callout recipients, range and monster audio-only | Integration | Ready | ADR-0004 |
| 007 | Displayed identity, (not you) mark and fake-callout parity | Integration | Ready | ADR-0004 |
| 008 | Ping input, marker display, callout wheel and feed | UI | Ready | ADR-0014 |
| 009 | Optional proximity voice rules | Integration | Blocked | ADR-0013 |

## Next Step

Run `/create-stories pings-and-callouts` to break this epic into implementable stories.
