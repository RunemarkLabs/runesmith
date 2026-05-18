# How-to: Set Up a New Project Workspace

You've just made a folder for a new project and want it ready for RuneSmith-driven Cowork sessions. Goal: canonical structure + CC head + (optionally) Atlassian + the guardrail.

For the system-wide model behind these steps, read `docs/AGENT_PRIMER.md`.

## Prerequisites

- RuneSmith marketplace installed in Cowork (`/runesmith-core` plus whichever plugins you need). See `INSTALL.md`.
- A workspace folder on disk: `~/Projects/<project-name>/` or wherever you keep them.
- Optionally: `.credentials` in the workspace root with `ATLASSIAN_*` and `GITHUB_PAT` keys if you'll use them. See `.credentials.example`.

## Steps

### 1. Open the workspace in Cowork

Launch Cowork desktop, point it at the empty (or near-empty) project folder. Cowork mounts the folder.

### 2. Lay down the canonical structure

```
/runesmith-workspace:reallocate
```

What happens:
- Cowork prompts via structured input — apply / preview diff / cancel.
- On apply: snapshots existing root files to `archive/_pre-migration/<ISO>/`, then creates the canonical dirs (`_INBOX/`, `plans/active/`, `plans/archive/`, `notes/`, `drafts/`, `research/`, `source-docs/`, `archive/`).
- Writes `STRUCTURE.md` and the `<!-- folder-conventions -->` + `<!-- agent-ops -->` marker blocks in `CLAUDE.md`.
- Surfaces a proposed Project Instructions text block for you to paste into Cowork's Project Instructions UI field.

### 3. Paste the Project Instructions

Copy the proposed text from the reallocate output. In Cowork: project settings → Instructions field → paste → save. This sets the behavioral context (role, mission, rules) that Cowork loads as system prompt for every chat.

If you re-run reallocate later, it'll re-emit updated text. Paste again to refresh.

### 4. Bootstrap the CC head

```
/runesmith-cc:bootstrap-cc
```

What happens:
- Detects existing git repos at workspace root, asks via structured prompt whether to migrate them into the CC head.
- Creates `{PROJECT}.cc/` with `CLAUDE.md`, `.claude/` scaffolding (skills, commands, agents, hooks), `comms/open/` and `comms/archive/`, marker file, and the deployed `code-tech-debt` CC-side skill.
- Writes project-level `<project>.cc/.claude/settings.json` (empty `additionalDirectories: []` escape hatch for the guardrail) and `<project>.cc/.claude/README.md`.
- Optionally: prompts to clone an existing GitHub repo or create a new one via PAT auth (uses `GITHUB_PAT` from `.credentials`).
- Surfaces a nudge to run `/runesmith-cc:guardrail install` if it's not installed at user-level yet.

The CC head folder is gitignored from the workspace dev repo — it's its own git repo (or repos plural, if you migrated multiple).

### 5. Install the user-level guardrail (one-time per machine)

If you haven't already:

```
/runesmith-cc:guardrail install
```

Constrains every CC session on this machine to its launch project's root. Cross-project filesystem reads are blocked at the harness level. See `docs/howto/install-guardrail.md` for details and residual risks.

### 6. Optionally enable Atlassian

If this project uses Jira + Confluence:

```
/runesmith-sprint:enable
```

Walks you through capturing the Jira project key, board id, Confluence space id. Appends the `<!-- runesmith:atlassian-start/end -->` block to both `CLAUDE.md` files. Surfaces a supplemental Project Instructions block to paste. Drops `.atlassian-enabled` at workspace root as the canonical marker.

Skip this for personal / non-tracked projects. You can enable later with the same command.

### 7. First plan

```
/runesmith-core:plan
```

Writes `plans/active/<slug>/plan.md`. Iterate. When ready to execute, set `status: building` and (if atlassian-enabled) run `/runesmith-sprint:plan-to-tickets` to convert it into Jira ticket drafts.

## Verify

```
/runesmith-devtools:help
```

Should list every installed plugin and its skills, with natural-language triggers.

Workspace folder should look like:

```
<project>/
├── _INBOX/
├── plans/active/
├── plans/archive/
├── notes/
├── drafts/
├── research/
├── source-docs/
├── archive/
├── {PROJECT}.cc/
├── CLAUDE.md          (folder-conventions + agent-ops markers populated)
├── STRUCTURE.md
└── .credentials       (gitignored)
```

## What can go wrong

**Plugins not loading after install.** Restart Cowork (full quit, not reload). If still not loading, check `~/.claude/local-agent-mode-sessions/.../rpm/plugin_*` directory listings and re-install the affected plugin from a fresh `.plugin` file.

**Reallocate refuses to write.** If the workspace folder has non-canonical content at root, the skill snapshots first and prompts before moving. Approve via structured prompt; never freeform chat consent.

**Bootstrap-cc can't detect repos.** Git repos must have a `.git/` directory at the workspace root level (not nested). Move them up if needed, or supply paths interactively.

**Atlassian enable fails.** Verify `.credentials` has `ATLASSIAN_API_URL`, `ATLASSIAN_API_EMAIL`, and `ATLASSIAN_API_TOKEN` set. Run `/runesmith-core:setup` to populate.

**Project Instructions block not appearing.** Re-run reallocate — the proposed text is emitted in the final report on every run. Look for the copy-friendly code block at the end of the output.
