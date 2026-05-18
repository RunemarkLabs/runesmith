# How-to: Migrate an Existing Workspace

You have a project folder that predates RuneSmith — maybe stuff at root, git repos in arbitrary places, notes scattered around. Goal: bring it into the canonical RuneSmith layout without losing any content.

For the target layout, see `docs/AGENT_PRIMER.md` ("Workspace structure").

## Prerequisites

- RuneSmith marketplace installed (specifically `runesmith-workspace` and `runesmith-cc`).
- Project folder mounted in Cowork.
- Optional: a backup of the current state somewhere outside the project folder. The skill snapshots, but defense-in-depth.

## What migration does

`/runesmith-workspace:reallocate` is idempotent. On a non-conforming workspace it:

1. **Snapshots first** — copies the entire current root state (minus already-canonical content) to `archive/_pre-migration/<ISO>/` so nothing is destroyed.
2. **Classifies root content** using the destination map in `plugins/runesmith-workspace/lib/folder-conventions.md`:
   - Loose `.md` files → routed to `notes/`, `drafts/`, or `_INBOX/` based on content shape
   - Loose `.json`/`.txt` files → `_INBOX/` for triage by the inbox skill
   - Image files → `_INBOX/` (or relevant `plans/active/<slug>/refs/` if you can identify the plan)
   - Existing git repos at root → migrated into `{PROJECT}.cc/<normalized-repo-name>/` (CC head territory)
   - Legacy `claude-code/` or `<old-name>.cc/` folders → renamed to current `{PROJECT}.cc/` convention
   - Already-canonical content (existing `plans/`, `notes/`, `drafts/`, etc.) → preserved in place
3. **Writes `STRUCTURE.md`** at workspace root documenting the canonical layout.
4. **Refreshes `CLAUDE.md`** marker blocks (folder-conventions + agent-ops) in place. Content outside the markers preserved.
5. **Surfaces a Project Instructions text block** for you to paste into Cowork's UI field.

## Steps

### 1. Snapshot manually (defense-in-depth)

Optional but recommended for non-trivial workspaces. Copy the entire project folder to a sibling backup location outside Cowork's mount:

```
cp -r ~/Projects/my-project ~/backups/my-project-pre-migration-$(date +%Y%m%d)
```

(Or use Windows File Explorer to duplicate.) Reallocate snapshots inside `archive/_pre-migration/` regardless; this is belt + suspenders.

### 2. Run reallocate

```
/runesmith-workspace:reallocate
```

Structured prompt — choose:
- **Preview diff first** (recommended for first run on a messy workspace). Shows the migration plan without writing.
- **Apply.** Performs the migration.
- **Cancel.** Bail out.

### 3. Review the preview (if you chose preview)

