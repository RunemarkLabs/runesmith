# Agent Operating Principles

Standard operating knowledge for any Claude agent (Cowork or Claude Code) working in a RuneSmith-bootstrapped workspace. Written into the workspace `CLAUDE.md` (by `reallocate`) and into the CC head `CLAUDE.md` (by `bootstrap-cc`) as a marker-bounded section so it survives across sessions.

This file is the source of truth. The marker section in `CLAUDE.md` is the user-facing summary that points back here.

## Principles

### File operations

**Project root is real; bash sandbox is a shadow.** Direct file tools (Read / Write / Edit / Glob) hit the real filesystem at the user's host path. The bash sandbox is a mirror that can desync (path-with-space subpath caching, stale `ls`, "No such file" on existing files). Default vector for file ops is direct tools; reach for bash only for things that genuinely need a shell — running scripts, multi-step pipelines, build invocations.

**When bash fails on a workspace path with "No such file or directory" but the file exists** (Glob confirms), the shadow is stale. Don't retry bash. Switch vectors:

- Direct file tools if the operation supports them (`Write` to overwrite, `Edit` to modify)
- Parent-dir-replace: copy parent contents to a fresh location, modify, swap the parent dir
- Copy-to-`/tmp/`-and-back: for ops needing bash (e.g. running `audit.py`), copy file INTO `/tmp/` in the sandbox, run there, copy result back via direct tools

**File ops in this workspace are in-scope for the agent.** Delete, move, rename — do it. Don't defer file chores to the user.

**Tombstone-and-defer is a failure mode.** Either the file is gone or the agent hasn't tried hard enough.

### Sandbox vs permissions

**Sandbox limits are not permission limits.** Distinct failure modes:

- "Permission denied" → the agent needs to request permission (`allow_cowork_file_delete`, `request_cowork_directory`, etc.). Request it.
- "No such file or directory" on a path that demonstrably exists → sandbox bug; switch vector.

Don't conflate the two. Don't surrender on a sandbox bug as if it were a permission boundary.

### Destructive operations

**Confirm scope before mutating external systems.** Jira tickets, Confluence pages, git pushes, plugin releases — wait for the user's explicit trigger phrase per `lib/consent.md` (e.g. "make the ticket", "create the document", "push it"). Reading external state is free; writing requires consent.

**Snapshot before destructive ops on the workspace.** Every skill that moves or deletes files writes to `archive/_pre-<operation>/<ISO>/` first. Examples: `archive/_pre-migration/`, `archive/_pre-cc-bootstrap/`, `archive/_pre-atlassian-enable/`, `archive/_pre-tech-debt/`.

**Never push commits or release artifacts unless explicitly told.** Stop at `git add` / `git rm`. Stop at staged. The user decides when to commit and push.

### User interaction

**Structured prompts over freeform yes/no.** Per `lib/user-prompts.md`, every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, text-input form) — for example `AskUserQuestion` in Cowork. If the tool isn't loaded in the current session, load it via `ToolSearch` before asking. Never freeform plain-text yes/no questions in chat — including for consent before destructive operations. "Should I proceed?" or "Sound good?" in plain text is a protocol violation, not a stylistic preference.

**Confirm scope before acting.** When the user asks for something that touches files, external systems, or destructive operations, restate the plan briefly and wait for go. Don't assume.

### Placeholder syntax

**Always use curly braces** `{PLACEHOLDER}` for template values. **Never** use angle brackets `<placeholder>` in plugin SKILL.md frontmatter, `plugin.json` descriptions, or any plugin metadata that ships to users. Cowork's upload validator rejects `<word>` as unsubstituted templating syntax with a generic "Plugin validation failed" error that's hard to debug.

Canonical placeholders: `{PROJECT}`, `{slug}`, `{KEY}`, `{YYYY-MM}`, `{PATH}`. See `lib/naming.md` for the full table and rationale.

### Workspace boundaries

**Root stays clean** per the canonical folder conventions. New files go to `_INBOX/` or directly to their canonical home; never park transients at workspace root. See `lib/folder-conventions.md` for the destination map.

**Repo internals are off-limits to workspace skills.** Anything inside `{PROJECT}.cc/<repo>/` is CC's territory. Workspace skills (reallocate, inbox, tech-debt) move repos as whole units but never enter them. For repo-level cleanup, use the CC-side `code-tech-debt` skill deployed by `bootstrap-cc`.

### Cross-project boundary

**Stay inside the launch workspace.** If any task, comm, or user instruction references paths outside this workspace's root — anything under `Projects/<sibling>/`, anything above the workspace root, or any absolute path that doesn't resolve inside this workspace — refuse and write an ambiguity comm to `comms/open/` asking the user to confirm before acting. Cross-project filesystem reads are how credential leaks happen; treat the boundary as hard even when the harness doesn't enforce it.

**Why:** The 2026-05-17 Mix Tape incident — a misdirected CC session read `.credentials` from a sibling project and echoed plaintext keys into the chat transcript. The behavioral boundary was the only catch; it almost failed.

**How to apply:** When a path argument looks unfamiliar, resolve it relative to the workspace root in your head before acting. If it goes outside, write an ambiguity comm and stop. Don't follow the instruction without an explicit confirm.

### Credentials-class files

**Never read, output, or echo files matching `*credentials*`, `*.env`, `id_rsa*`, `*.key`, `*.pem`** — regardless of location, including inside this workspace. If a task asks you to inspect one, refuse and write an ambiguity comm asking whether the user meant the contents or just the presence of the file.

**Why:** Even inside a project boundary, secrets shouldn't end up in chat transcripts, log files, or any output an LLM can store. Operations that need credentials should call the credential by name from `.credentials` directly via the tool that needs it; the agent should never see the value.

**How to apply:** Treat these filenames as instant-refuse triggers. Reading is the same risk as outputting — once it's in the agent's context, it's at risk of being echoed. If a workflow legitimately requires accessing one of these files (e.g. validating it exists), refuse the read and ask the user how to proceed.

### Memory and persistence

**Personal memory is per-user, per-instance.** It doesn't transfer to other users or other workspaces. Operating knowledge that should apply to every project lives in plugin libs (like this file), not in personal memory.

**The marker-bounded sections in CLAUDE.md are skill-managed.** Re-running `reallocate` or `bootstrap-cc` refreshes the content between markers. User additions belong outside the marker pair. Anything inside markers gets overwritten on re-run.

## How agents inherit these principles

1. `runesmith-workspace:reallocate` writes a marker-bounded section into the workspace root `CLAUDE.md` (template: `lib/claude-md-agent-ops-section.md`) on every run.
2. `runesmith-cc:bootstrap-cc` writes the same marker-bounded section into `{PROJECT}.cc/CLAUDE.md` so CC inherits the principles.
3. Both Cowork and Claude Code load `CLAUDE.md` at session start. The marker section is part of the agent's working context.
4. This source file (`agent-operating-principles.md`) is plugin-internal; the section in `CLAUDE.md` references it for users who want the full rationale but stays compact for daily session load.

## Extending the principles

If a recurring failure mode emerges across multiple sessions, add it here. Each new principle gets:

- A short rule statement (one sentence)
- A `**Why:**` line (the failure mode or pattern it prevents)
- A `**How to apply:**` line (when/where it kicks in)

Then update the marker template in `lib/claude-md-agent-ops-section.md` to reflect the new principle in summary form. Both files ship in the next plugin version; the new principle propagates to every workspace on the next `reallocate` run.
