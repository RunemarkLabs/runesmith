---
name: reallocate
description: "Migrate or initialize the workspace folder structure to the canonical layout defined in lib/folder-conventions.md. Auto-detects existing git repos and migrates them into the CC head; normalizes folder/repo names to kebab-case-lowercase. Writes STRUCTURE.md and refreshes a marker-bounded section in workspace CLAUDE.md so future sessions stay coherent. Use when the user says \"reallocate\", \"fix the structure\", \"set up the workspace\", \"migrate to new layout\", \"tidy the workspace\", \"bootstrap this project's folders\", or starts work in a workspace that hasn't been organized."
compatibility: Requires Cowork desktop app environment.
---

# Reallocate Workspace

Move the workspace to the canonical structure. Detect current state, propose a migration with naming normalization, snapshot before any change, execute on consent. Pin the conventions into `CLAUDE.md` so they survive across sessions. Idempotent.

## References

- `lib/folder-conventions.md` - **single source of truth** for canonical layout, root keep-list, destination map, lifecycle rules. Reallocate is the writer; this file is the spec.
- `lib/claude-md-section.md` - marker-bounded folder-conventions section template written into workspace CLAUDE.md
- `lib/claude-md-agent-ops-section.md` - marker-bounded agent-ops section template written into workspace CLAUDE.md
- `lib/agent-operating-principles.md` - full rationale for the agent-ops section
- `lib/project-instructions.md` - two-tier project context model (`CLAUDE.md` vs Cowork UI Project Instructions field). Reallocate emits proposed Project Instructions text for the user to paste.
- `lib/project-mission-inference.md` - signal sources and procedure for drafting the PROJECT mission from existing workspace content instead of emitting a static fill-in placeholder.
- `lib/STRUCTURE.template.md` - template for the `STRUCTURE.md` written at workspace root
- `lib/cc-workspace.md` - CC head structure spec
- `lib/plan-format.md` - `plans/active/<slug>/` schema
- `lib/comms-check.md` - runs before mutation
- `lib/naming.md` - kebab-case-lowercase normalization rule

## User input rules (CRITICAL)

