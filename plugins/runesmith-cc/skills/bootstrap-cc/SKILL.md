---
name: bootstrap-cc
description: >
  Build the Claude Code monorepo head {PROJECT}.cc/ at the workspace root with normalized naming, auto-migration of detected repos, structured prompts for user input, comms folder, and optional repo create/clone via PAT auth. Use when the user says "bootstrap CC", "set up Claude Code", "create the cc folder", "init Claude Code workspace", "add a repo to CC", "clone repo into CC". Cowork builds; Claude Code never builds itself.
---

# Bootstrap Claude Code Workspace

Create the `<name>.cc/` monorepo head at workspace root. Cowork drives this; Claude Code consumes the result. Detects existing git repos and auto-migrates them. Uses structured prompts (never plain-text yes/no) for any user input.

Idempotent. Safe to re-run.

## References

- `agents/repo-bootstrapper.md` — subagent for repo create/clone with PAT auth
- `lib/cc-workspace.md` — canonical structure
- `lib/comms-protocol.md` — comms folder shape
- `lib/comms-check.md` — runs first
- `lib/credentials.md` — `.credentials` resolution + GITHUB_PAT
- `lib/naming.md` — kebab-case-lowercase normalization rule
- `lib/agent-operating-principles.md` — agent-ops principles applied to CC head CLAUDE.md
- `lib/code-analyzers.md` — per-language analyzer registry for the deployed `code-tech-debt` skill
- Templates in this skill's `templates/` directory (notably `CLAUDE.parent.md` which carries the agent-ops marker section)

## User input rules (CRITICAL)