The skill outputs:
- Source root listing (what's there now)
- Destination map (what goes where)
- Conflicts or ambiguous items (with structured-prompt clarification needed)
- Snapshot target path

Look for anything weird:
- Unrecognized files routed to `_INBOX/` — fine, you'll classify with `/runesmith-workspace:inbox` later.
- Files routed to a wrong canonical home — comment on them in chat; the skill adapts.
- Git repos detected at root that you DON'T want migrated to CC head — say so; the skill leaves them alone.

If the plan looks right, re-run with **Apply**.

### 4. Apply the migration

Re-run with apply. The skill:
- Creates `archive/_pre-migration/<ISO>/` snapshot.
- Moves each classified item.
- Renames the CC head per the canonical naming rule (`<project-name>.cc/` — kebab-case-lowercase).
- Writes `STRUCTURE.md`.
- Refreshes `CLAUDE.md` markers.
- Emits a final report with the proposed Project Instructions text.

### 5. Paste Project Instructions

Copy the proposed text block from the final report. In Cowork: project settings → Instructions field → paste → save.

### 6. Bootstrap the CC head if needed

If you didn't have a CC head before migration, reallocate left a placeholder. Bootstrap it properly:

```
/runesmith-cc:bootstrap-cc
```

Detects the migrated repos in the placeholder, writes `CLAUDE.md`, `.claude/` scaffolding, `comms/`, marker file. See `docs/howto/new-workspace.md` step 4.

### 7. Inbox triage

`_INBOX/` likely has anything reallocate couldn't classify:

```
/runesmith-workspace:inbox
```

Walks each file, asks via structured prompt for ambiguous ones, routes per the destination map.

### 8. Optional: enable Atlassian

If this project should be wired to Jira + Confluence:

```
/runesmith-sprint:enable
```

See `docs/howto/enable-atlassian.md`.

### 9. Install the guardrail (one-time per machine, not per project)

If you haven't installed the user-level CC project-boundary guardrail yet:

```
/runesmith-cc:guardrail install
```

See `docs/howto/install-guardrail.md`. Protects this project + every other CC session on the machine.

## What stays where

The canonical layout in `docs/AGENT_PRIMER.md` shows the target. Migration preserves:

- Existing `.git/` directories — repos move into CC head as whole units, history intact.
- Existing `CLAUDE.md` — content outside the marker blocks is preserved. Skill content between markers is overwritten.
- Existing canonical folders (`plans/`, `notes/`, etc.) — preserved in place, not snapshotted, not duplicated.
- `.credentials` — preserved (already at workspace root).
- `.git/`, `.github/`, `node_modules/`, etc. — not touched by reallocate; those belong to nested repos or build tooling.

## What gets moved or renamed

- Loose root files (anything not on the canonical keep-list) → `_INBOX/` or their canonical home.
- Legacy `claude-code/` folder → `{PROJECT}.cc/`.
- Old `<old-name>.cc/` folder when the project name changed → `{PROJECT}.cc/`.
- Git repos at root → `{PROJECT}.cc/<normalized-name>/`.

## What gets deleted

Nothing. Reallocate is move-only. Every move snapshots to `archive/_pre-migration/<ISO>/` first.

## Verify after migration

```
ls
```

Root should show only:
- `_INBOX/`, `plans/`, `notes/`, `drafts/`, `research/`, `source-docs/`, `archive/`, `{PROJECT}.cc/`
- `CLAUDE.md`, `STRUCTURE.md`
- `.credentials` (gitignored)
- Standard repo files if this workspace itself is a git repo (`.gitignore`, etc.)

Anything else means reallocate had ambiguous cases it couldn't classify. Run `/runesmith-workspace:inbox` to clean up.

```
cat STRUCTURE.md
```

Should reflect the canonical layout with your project's specifics filled in.

```
cat CLAUDE.md
```

Should show the `<!-- folder-conventions:start/end -->` and `<!-- agent-ops:start/end -->` marker blocks populated. Any user content outside the markers is preserved.

## Rollback

If something went sideways, the snapshot is at `archive/_pre-migration/<ISO>/`. Manually move content back:

```
mv archive/_pre-migration/<ISO>/* ./
```

(Be careful — this is destructive in the other direction. Manual snapshot in step 1 is your real safety net.)

Once you've verified rollback worked, delete the snapshot to save space.

## Troubleshooting

**Reallocate refuses to move a file.** The destination is occupied. Resolve manually — either rename the existing file or the incoming one. Re-run reallocate.

**Git repo migration breaks remote tracking.** It shouldn't — git tracks remotes by `.git/config`, which travels with the repo. Verify: `cd {PROJECT}.cc/<repo>/ && git remote -v`. If empty, the move corrupted `.git/`. Restore from `archive/_pre-migration/<ISO>/<repo>/.git/` manually.

**CLAUDE.md user content got eaten.** Should never happen — markers are strict. If it did, the file at `archive/_pre-migration/<ISO>/CLAUDE.md` has the pre-migration state. Diff against current, restore the missing pieces, ensure they're outside any marker pair.

**`STRUCTURE.md` doesn't reflect my custom layout.** STRUCTURE.md is generated from `plugins/runesmith-workspace/lib/STRUCTURE.template.md` — it documents the canonical layout, not your specific deviations. If you have valid custom folders that aren't in the canonical set, document them outside the marker pair in `CLAUDE.md`.

**Reallocate ran but didn't migrate a repo I expected.** The skill only auto-migrates folders with a `.git/` directory directly under workspace root. Nested repos (e.g. `subdir/my-repo/.git/`) aren't auto-migrated — move them manually if needed, or use `/runesmith-cc:bootstrap-cc` to clone fresh.
