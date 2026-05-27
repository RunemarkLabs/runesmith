# Build, audit, dist

Every marketplace needs three scripts and three conventions. This file describes what they do and why.

## `scripts/audit.py`

Build this first. It catches every class of pitfall before you push. Required checks:

| Check | Catches |
|---|---|
| `check_marketplace_json()` | Missing `name`/`owner`/`plugins`; bad plugin entries |
| `check_plugin_manifests()` | Missing required fields; name mismatches folder |
| `check_dependency_dag()` | Cyclic plugin dependencies (if you use deps - we don't, see forbidden fields) |
| `check_skill_frontmatter()` | Missing `name`/`description`; name mismatches folder |
| `check_forbidden_patterns()` | Angle-bracket placeholders in body, plain-text yes/no prompts, brand-specific anti-patterns |
| `check_frontmatter_placeholders()` | Angle-bracket placeholders in SKILL.md frontmatter or plugin.json description |
| `check_command_descriptions()` | `commands/*.md` descriptions too short or truncated at placeholder boundary |
| `check_forbidden_plugin_fields()` | `dependencies` and other non-schema fields in plugin.json |
| `check_no_emdashes()` | Byte-level em-dash/en-dash scan across `.md`/`.json`/`.ps1`/`.sh`/`.py`/`.txt`/`.xhtml`/`.yml`/`.yaml` |
| `check_no_emdash_json_escapes()` | JSON-decode then scan parsed strings for U+2014/U+2013 (catches escapes the byte scan misses) |
| `check_references()` | Broken `lib/x.md` and `agents/x.md` references in SKILL.md |

Exit code 0 = pass, 1 = fail with line-numbered errors. Run before every build, before every push, and in CI.

Use the runesmith `scripts/audit.py` as a reference implementation. Strip checks that don't apply to your marketplace; never add a check unless you have a real failure mode it catches.

## `scripts/build.py`

Produces `.plugin` zip files (one per plugin) in `dist/`. Each `.plugin` is a zip of the plugin folder containing `.claude-plugin/`, `skills/`, `lib/`, `commands/`, `templates/`, etc.

Cowork installs from `.plugin` URLs (drag-and-drop into the sidebar) or directly from the marketplace.json `source` paths in a git repo.

Build script responsibilities:
- Exclude development artifacts (`__pycache__`, `.pytest_cache`, `.git`).
- Use forward-slash separators in the zip (matters for cross-platform install).
- Write to `dist/{plugin-name}.plugin` per plugin.
- Print the file size of each plugin so you can spot bloat.

## `CHANGELOG.md`

Keep one. Every plugin or marketplace version bump gets an entry. Format follows Keep a Changelog.

Useful sections per entry:
- **Added** - new skills, lib files, commands.
- **Changed** - breaking changes; user-facing behavior shifts.
- **Fixed** - bug fixes with the symptom + root cause.
- **Removed** - retired features.
- **Why** - one paragraph context for non-obvious changes.
- **Versions** - which plugin.json files moved, which marketplace.json version landed.
- **Upgrade path** - what users need to do to migrate.

Be honest about what was a fix vs what was a red herring. Future-you debugging the next dispatch failure will thank you.

## `.gitignore`

Always gitignore:
- `dist/` - build outputs.
- `.credentials` - never commit secrets.
- Workspace drop zones (`_INBOX/*` if your skills use one).
- Operation snapshots (`archive/_pre-*/` if your skills snapshot before mutation).
- `__pycache__/`, `*.pyc`, `.pytest_cache/` - standard Python ignores if you have Python scripts.

## Versioning

Plugin and marketplace versions use SemVer:

- **Patch (0.8.0 -> 0.8.1):** non-breaking bug fixes, doc updates, internal refactors.
- **Minor (0.8.0 -> 0.9.0):** new skills, new features, backward-compatible changes.
- **Major (0.x -> 1.0):** breaking changes to skill behavior, plugin schema, or user-facing workflow.

**Per-plugin versioning, not blanket bumps (HARD RULE).** Each plugin gets its own independent SemVer track. When a release touches `runesmith-workspace` and `runesmith-devtools` but not the other six plugins, ONLY those two bump. The unchanged plugins stay at their current version.

Wrong (do not do this):
```
v0.7.3: all 8 plugin.json bumped to 0.7.3
```

Right:
```
v0.8.1: runesmith-workspace 0.8.0 -> 0.8.1, runesmith-devtools 0.8.0 -> 0.8.1, other six unchanged
```

Why: each plugin is independently installable. A user installing one plugin should see the version that reflects that plugin's actual change history, not the marketplace-wide release counter. Blanket-bumping breaks the contract.

**Marketplace SemVer is independent.** Convention: bump marketplace `metadata.version` whenever any plugin inside bumps, tracking the highest plugin version. So if any plugin moves to 0.8.1, marketplace moves to 0.8.1.

**Description prefix carries the version.** Cowork's plugin directory UI shows the description but not the version field. Lead the description with the version: `"[MarketplaceName vX.Y.Z] {existing description}"`. Update both `plugin.json` and the corresponding `marketplace.json` plugin entry when the version bumps. A `scripts/bump-version.py` that updates all locations atomically for a single plugin is recommended.

Per-bump checklist:
1. Update the plugin's `plugin.json` `version` field.
2. Update the plugin's `plugin.json` `description` prefix to the new version.
3. Update the corresponding entry in `marketplace.json` `plugins[]` - same description prefix.
4. Update `marketplace.json` `metadata.version` to the new highest version across all plugins.
5. Add a CHANGELOG entry listing ONLY the plugins that actually moved.
6. Run audit + build.

## Pre-flight before push

1. `python scripts/audit.py` from repo root - must exit 0.
2. `python scripts/build.py` - must succeed, all `.plugin` files written.
3. Test-install one of the changed plugins locally. Drag the `.plugin` into Cowork. Try the skill. Confirm it dispatches.
4. CHANGELOG entry present?
5. Version bumps in `plugin.json` AND `marketplace.json`?
6. Commit message describes the user-facing change, not the file list.

Only then ship.
