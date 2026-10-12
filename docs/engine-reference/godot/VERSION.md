# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.7.2 |
| **Installed at pin time** | 4.7.2.stable.official.ed1daf0bf — matches the pin (winget install, not on PATH; path in `project.yaml` `engine.path`) |
| **Release Date** | 4.7.2: 2026-08-18 per a third-party timeline (not confirmed on godotengine.org). 4.7 stable: ~June 2026, inferred from RC2 on 2026-06-12 |
| **Project Pinned** | 2026-10-11 |
| **Last Docs Verified** | 2026-10-11 (4.6 → 4.7 migration guide); older spans 2026-02-12 |
| **LLM Knowledge Cutoff** | May 2025 |

## Knowledge Gap Warning

The LLM's training data likely covers Godot up to ~4.3. Versions 4.4 through
4.7 introduced significant changes that the model does NOT know about.
Always cross-reference this directory before suggesting Godot API calls.

## Installed-Version Gap Warning

The warning above is one-directional — it covers the **model** knowing less than
this pin. The reverse gap is real and `/setup-engine` §3 creates it deliberately
("pin the newer one and upgrade later"): this reference can sit **ahead of the
installed editor**, and an agent citing it correctly then emits APIs that do not
compile locally. **Check `Installed at pin time` above before trusting a
version-qualified claim** — `NOT DETERMINED` means the gap is unknown, not absent.

## Post-Cutoff Version Timeline

| Version | Release | Risk Level | Key Theme |
|---------|---------|------------|-----------|
| 4.4 | ~Mid 2025 | MEDIUM | Jolt physics option, FileAccess return types, shader texture type changes |
| 4.5 | ~Late 2025 | HIGH | Accessibility (AccessKit), variadic args, @abstract, shader baker, SMAA |
| 4.6 | Jan 2026 | HIGH | Jolt default, glow rework, D3D12 default on Windows, IK restored |
| 4.7 | ~Jun 2026 | HIGH | Typed-return override inheritance, input device IDs, audio `area_mask` default, Jolt soft-body/plane fixes |

## Verified Sources

- Official docs: https://docs.godotengine.org/en/stable/
- 4.6→4.7 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html
- 4.5→4.6 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.4→4.5 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- 4.7.1 maintenance release: https://godotengine.org/article/maintenance-release-godot-4-7-1/
- 4.7.2 release date (third-party): https://gamedev.net/news/5172-godot-engine-472-stable-released/
- Changelog: https://github.com/godotengine/godot/blob/master/CHANGELOG.md
