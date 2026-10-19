# Asset Manifest

> Last updated: 2026-10-18

Status sources: Done = built and in the game (commits 19885cb dressing, 6bfe46d level geometry, 81ef3ee VFX,
2a8ba44 objective glows, 8d16dfe true form, and the character and props art passes). Approved = designer sign-off on
record: the facility rooms (`production/qa/evidence/facility-detail.md`, 2026-10-17, "the facility looks good")
and the true form (`design/art/true-form-review.md` round 9, 2026-10-18). ASSET-087 is Done as hud.md H13's world
progress bars (`src/feature/hud_results/world_progress.gd` server side, `world_progress_bars.gd` client; story
hud-results/005): every real hold and the activation countdown, survivors only, never hiding or fake holds. The
greybox text bar became a drawn bar (`spatial_ui_world_progress.gdshader`) on 2026-10-18
(`production/qa/evidence/world-progress-bar-art-2026-10-18.png`).

## Progress Summary

| Total | Needed | In Progress | Done | Approved |
|-------|--------|-------------|------|----------|
| 87 | 0 | 0 | 69 | 18 |

## Assets by Context

### Character: survivors, shapeshifter, held items
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-001 | Survivor shared body | 3D character | Done | design/assets/specs/characters-assets.md |
| ASSET-002 | Survivor look C1 (Bone) | Character look | Done | design/assets/specs/characters-assets.md |
| ASSET-003 | Survivor look C2 (Safety Yellow) | Character look | Done | design/assets/specs/characters-assets.md |
| ASSET-004 | Survivor look C3 (Cobalt) | Character look | Done | design/assets/specs/characters-assets.md |
| ASSET-005 | Survivor look C4 (Rust Orange) | Character look | Done | design/assets/specs/characters-assets.md |
| ASSET-006 | Survivor look C5 (Violet) | Character look | Done | design/assets/specs/characters-assets.md |
| ASSET-007 | Retro-reflective stripe material | Material | Done | design/assets/specs/characters-assets.md |
| ASSET-008 | Survivor animation set | Animation | Done | design/assets/specs/characters-assets.md |
| ASSET-009 | Shapeshifter true form | 3D character | Approved | design/assets/specs/characters-assets.md |
| ASSET-010 | True form animations | Animation | Done | design/assets/specs/characters-assets.md |
| ASSET-011 | First-person arms (viewmodel) | 3D character | Done | design/assets/specs/characters-assets.md |
| ASSET-012 | Flashlight | 3D prop | Done | design/assets/specs/characters-assets.md |
| ASSET-013 | Taser | 3D prop | Done | design/assets/specs/characters-assets.md |
| ASSET-014 | Taser darts and wires | 3D prop | Done | design/assets/specs/characters-assets.md |

### Level: research-facility
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-015 | Trim: concrete / wall base | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-016 | Trim: metal / door frames | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-017 | Trim: glass / mullion | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-018 | Trim: floor markings / pipes | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-019 | Tileable: floor tile | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-020 | Tileable: concrete | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-021 | Tileable: painted block | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-022 | Tileable: steel plate | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-023 | Tileable: ceiling panel | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-024 | Tileable: rubber matting | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-025 | Tileable: checker plate | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-026 | Tileable: server rack face | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-027 | Tileable: metal grate | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-028 | Decal set | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-029 | Room and zone signage | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-030 | Corridor floor stripes | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-031 | A1 Entry / Decon | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-032 | A2 Lab Spine | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-033 | A3 Wet Lab | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-034 | A4 Specimen Lab | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-035 | A5 Cold Storage | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-036 | A6 Director's Office | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-037 | A7 Observation Gallery | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-038 | H-N North Service Corridor | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-039 | H-S South Service Corridor | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-040 | B1 Server Hall | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-041 | B2 Power Room | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-042 | B3 Cooling Plant | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-043 | C1 Security Office | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-044 | C2 Checkpoint | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-045 | C3 Records Archive | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-046 | C4 Evacuation Hall | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-047 | C5 Backup Control | Environment | Approved | design/assets/specs/research-facility-assets.md |
| ASSET-048 | Ordinary door | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-049 | Barricadable door | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-050 | Open archway | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-051 | Glass partition | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-052 | Hiding lab cabinet | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-053 | Hiding storage locker | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-054 | Data drive | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-055 | Breaker wall | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-056 | Fuse | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-057 | Fuse box | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-058 | Evacuation terminal (T1-T3) | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-059 | Exit door E and chevron frame | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-060 | The Core | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-061 | Monitor wall and C1 station | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-062 | Backup controls panel | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-063 | Backup light switch | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-064 | Surveillance camera | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-065 | Monitor feed screen material | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-066 | PA speaker with light | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-067 | Lab dressing set | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-068 | Server, power and cooling dressing | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-069 | Security dressing | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-070 | Lab panel lights (Zone A) | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-071 | Equipment glow (Zone B) | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-072 | Security lights (Zone C) | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-073 | Emergency floor strips and exit signage | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-074 | Evacuation beacons (amber) | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-075 | C4 evacuation beacon (red) | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-076 | Alarm strobe | Environment | Done | design/assets/specs/research-facility-assets.md |
| ASSET-077 | Lighting presets | Environment | Done | design/assets/specs/research-facility-assets.md |

### System: VFX
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-078 | Transformation warp | VFX | Done | design/assets/specs/vfx-assets.md |
| ASSET-079 | Reveal flare | VFX | Done | design/assets/specs/vfx-assets.md |
| ASSET-080 | Taser arc | VFX | Done | design/assets/specs/vfx-assets.md |
| ASSET-081 | Stun-resisted spark | VFX | Done | design/assets/specs/vfx-assets.md |
| ASSET-082 | Fuse install sparks | VFX | Done | design/assets/specs/vfx-assets.md |
| ASSET-083 | Door-burst debris and dust | VFX | Done | design/assets/specs/vfx-assets.md |
| ASSET-084 | Glass shards | VFX | Done | design/assets/specs/vfx-assets.md |
| ASSET-085 | Lunge impact | VFX | Done | design/assets/specs/vfx-assets.md |
| ASSET-086 | Drive and exit glow | VFX | Done | design/assets/specs/vfx-assets.md |
| ASSET-087 | World progress ring | VFX | Done | design/assets/specs/vfx-assets.md |
