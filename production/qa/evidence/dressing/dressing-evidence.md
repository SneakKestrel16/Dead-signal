# Evidence: dressing sets, decals, signage and fixtures (ASSET-028..030, 067..076)

Spec: `design/assets/specs/research-facility-assets.md`; art bible §3, §4, §6, §8.
Built by `tools/art/build_dressing.py` (Blender 5.2, background). Each PNG is a Cycles render of one item in
near-dark (ambient `#14181A`) under one warm `#F2E6C8` spot from about eye height (fixtures hung at 2 m).

| Set | Item | Tris (budget) |
|---|---|---|
| lab (067) | bench 368, desk 304, chair 288, fridge 220, monitor 156, binders 132 | 1500 each |
| server/cooling (068) | rack 92, rack row w5 736, rack row w4 552, cable bundle 540, pipes 252, pump 244, fan 200 | 1500 each |
| security (069) | gate arm 164, log screen 184, shelving 724, file boxes 156 | 1500 each |
| fixtures (070-076) | panel 24, cage 156, emergency strip 24, beacon 132, red beacon 140, strobe 56 | 300 each |

Placement, clearances, density, colours and fixture positions: `tests/unit/facility-map/map_dressing_test.gd`.
In-game screenshots: still to be taken (no windowed run allowed in this session).

- [ ] Lead sign-off (art-director)
