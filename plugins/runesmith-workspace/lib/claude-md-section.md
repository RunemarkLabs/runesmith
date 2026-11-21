# Workspace CLAUDE.md - folder-conventions section

`runesmith-workspace:init` writes (or refreshes) a marker-bounded section into the workspace's root `CLAUDE.md` so every future Cowork session in this workspace knows the canonical folder layout.

## Why

Cowork loads `CLAUDE.md` at session start. If the folder convention isn't pinned there, subsequent sessions drift - files get parked at root, transients accumulate, _INBOX never gets emptied. Pinning the section keeps the workspace coherent across sessions and across users.

## Marker pattern

Mirrors the `<!-- atlassian-section:start/end -->` pattern in `lib/cc-workspace.md`. Markers let init refresh the section idempotently without clobbering surrounding content.

```markdown
<!-- folder-conventions:start -->
## Workspace structure

This workspace follows the canonical layout in @STRUCTURE.md.

**Rules:**
- Root stays clean. Marketplace standard files + canonical dirs only.
- New files go to `_INBOX/`. Run `/runesmith-workspace:inbox` to classify and route them.
- Every plan is a folder: `plans/active/{slug}/plan.md` plus an append-only `decisions.md`.
- Handoffs the owner carries to another project go to `drafts/handoffs/{name}/`; handoffs from other projects arrive in `_INBOX/` and land in `source-docs/`, kept as received.
- Tickets live under their plan: `plans/active/{slug}/tickets/{KEY}.json`. Pushed tickets archive to `archive/tickets-pushed/{YYYY-MM}/`.
- Consumed or superseded content to `archive/superseded/{YYYY-MM}/`. Never park transients at root.
- Plans, drafts, research, source-docs each have a canonical home. See @STRUCTURE.md for the full map.

**Canonical dirs:** `_INBOX/`, `plans/`, `notes/`, `drafts/`, `research/`, `source-docs/`, `archive/`, `{PROJECT}.cc/`

To set up or normalize this layout, or refresh `STRUCTURE.md`, run `/runesmith-workspace:init`.
<!-- folder-conventions:end -->
```

## How init applies it

1. Read workspace root `CLAUDE.md`.
2. If markers exist to replace content between them with the current template.
3. If markers don't exist to append the full block (markers + content) to the end of `CLAUDE.md`, preceded by a blank line.
4. If `CLAUDE.md` doesn't exist to create it with a minimal preamble:
   ```markdown
   # {WORKSPACE-NAME}

   Workspace constitution. Read at session start.

   <!-- folder-conventions:start -->
   ... (block above) ...
   <!-- folder-conventions:end -->
   ```

## How disable / removal works

If a user wants to remove the section (for example when uninstalling `runesmith-workspace`), they delete everything from `<!-- folder-conventions:start -->` through `<!-- folder-conventions:end -->` inclusive. No skill currently writes a "disable" - init is idempotent, so re-running it overwrites the section, and not running it leaves the section in place.

## Token substitution

The template above contains `{WORKSPACE-NAME}` only in the bootstrap case (CLAUDE.md doesn't yet exist). Init substitutes the workspace root folder name. The section body contains no tokens - paths are absolute relative to workspace root and don't need substitution.

## Surrounding content preservation

Init MUST NOT touch any content outside the marker pair. Workspaces commonly have project-specific rules (e.g. this marketplace's own CLAUDE.md has private dev-workspace rules) that live alongside the folder-conventions section.
