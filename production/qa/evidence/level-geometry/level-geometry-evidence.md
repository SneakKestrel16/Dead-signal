# Level geometry evidence (AD-249)

Runtime level geometry from `MapGreybox.build` (`src/core/facility/map_greybox.gd`), captured 2026-10-15 with
`tests/manual/round_host.gd` (headless, `--players=5`) and `tests/manual/round_view.tscn` (windowed,
`--write-movie`, `--count=5 --view=survivor`), ports 30110-30130.

| Shot | Run | What it shows |
|---|---|---|
| `corridor.png` | `--bot=walk --light`, link.png renamed | H-S corridor looking east: both walls, ceiling, floor, the far end |
| `archway.png` | `--bot=walk --light`, zone_a.png renamed | A1 from its spawn: walls and ceiling, the A1-H-S archway opening (left) |
| `doorway.png` | `--yaw=-90 --pitch=-5 --light --shot-at=400` | A1 looking east: open doorways with their door posts, walls, ceiling |
| `glass.png` | `--yaw=-90 --pitch=-5 --shot-at=400`, host `--force=2:anchor` (re-shot without `--light`) | From A3 at (9.5, 21.5) east through the A2/A3 glass (tinted lower half): the A2 spine, the A2/A4 glass and lab A4 with its markers behind |

Known limits: door leaves are not drawn (door state is not applied to physics or visuals at runtime).

- [ ] Lead sign-off
