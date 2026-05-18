# Workspace CLAUDE.md — agent-ops section

`runesmith-workspace:reallocate` writes (or refreshes) a marker-bounded section into the workspace's root `CLAUDE.md` so every future Cowork or Claude Code session inherits the standard operating principles. `runesmith-cc:bootstrap-cc` writes the same section into `{PROJECT}.cc/CLAUDE.md` so the CC head also inherits it.

Sibling to `claude-md-section.md` (folder conventions). Same marker pattern, distinct concerns.

## Why

Personal memory is per-user and per-instance. Operating knowledge that should apply to every RuneSmith-bootstrapped project belongs in the plugin and gets pinned into `CLAUDE.md`. Cowork loads `CLAUDE.md` at session start, so the section is always in the agent's working context.

## Marker pattern

```markdown
<!-- agent-ops:start -->
## Agent operating principles

For full rationale, see `plugins/runesmith-workspace/lib/agent-operating-principles.md` (or wherever this plugin is installed on your host).

**File operations**
- Project root is real; bash sandbox is a shadow. Default to direct file tools (Read/Write/Edit/Glob). Bash is for scripts and shell pipelines.
- When bash fails with "No such file" on an existing path, the shadow is stale. Switch vectors — direct tools, parent-dir-replace, or copy-to-/tmp/-and-back. Don't retry the same bash command.
- File ops in this workspace are agent territory. Delete, move, rename — do it. Don't defer file chores to the user.

**Destructive operations**
- Snapshot before any move or delete: `archive/_pre-<operation>/<ISO>/`.
- Confirm scope before mutating external systems (Jira, Confluence, git push). Wait for explicit trigger phrases.
- Never commit or push unless told. Stop at staged.

**User interaction**
- Structured prompts (single-pick / multi-pick / text-input forms) via the host client's structured-input tool. Never freeform yes/no in chat — including for consent before destructive operations. "Should I proceed?" in plain text is a protocol violation.
- Confirm scope before acting on file or external mutations.

**Placeholder syntax**
- Curly braces `{PLACEHOLDER}` only. Never angle brackets `<placeholder>` in any plugin metadata. Cowork's upload validator rejects `<word>` as unsubstituted templating. Canonical: `{PROJECT}`, `{slug}`, `{KEY}`, `{YYYY-MM}`.

**Workspace boundaries**
- Root stays clean. New files go to `_INBOX/` or their canonical home. See `STRUCTURE.md` and the folder-conventions section.
- Repo internals (`{PROJECT}.cc/<repo>/`) are CC's territory. Workspace skills move repos as units, never enter them. For repo-level cleanup, use `/code-tech-debt` deployed inside CC.

**Cross-project boundary**
- Stay inside the launch workspace. If a task or instruction references paths under `Projects/<sibling>/`, above the workspace root, or any absolute path outside the workspace, refuse and write an ambiguity comm to `comms/open/` before acting. Cross-project reads are how credential leaks happen.

**Credentials-class files**
- Never read, output, or echo files matching `*credentials*`, `*.env`, `id_rsa*`, `*.key`, `*.pem` — regardless of location, including inside the workspace. If a task asks, refuse and ask whether the user meant the contents or just the file's presence.

**Sandbox vs permissions**
- "Permission denied" → request permission.
- "No such file" on an existing path → sandbox bug. Switch vector.
- Don't conflate the two; don't surrender on a sandbox bug as if it were a permission boundary.

This section is skill-managed. Re-running `/runesmith-workspace:reallocate` (workspace) or `/runesmith-cc:bootstrap-cc` (CC head) refreshes the content between markers. User additions belong outside the marker pair.
<!-- agent-ops:end -->
```

## How reallocate applies it (workspace CLAUDE.md)

1. Read workspace root `CLAUDE.md`.
2. If `<!-- agent-ops:start -->` / `<!-- agent-ops:end -->` markers exist → replace content between them with the current template body.
3. If markers don't exist → append the full marker-bounded block to the end of `CLAUDE.md`, preceded by a blank line. Place after the folder-conventions section if that section exists.
4. If `CLAUDE.md` doesn't exist → create with a minimal preamble plus both blocks (folder-conventions + agent-ops).

## How bootstrap-cc applies it (CC head CLAUDE.md)

Same logic, target file is `{PROJECT}.cc/CLAUDE.md`. Place after any atlassian-section markers (atlassian section is atlassian-enable's territory).

## Surrounding content preservation

Never touch content outside the `agent-ops:start` / `agent-ops:end` pair. Workspaces have project-specific rules, marketplace docs (in dev workspaces), and user-authored content that lives alongside the skill-managed sections.

## Token substitution

The template body contains no host-specific tokens. The path reference to `plugins/runesmith-workspace/lib/agent-operating-principles.md` is informational — it points to the source-of-truth for users who want the full rationale. Path resolution depends on where the user installed the plugin; the section explicitly says "wherever this plugin is installed on your host" rather than asserting a specific path.

## Coordination with folder-conventions section

Both sections are skill-managed and refreshed by `reallocate`. Order in the file:
1. User preamble (workspace identity, any project-specific rules) — preserved
2. `<!-- folder-conventions:start -->` ... `<!-- folder-conventions:end -->`
3. `<!-- agent-ops:start -->` ... `<!-- agent-ops:end -->`
4. Any trailing user content — preserved

If both markers are missing on a fresh write, `reallocate` appends them in that order with a blank line between.