Every question to the user MUST be a **structured prompt** (the host client's multi-choice or form UI, e.g. AskUserQuestion in Cowork). Never ask freeform yes/no in plain chat text.

For values the user types (names, URLs): single-question form with a default pre-populated. Show the normalized form per `lib/naming.md` alongside the raw input so they can see and confirm.

Auto-decisions (no prompt needed):
- A detected `<dir>/` containing `.git/` at workspace root → auto-migrate into the CC head. No prompt.
- The CC head name is derived from the primary git repo's folder name (per `lib/naming.md`). No prompt unless there are zero repos AND the workspace folder name normalizes to empty.

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`.

### 1. Workspace root

Resolve workspace root (cwd or `BOOTSTRAP_WORKSPACE` env). No confirmation prompt — surface it in the upcoming plan.

### 2. Detect git repos at workspace root

For each subdir directly under workspace root, check for `.git/`. If found, that subdir is a git repo and will auto-migrate into the CC head.

Also detect:
- Existing `<name>.cc/` (already canonical → idempotent re-init mode)
- Legacy `claude-code/` (migrate to `<name>.cc/`)

### 3. Derive CC head name

Per `lib/naming.md`:

1. **Exactly one git repo** at workspace root → normalize its folder name → that's the CC head name. No prompt.
2. **Multiple git repos** at workspace root → present a **structured single-pick** listing each by normalized name. The chosen one's name becomes the CC head name. Others migrate alongside.
3. **No git repo** → normalize the workspace root folder name. If normalization produces a non-empty result, use it. No prompt.
4. **Normalization yields empty** (only symbols or whitespace) → **structured prompt** asking user for a name. Show normalized preview as form default.

Always show the resolved CC head name in the upcoming plan.

### 4. GitHub PAT

If user might add or create repos: read `GITHUB_PAT` from `.credentials`. If missing, mark repo operations as unavailable in the plan.

## When to Use

Use for:
- First-time CC head bootstrap
- Migrating legacy `claude-code/` to canonical `<name>.cc/`
- Adding a new repo to an existing CC head
- Re-initializing missing files in an already-bootstrapped CC head

Do not use for:
- Atlassian wiring → `/runesmith-sprint:enable`
- Building plugins → `/runesmith-devtools:plugin-builder`

## Workflow

### 1. Show the plan

Present a structured summary:

```
Workspace root: <path>
CC head name:   <normalized-name>.cc/   (from <source>: git repo "X" / workspace folder)
CC head state:  fresh | legacy migration | re-init
Auto-migrating repos (no prompt):
  - <repo-folder> → <name>.cc/<normalized-repo-folder>/
Files to create:
  - CLAUDE.md, README.md, .claude-code-workspace, .claude/{...}, comms/{...}, .gitignore, .gitattributes
GitHub PAT: present | missing
Atlassian: not enabled (use /runesmith-sprint:enable after)
```

### 2. Consent (structured)

Single-pick structured prompt:
- **Apply** (default)
- **Show file diff first** (preview-only, no writes)
- **Cancel**

### 3. Snapshot if needed

If migrating or filling into an existing folder where files might be overwritten:

```
archive/_pre-cc-bootstrap/<ISO timestamp>/
```

Copy current `<name>.cc/` (or `claude-code/`, or each migrating repo) before any change.

### 4. Migrate

- Legacy `claude-code/` → rename to `<name>.cc/`.
- Each detected git repo at workspace root → move into `<name>.cc/<normalized-repo-folder>/`.
- Existing repos inside `claude-code/` move along when the parent renames.

### 5. Generate files from templates

Per `lib/cc-workspace.md`, ensure these exist (do not clobber if user has customized):

| Path | Source template |
|---|---|
| `<name>.cc/CLAUDE.md` | `templates/CLAUDE.parent.md` (token-substituted) |
| `<name>.cc/README.md` | `templates/README.md` |
| `<name>.cc/.claude-code-workspace` | `templates/marker.json` (token-substituted) |
| `<name>.cc/.claude/settings.json` | `../guardrail/templates/project-settings.json` (project-level guardrail scaffolding — `additionalDirectories: []`, empty allow/deny) |
| `<name>.cc/.claude/README.md` | `../guardrail/templates/project-claude-readme.md` (documents the boundary + escape-hatch usage) |
| `<name>.cc/.claude/settings.local.json` | empty `{}` (gitignored) |
| `<name>.cc/.claude/skills/code-tech-debt/SKILL.md` | `../../cc-skill-templates/code-tech-debt/SKILL.md` (plugin-relative) |
| `<name>.cc/.claude/skills/code-tech-debt/lib/code-analyzers.md` | `../../../lib/code-analyzers.md` (plugin-relative) |
| `<name>.cc/.claude/commands/.gitkeep` | empty |
| `<name>.cc/.claude/agents/.gitkeep` | empty |
| `<name>.cc/.claude/hooks/.gitkeep` | empty |
| `<name>.cc/comms/open/.gitkeep` | empty |
| `<name>.cc/comms/archive/.gitkeep` | empty |
| `<name>.cc/comms/README.md` | `templates/comms-README.md` |
| `<name>.cc/.gitignore` | `templates/gitignore` |
| `<name>.cc/.gitattributes` | `templates/gitattributes` |

**Guardrail nudge**: after writing the project-level `.claude/settings.json` + `.claude/README.md`, check whether the user-level guardrail is installed (look for `_runesmith_guardrail_marker` in `~/.claude/settings.json` / `%USERPROFILE%\.claude\settings.json`). If absent, surface this in the final report with a clear next step: "Run `/runesmith-cc:guardrail install` to enforce the project boundary at the harness level. Without it, the project-level settings are advisory only."

Token substitution:
- `{PROJECT}` → resolved CC head name
- `{ISO_TIMESTAMP}` → now in ISO 8601

**Idempotent re-apply on existing CC head**: if `<name>.cc/CLAUDE.md` already exists, do not overwrite. Instead, refresh the marker-bounded sections in place:

1. `<!-- atlassian-section:start -->` / `<!-- atlassian-section:end -->` — leave content alone (atlassian-enable owns it; bootstrap-cc only seeds empty markers on first write)
2. `<!-- agent-ops:start -->` / `<!-- agent-ops:end -->` — replace content between markers with the current body from `templates/CLAUDE.parent.md`. If markers don't exist, append the full block before the closing comment.

Never touch content outside any marker pair.

### 5a. Deploy standard CC skill templates

Every CC head ships with the following CC-side skill templates (callable from inside CC via slash commands):

- **`code-tech-debt`** — repo-level dead-code / unused-export / unused-dep scanner. Per-language analyzers (TS, JS, Node, React, Next.js, Python out of the box; extensible via `code-analyzers.md`). Source: `cc-skill-templates/code-tech-debt/SKILL.md` in this plugin. The skill's lib (`code-analyzers.md`) is also copied into the deployed skill's own `lib/` so it travels with the skill.

Sprint-specific skills (sprint-pull, ticket-document, blocker-write, ticket-done) are NOT deployed by bootstrap-cc — those are deployed by `/runesmith-sprint:enable` and only when the user opts into the Atlassian workflow.

Copy templates with token substitution where applicable. Do not clobber if the user has customized the deployed copy.

### 6. For each migrated repo: drop a stub CLAUDE.md

If a migrated repo lacks a top-level CLAUDE.md, drop a stub from `templates/CLAUDE.repo.md` (token-substituted: `{PROJECT}` → CC head name, `{REPO_NAME}` → normalized repo dir name). Do not commit; user reviews/edits first.

### 7. Update marker

Write final `.claude-code-workspace`:

```json
{
  "project": "<normalized-cc-head-name>",
  "initialized": "<ISO>",
  "schemaVersion": 1,
  "atlassianEnabled": false,
  "atlassian": null,
  "repos": [
    { "name": "<normalized-repo-dir>", "path": "./<normalized-repo-dir>", "migratedFrom": "<workspace-root>/<original-name>" }
  ]
}
```

### 8. Optional: add more repos

After main bootstrap completes, present a **structured single-pick prompt**:
- **Add a new repo** (creates on GitHub + clones)
- **Clone an existing repo** (paste URL)
- **Skip** (default)

If user picks new or clone, **delegate to the `repo-bootstrapper` agent** with the relevant inputs. Form fields use structured prompts:

For **new repo**:
- Name (default: blank; user types; normalize per `lib/naming.md` and show preview)
- Description (single line)
- Visibility: **structured single-pick** of `public` | `private`
- Owner (default: user's GitHub login from `.credentials` if available)

For **clone**:
- Git URL (single text field)

After the agent returns, append the repo to `.claude-code-workspace`'s `repos[]` and loop back to the add-or-skip prompt.

### 9. Security scan

After all moves, scan migrated repos for:
- `.git/config` containing literal credentials in remote URL (`https://ghp_*@...`, `https://x-access-token:*@...`)
- Loose `.credentials`, `.env`, secrets-named files at the repo root

Surface findings in the report as warnings with specific remediation commands.

### 10. Report

```
✓ Claude Code workspace ready
Path: <workspace-root>/<name>.cc/

Drag this folder into Claude Code's "Open Folder":
  <absolute path to <name>.cc/>

Migrated:
  - <repo-folder>/ → <name>.cc/<normalized-repo-folder>/

Repos in CC head: <n>
Comms: <name>.cc/comms/  (open is gitignored, archive is committed)

⚠ Security review (if any)
  - <name>.cc/<repo>/.git/config has a credential in the remote URL.
    Rotate the token, then run:
      git -C <path> remote set-url origin https://github.com/<owner>/<repo>.git

Next:
  /runesmith-sprint:enable      — wire Atlassian into this project (optional)
  /runesmith-cc:bootstrap-cc    — re-run any time to add more repos
```

## Idempotent re-run

If `<name>.cc/` is already canonical:
- No snapshot needed.
- Skip migration step.
- Generate any missing files from templates (do not clobber).
- Detect any newly-arrived git repos at workspace root and offer to migrate them via structured prompt.
- Re-prompt for repo additions if user explicitly asks.

## Guard Rails

- [ ] Comms check ran first
- [ ] All user input via structured prompts (no plain-text yes/no)
- [ ] CC head name normalized per `lib/naming.md` from the primary git repo (when present) or workspace folder name
- [ ] Git repos at workspace root auto-migrate without prompts
- [ ] Snapshot before any modification
- [ ] User explicitly consented via structured prompt before file writes
- [ ] Folder name canonical: `<name>.cc/` (lowercase, kebab-case)
- [ ] Marker file written with correct `project`, `initialized`, `atlassianEnabled: false`, `repos[]`
- [ ] PAT stripped from stored git remotes after any new-repo create flow
- [ ] CC parent CLAUDE.md does NOT mention Atlassian (Atlassian wiring is `/runesmith-sprint:enable`'s job)
- [ ] Existing user-customized files preserved
- [ ] Comms folder created with `.gitkeep` so dirs exist in git
- [ ] Security scan run on migrated repos; findings surfaced

## Error Cases

**No `GITHUB_PAT`, user wants to create repo:** Surface a structured prompt to either skip repo creation, paste a PAT inline, or run `/runesmith-core:setup` first.
**GitHub repo create 422 (name taken):** Surface a structured prompt to either pick a different name or switch to clone mode.
**Clone permission denied:** Verify PAT scope (`repo` for private). Re-auth via `/runesmith-core:setup`.
**`<name>.cc/` exists with non-canonical content:** Show diff, surface a **structured choice**: replace with template / preserve as-is / abort.
**Multiple git repos and user can't pick primary:** Default to alphabetically-first; surface that choice with structured prompt confirming.
**Workspace folder name and all repo names normalize to empty:** Surface a **structured prompt** asking user to type a name from scratch.