Every question to the user in this skill MUST be a **structured prompt** (the host client's multi-choice / form UI, e.g. AskUserQuestion in Cowork). Never ask freeform yes/no in plain chat text.

When you need a value the user must type (a name, a path), use a single-question form with a default already populated. Show the normalized form alongside the raw input.

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`. Pause for `to: user` items.

### 1. Workspace root

Resolve workspace root (cwd or `BOOTSTRAP_WORKSPACE` env). Show in the upcoming migration plan, no separate confirmation prompt needed.

## When to Use

Use for:
- Fresh workspace - initialize the canonical structure
- Workspace from a prior version of this marketplace - normalize to current layout
- Unknown structure - detect what's there, propose mapping, ask only when ambiguous

Do not use for:
- Mid-session ad-hoc moves (do those manually)
- **Anything inside `{PROJECT}.cc/`** beyond the head's own scaffold (CLAUDE.md, marker, comms, .claude/). Reallocate has a HARD BOUNDARY at the `{PROJECT}.cc/<repo>/` level - it never enters source repos. Repo internals are CC's territory; use `/runesmith-cc:code-tech-debt` (deployed by `bootstrap-cc`) for repo-level cleanup.
- Routing inbox content (use `runesmith-workspace:inbox` - reallocate routes only ambiguous loose-root files; inbox handles all `_INBOX/` content)

## Workflow

### 1. Detect current state

Scan workspace root for known entries. Bucket each against the keep-list in `lib/folder-conventions.md`:

- **Canonical dir** - appears on the required-dir list. Keep in place.
- **Canonical file** - appears on the root keep-list (marketplace docs, workspace config, generated files). Keep in place.
- **Git repo** - any subdir containing `.git/`. **These auto-migrate into the CC head without asking.** Their folder name (normalized per `lib/naming.md`) is the primary candidate for the CC head name.
- **CC head candidate** - `claude-code/` (legacy name) or `<name>.cc/` (canonical) at workspace root.
- **Unknown at root** - anything not on the keep-list and not a git repo. Surface to the user as inbox-items via a structured prompt (route to `_INBOX/` for inbox-skill classification, or specify another canonical home directly).
- **Already in a canonical home** - files inside `plans/`, `notes/`, `drafts/`, `research/`, `source-docs/`, `tickets/` (legacy root dir), `archive/`. Touch only if explicitly part of a migration (e.g. legacy `tickets/` at root → into plans).

### 2. Derive CC head name

Per `lib/naming.md`:

1. If exactly **one git repo** is detected at workspace root → normalize its folder name. CC head becomes `<normalized-repo-name>.cc/`. No prompt.
2. If **multiple git repos** → surface a **structured choice** (single-pick) listing each repo. The chosen one's normalized name becomes the CC head name. Others migrate alongside.
3. If **no git repo** → normalize the workspace root folder name. No prompt unless the normalized result is empty.
4. If normalization fails → **structured prompt** asking for a name. Show normalized preview as default.

Always show the resulting CC head name in the migration plan before executing.

### 3. Build migration plan

Per detected item (no per-item prompts unless the row is ambiguous):

| Source | Target |
|---|---|
| `claude-code/` (legacy CC head) | `{PROJECT}.cc/` (rename + normalize via CC migration sub-step) |
| `<git-repo-dir>/` at root | `{PROJECT}.cc/<git-repo-dir>/` (auto-migrate) |
| Legacy `tickets/` at root | Surface as ambiguous: each JSON file needs a plan slug. Route via inbox protocol with prompt "which plan does this ticket belong to?" If user can't say, route to `archive/superseded/<YYYY-MM>/tickets-orphan/`. |
| Loose files at root not on keep-list | `_INBOX/` for inbox classification |
| Unknown dirs at root | structured prompt: leave / move to `_INBOX/` / move to specific path |
| Existing `_INBOX/`, `plans/`, `notes/`, `drafts/`, `research/`, `source-docs/`, `archive/` contents | leave in place |

Show the full plan as a table. One row per move. Highlight the `{PROJECT}.cc/` migration as a clear summary line above the table.

**Never auto-park content in `_INBOX/` if it has a clear canonical home.** _INBOX is for user drops and for ambiguous root content that needs the inbox skill's deeper classification. If reallocate can route directly per `lib/folder-conventions.md`, it does so.

### 4. Snapshot

Before any move, copy everything that will move to:

```
archive/_pre-migration/<ISO timestamp>/
```

CC head migration uses a separate snapshot at `archive/_pre-cc-bootstrap/<ISO>/`.

### 5. Get consent (structured - MANDATORY)

Surface a **single structured confirmation prompt** using the host client's structured-input tool (in Cowork: `AskUserQuestion`). Do NOT ask in chat with a freeform "should I proceed?" - that's a protocol violation against the user-input rules in this skill's frontmatter.

The prompt MUST be a single-pick form with the migration plan summary visible above it. Options:

- **Apply migration** (default)
- **Preview only - don't move anything**
- **Cancel**

If you find yourself typing "want me to proceed?" or "ready to execute?" in chat, STOP. Load the structured-input tool first (via ToolSearch if not already loaded), then use it. This rule applies to every consent gate in this skill - migration consent, per-item ambiguous routing, conflict resolution, Project Instructions merge mode.

### 6. CC head migration sub-step

If `claude-code/` exists at workspace root OR git repos need to be moved in:

a. Determine final CC head name per step 2 (already resolved at plan stage).
b. If `claude-code/` exists: rename `claude-code/` → `{PROJECT}.cc/`.
c. For each detected git repo not already inside `claude-code/`: move it into `{PROJECT}.cc/<normalized-repo-dir>/`.
d. Normalize per `lib/cc-workspace.md`:
   - Ensure `CLAUDE.md`, `README.md`, `.claude-code-workspace`, `.claude/{settings.json, skills/, commands/, agents/, hooks/}`, `comms/{open,archive}/`, `.gitignore`, `.gitattributes` exist. Generate from templates if missing. Do not clobber existing files.
e. If applied atlassian section markers detected in old `CLAUDE.md`, set `atlassianEnabled: true` in marker JSON, copy preserved values, suggest user re-run `/runesmith-sprint:enable` to refresh.

### 7. Execute workspace migration

Move every item per the plan. Create destination dirs as needed. Preserve mtimes.

### 8. Create / refresh required dirs

Ensure these exist per `lib/folder-conventions.md` (empty with `.gitkeep` is fine):

- `_INBOX/`
- `plans/active/`, `plans/archive/`
- `notes/`
- `drafts/features/`, `drafts/project-docs/`, `drafts/bugs/`
- `research/`
- `source-docs/`
- `archive/superseded/`, `archive/tickets-pushed/`

Do not create a root-level `tickets/` - tickets live under their plan now.

### 9. Generate STRUCTURE.md

Read `lib/STRUCTURE.template.md`. Write it to workspace root as `STRUCTURE.md`. No substitutions - paths in the template are conventional and don't require workspace-specific values.

### 10. Apply folder-conventions + agent-ops sections to CLAUDE.md

Two marker-bounded sections to manage in workspace root `CLAUDE.md`, in this order:

1. `<!-- folder-conventions:start -->` ... `<!-- folder-conventions:end -->` - per `lib/claude-md-section.md`
2. `<!-- agent-ops:start -->` ... `<!-- agent-ops:end -->` - per `lib/claude-md-agent-ops-section.md`

For each section:
- Read workspace root `CLAUDE.md`.
- If the section's markers exist → replace content between them with the current template body.
- If markers don't exist → append the full marker-bounded block to the end of `CLAUDE.md`, preceded by a blank line.
- If `CLAUDE.md` doesn't exist → create with a minimal preamble plus both blocks (folder-conventions first, then agent-ops).

Never touch content outside any marker pair. Workspaces commonly have project-specific rules alongside the skill-managed sections.

### 11. Update `.gitignore`

Ensure these patterns are gitignored:
- `_INBOX/*` (drop zone, ephemeral)
- `archive/_pre-migration/*`
- `archive/_pre-cc-bootstrap/*`
- `archive/_pre-atlassian-enable/*`
- `{PROJECT}.cc/comms/open/*` (CC's open comms; archive is committed)
- `.credentials`

### 12. Emit Project Instructions text (CRITICAL - don't skip)

Per `lib/project-instructions.md`: Cowork has TWO project-context surfaces. `CLAUDE.md` is the on-disk **structural** context (folder layout, file paths, conventions that change as the project grows). **Project Instructions** is a separate Cowork UI field carrying **behavioral** context (project mission, Cowork's role, permanent rules) - invisible to the agent, edited only via Cowork's app UI.

The hard rule: **Project Instructions is behavioral; CLAUDE.md is structural.** They must NOT bleed into each other.

Reallocate cannot edit the UI field directly. It MUST surface proposed text for the user to paste.

For every reallocate run:

1. Detect the project name (workspace root folder, normalized per `lib/naming.md`).
2. Render the canonical Project Instructions template from `lib/project-instructions.md`, substituting `{PROJECT_NAME}` only.
3. Surface in the final report inside a clearly-labelled code block - the user copies and pastes into Cowork → project settings → Instructions field.

**Do NOT emit Atlassian content.** Reallocate produces the BASE Project Instructions only. Atlassian-specific rules are appended separately by `runesmith-sprint:enable` (marker-bounded so they can be added/removed independently). If you detect `.atlassian-enabled` at workspace root, surface a note in the report: "Atlassian is enabled for this project - your existing Project Instructions likely has an `<!-- runesmith:atlassian-start/end -->` block from `/runesmith-sprint:enable`. Preserve that block when pasting; the base template below replaces only the non-Atlassian portion."

Likewise: do not emit content for any other opt-in feature plugin (future extensions). Each skill owns its own Project Instructions supplement.

**MUST NOT include in the generated text:**
- File paths or folder layouts (those go in CLAUDE.md)
- Plugin names, counts, or any structural inventory
- Version numbers or commands referencing files
- Anything that would need to be re-edited when the workspace is restructured

If any of those appear in the text, you've written the wrong content for this field - move them to CLAUDE.md instead.

**Auto-written sections** (reallocate generates these verbatim per the template):
- `## ROLE`
- `## RULES`
- `## HOW WE WORK`
- `## ATLASSIAN` (only if atlassian-enabled)

**Inferred section** (reallocate scans existing workspace signal, drafts content, asks user via structured prompt):
- `## PROJECT` - one to three sentences describing what the project IS. Per `lib/project-mission-inference.md`, scan signal sources in order (README.md at root → source-docs/*.md → prior CLAUDE.md content outside markers → package manifest description → top-level notes/). On first strong hit, draft 1-3 sentences and surface a structured prompt with options: **Accept** (use draft as-is), **Edit** (text-input form pre-filled with the draft), **Skip** (fall back to the `{Fill in: ...}` placeholder). If no signal produces a usable draft, emit the placeholder without prompting. Never auto-write without the structured prompt.

Format in the report (use this exact preamble so the user knows what to do):

```
─────────────────────────────────────────────────────────────
PROJECT INSTRUCTIONS - paste into Cowork's UI

Cowork's Project Instructions field (app sidebar → project
settings → Instructions) carries the project's PERMANENT
ROLE and BEHAVIORAL RULES. It is separate from CLAUDE.md
(which carries the dynamic folder structure) and cannot be
edited from here.

Open Cowork's UI and paste the block below into the
Instructions field. Fill in the PROJECT section with what
your project IS - that's the only part you need to author.
─────────────────────────────────────────────────────────────

# {PROJECT_NAME}

... (rendered template from lib/project-instructions.md) ...
```

If the workspace already had Project Instructions set (no programmatic way to know - ask the user via structured prompt: "Do you already have Cowork Project Instructions set for this project? - Yes, replace / Yes, merge / No, paste fresh"), surface guidance accordingly:
- Replace → paste over existing
- Merge → keep their PROJECT section, replace ROLE/RULES/HOW WE WORK with the new template (they're skill-managed)
- Fresh → first-time bootstrap

Do NOT skip this step. The user has no other signal that the Project Instructions field needs to exist or be updated. If you skip it, the workspace ends up half-configured - folder structure correct, role context missing or stale.

### 13. Surface security warnings

If any of the following were detected during scan, surface them at the end of the report (NOT as a blocker):

- A git config file (`.git/config`) at any path containing a literal PAT/OAuth token in the remote URL (`https://ghp_*@github.com/...`, `https://x-access-token:*@github.com/...`)
- A `.env`, `.credentials`, or similar file inside a moved repo
- An archive (`.zip`, `.tar.gz`) that wasn't unpacked but contains the word "credentials" or "secret" in its name

Format:
```
⚠ Security review
  - {PROJECT}.cc/<repo>/.git/config has a GitHub PAT in the remote URL.
    Rotate at github.com → Settings → Developer settings → Tokens, then
    run: git -C <path> remote set-url origin https://github.com/<owner>/<repo>.git
```

### 14. Report

```
✓ Reallocation complete
Snapshot: archive/_pre-migration/<ISO>/
Workspace root: <path>
CC head: {PROJECT}.cc/

Moved: <n> items
  - <git-repo-name>/ → {PROJECT}.cc/<git-repo-name>/   (auto-migrated)
  - <root-loose-file> → _INBOX/                         (run inbox to classify)
  - claude-code/   → {PROJECT}.cc/                      (renamed)

CLAUDE.md: folder-conventions section refreshed
STRUCTURE.md: regenerated

Next:
  /runesmith-workspace:inbox  - process anything sitting in _INBOX/
  /runesmith-core:plan        - capture a plan
```

## Idempotent re-run

If the workspace is already in canonical shape:

- No moves required.
- Skip snapshot.
- Verify required dirs exist; create any missing.
- Verify `.gitignore` patterns; add any missing.
- Refresh `STRUCTURE.md` from current template.
- Refresh marker-bounded section in `CLAUDE.md` (idempotent - replaces with current template).
- Report "Already canonical."

## Guard Rails

- [ ] Comms check ran first
- [ ] All user prompts use structured UI (no plain-text yes/no)
- [ ] Reads `lib/folder-conventions.md` for keep-list and destination map
- [ ] Never auto-parks content in `_INBOX/` if a canonical home is unambiguous
- [ ] Git repos auto-migrate INTO `{PROJECT}.cc/<repo>/` without per-repo prompts
- [ ] **Hard boundary: never enters `{PROJECT}.cc/<repo>/` to inspect or modify repo contents.** Reallocate moves a repo as a whole unit when migrating, then stops at the boundary. Repo-internal cleanup is `runesmith-cc:code-tech-debt` (CC-side).
- [ ] CC head name normalized per `lib/naming.md`
- [ ] Migration plan shown before any move
- [ ] Snapshot created before any move
- [ ] User explicitly consented (structured prompt) before migration runs
- [ ] CC head migration uses canonical naming `{PROJECT}.cc/`
- [ ] No root-level `tickets/` directory created (legacy)
- [ ] `archive/superseded/` and `archive/tickets-pushed/` created
- [ ] `STRUCTURE.md` written at root from `lib/STRUCTURE.template.md`
- [ ] Marker-bounded folder-conventions section written into `CLAUDE.md` per `lib/claude-md-section.md`
- [ ] Marker-bounded agent-ops section written into `CLAUDE.md` per `lib/claude-md-agent-ops-section.md`
- [ ] Content outside marker pairs in `CLAUDE.md` untouched
- [ ] `.gitignore` patterns added
- [ ] **Project Instructions text emitted at the end of the report** (Cowork UI field; agent can't write directly - user pastes). Skipping this leaves the workspace half-configured. See `lib/project-instructions.md`.
- [ ] **PROJECT mission inferred from workspace signal when possible** (README, source-docs, prior CLAUDE.md preamble, package manifest). Draft surfaced via structured prompt: Accept / Edit / Skip. Fall back to `{Fill in: ...}` placeholder only when no signal hits. See `lib/project-mission-inference.md`.
- [ ] Atlassian section markers preserved (suggest re-run if detected)
- [ ] Security warnings surfaced (PAT in remote URL, leaked secrets in moved repos)
- [ ] Idempotent on re-run

## Error Cases

**Empty workspace, nothing to migrate:** Initialize canonical dirs from scratch, write STRUCTURE.md, apply CLAUDE.md section (bootstrap form), report.
**Permission errors during move:** Surface the file, abort the run, suggest user fix permissions and re-run.
**Conflict - destination exists with different content:** Surface a **structured choice** (single-pick): keep existing / overwrite from source / skip / abort.
**Multiple `*.cc/` candidates:** Surface a **structured choice** listing each, single-pick which is active.
**`{PROJECT}.cc/` exists but no marker file:** Treat as legacy CC head; run normalization to add marker + missing structural files.
**Legacy `tickets/` at root with JSONs:** For each JSON, surface a structured prompt asking which plan slug it belongs to. If no plan exists, offer "create a plan now" or "route to `archive/superseded/<YYYY-MM>/tickets-orphan/`".
**Normalized name is empty:** Surface a **structured prompt** for the user to provide a name.
**CLAUDE.md modified externally during reallocate run:** Re-read, re-apply section (markers handle merge), surface a notice in the report.
