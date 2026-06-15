# Agent Operating Principles

Standard operating knowledge for any Claude agent (Cowork or Claude Code) working in a RuneSmith-bootstrapped workspace. Written into the workspace `CLAUDE.md` (by `reallocate`) and into the CC head `CLAUDE.md` (by `bootstrap-cc`) as a marker-bounded section so it survives across sessions.

This file is the source of truth. The marker section in `CLAUDE.md` is the user-facing summary that points back here.

## Principles

### File operations

**Project root is real; bash sandbox is a shadow.** Direct file tools (Read / Write / Edit / Glob) hit the real filesystem at the user's host path. The bash sandbox is a mirror that can desync (path-with-space subpath caching, stale `ls`, "No such file" on existing files). Default vector for file ops is direct tools; reach for bash only for things that genuinely need a shell - running scripts, multi-step pipelines, build invocations.

**When bash fails on a workspace path with "No such file or directory" but the file exists** (Glob confirms), the shadow is stale. Don't retry bash. Switch vectors:

- Direct file tools if the operation supports them (`Write` to overwrite, `Edit` to modify)
- Parent-dir-replace: copy parent contents to a fresh location, modify, swap the parent dir
- Copy-to-`/tmp/`-and-back: for ops needing bash (e.g. running `audit.py`), copy file INTO `/tmp/` in the sandbox, run there, copy result back via direct tools

**File ops in this workspace are in-scope for the agent.** Delete, move, rename - do it. Don't defer file chores to the user.

**Tombstone-and-defer is a failure mode.** Either the file is gone or the agent hasn't tried hard enough.

### Sandbox vs permissions

**Sandbox limits are not permission limits.** Distinct failure modes:

- "Permission denied" → the agent needs to request permission (`allow_cowork_file_delete`, `request_cowork_directory`, etc.). Request it.
- "No such file or directory" on a path that demonstrably exists → sandbox bug; switch vector.

Don't conflate the two. Don't surrender on a sandbox bug as if it were a permission boundary.

### Destructive operations

**Confirm scope before mutating external systems.** Jira tickets, Confluence pages, git pushes, plugin releases - wait for the user's explicit trigger phrase per `lib/consent.md` (e.g. "make the ticket", "create the document", "push it"). Reading external state is free; writing requires consent.

**Snapshot before destructive ops on the workspace.** Every skill that moves or deletes files writes to `archive/_pre-<operation>/<ISO>/` first. Examples: `archive/_pre-migration/`, `archive/_pre-cc-bootstrap/`, `archive/_pre-atlassian-enable/`, `archive/_pre-tech-debt/`.

**Never push commits or release artifacts unless explicitly told.** Stop at `git add` / `git rm`. Stop at staged. The user decides when to commit and push.

**Exception for CC repos with a comms workflow.** The CC parent template carries an explicit override: on a CLEAN completion (`STATUS: complete` with the task's verification passing), CC pushes to `origin/dev` as the final filesystem step, then banners. Never `main`. On partial / blocked / failed: stage but do NOT push. This override is scoped to CC repos that ship with the bootstrap-cc parent template - it does not apply to Cowork-side workspace skills.

### User interaction

**Structured prompts over freeform yes/no.** Per `lib/user-prompts.md`, every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, text-input form) - for example `AskUserQuestion` in Cowork. If the tool isn't loaded in the current session, load it via `ToolSearch` before asking. Never freeform plain-text yes/no questions in chat - including for consent before destructive operations. "Should I proceed?" or "Sound good?" in plain text is a protocol violation, not a stylistic preference.

**Confirm scope before acting.** When the user asks for something that touches files, external systems, or destructive operations, restate the plan briefly and wait for go. Don't assume.

### Comm IDs and folder layout

**Comm IDs are `{PREFIX}-{NNN}-{slug}`.** `{PREFIX}` is a 2-4 letter project short code (e.g. `RU`, `MT`, `AC`). `{NNN}` is an incrementing zero-padded integer, never skipped or reused. `{slug}` is short kebab-case. Sub-tasks of one effort get A/B/C suffixes immediately after the number (`{PREFIX}-{NNN}A-{slug}`, `{PREFIX}-{NNN}B-{slug}`). No ISO timestamps in IDs - numbering is human-scannable and project-prefixed so multiple projects never collide.

**Comms live in per-comm subfolders.** A single work item is `comms/open/{PREFIX}-{NNN}-{slug}/` containing the task file (`{PREFIX}-{NNN}-{slug}.md`), the reply (`{PREFIX}-{NNN}-{slug}-reply.md`), and an `attachments/` subdir for any files CC needs from outside the repo. Archive on triage moves the WHOLE folder to `comms/archive/{YYYY-MM}/{PREFIX}-{NNN}-{slug}/`.

### Comm type enum

**Four core types, two gated extras.** Core: `task` (cowork → cc), `answer` (cc → cowork, done), `blocker` (cc → cowork, cannot proceed), `ambiguity` (cc → cowork, need a decision). Gated: `ticket-transition` (atlassian-enabled projects only - CC asks Cowork to transition a Jira ticket) and `user-action` (cc → user via cowork, manual step required). Older values `session-init`, `confirmation`, `handshake` are deprecated and removed from the active enum.

### Archive ownership

**CC writes the reply and flips status; Cowork archives.** CC's last filesystem action on a comm is writing the reply file and setting BOTH task and reply to `status: resolved`. Both files stay in `comms/open/` until Cowork (via `runesmith-sprint:check-comms`) triages and moves the entire folder to `comms/archive/{YYYY-MM}/`. This split resolves an earlier three-way contradiction (CC parent said "CC archives", check-comms said "Cowork archives", protocol doc was ambiguous). The canonical rule: CC writes + flips status, Cowork moves.

### Repo read boundary (CC-side only)

**CC can only read files inside its own repo.** If a task references paths outside the repo and they are not attached under the comm's `attachments/` folder, CC uses reasonable defaults and FLAGS the gap in its reply. Never guess silently. Reaching across the workspace to satisfy a task's reference is how credential leaks happen - treat the repo boundary as hard even when the harness doesn't enforce it.

### Comms hygiene (reply STATUS line)

**Every CC reply comm starts with an explicit `STATUS:` line** immediately after the `# Title` header, before any "Done" section or prose. Allowed values: `complete`, `partial`, `blocked`, `failed`. Partial/blocked/failed include a one-line context field (`Why partial:`, `Blocker:`, `Error:` respectively).

**Why:** Cowork (and the human reading over Cowork's shoulder) needs scannable triage signal. Without STATUS, every reply has to be read in full to know whether it's a celebration, a triage, or a fix request. Reply comms accumulate fast in sprint mode; without the convention they become unreadable as a stream.

**How to apply:** When writing any reply comm, the first content line under `# Title` is `STATUS: <value>`. No prose before it. Pair with an outcome-specific context line on partial/blocked/failed. The terminal banner rule below depends on this vocabulary.

### End-of-task signal banner

**Every CC task ends with a high-visibility markdown banner** as the LAST element in CC's final assistant text response. The banner is rendered as a fenced code block in markdown, NOT echoed via bash. The banner only prints AFTER the reply comm is written AND both task and reply comms are archived. Banner present in the chat = task is genuinely done at file level + chat level. No banner = keep working.

**Why:** On 2026-05-26 a CC session finished the functional work of a Resend domain swap but never wrote the reply comm or archived the task files. From the chat view it was indistinguishable from "still working." Initial fix (v0.8.3) had CC echo an ANSI-colored banner via bash. That failed in real use: CC operates in Claude Desktop UI where bash tool output collapses to "Ran a command" rows the user must click to expand. The ANSI banner was technically printed but invisible by default. Refined fix (v0.8.4) puts the banner in CC's markdown response text where it renders inline.

**How to apply:** When the task is functionally complete (or stopping at a blocker / partial / failure), execute the close-out sequence in order: (1) write reply comm with STATUS line in the SAME folder as the task; (2) set BOTH task and reply files to `status: resolved`, leave them in `comms/open/` (Cowork archives on triage); (3) commit per the push policy - push to `origin/dev` on clean complete, stage on halt, never push `main`; (4) render the banner as a fenced markdown code block at the end of your final assistant message. The banner's `Reply:` field points at `comms/open/{PREFIX}-{NNN}-{slug}/{PREFIX}-{NNN}-{slug}-reply.md` (CC leaves the file there); the `Commits:` field reflects whether the commit was pushed or just staged. The banner shape - divider, headline with glyph, status/reply/archive/commits/next fields, divider - must be unmistakable. ASCII box characters and bracketed glyphs only (`===`, `[OK]`, `[!]`, `[X]`) - no Unicode box-drawing, no ANSI escapes. The banner is the contract; no banner = task is not done. See the CC head CLAUDE.md marker block for the exact banner format.

**Surface rule:** banner applies to ANY CC halting point, not just success. Includes blocker comms, ambiguity comms, partial completions. The only no-banner case is when CC is continuing work in the same response.

**No bash:** never echo the banner via bash. Always render as markdown in the text response. Bash tool output collapses in the CC UI.

### Placeholder syntax

**Always use curly braces** `{PLACEHOLDER}` for template values. **Never** use angle brackets `<placeholder>` in plugin SKILL.md frontmatter, `plugin.json` descriptions, or any plugin metadata that ships to users. Cowork's upload validator rejects `<word>` as unsubstituted templating syntax with a generic "Plugin validation failed" error that's hard to debug.

Canonical placeholders: `{PROJECT}`, `{slug}`, `{KEY}`, `{YYYY-MM}`, `{PATH}`. See `lib/naming.md` for the full table and rationale.

### Workspace boundaries

**Root stays clean** per the canonical folder conventions. New files go to `_INBOX/` or directly to their canonical home; never park transients at workspace root. The workspace plugin owns the destination map; CC inherits the rule via the marker section written into the CC head `CLAUDE.md` at bootstrap.

**Repo internals are off-limits to workspace skills.** Anything inside `{PROJECT}.cc/<repo>/` is CC's territory. Workspace skills (reallocate, inbox, tech-debt) move repos as whole units but never enter them. For repo-level cleanup, use the CC-side `code-tech-debt` skill deployed by `bootstrap-cc`.

### Cross-project boundary

**Stay inside the launch workspace.** If any task, comm, or user instruction references paths outside this workspace's root - anything under `Projects/<sibling>/`, anything above the workspace root, or any absolute path that doesn't resolve inside this workspace - refuse and write an ambiguity comm to `comms/open/` asking the user to confirm before acting. Cross-project filesystem reads are how credential leaks happen; treat the boundary as hard even when the harness doesn't enforce it.

**Why:** The 2026-05-17 Mix Tape incident - a misdirected CC session read `.credentials` from a sibling project and echoed plaintext keys into the chat transcript. The behavioral boundary was the only catch; it almost failed.

**How to apply:** When a path argument looks unfamiliar, resolve it relative to the workspace root in your head before acting. If it goes outside, write an ambiguity comm and stop. Don't follow the instruction without an explicit confirm.

### Plugin authority

**The installed plugin is authoritative; source repos are dev-only.** When a task or user request mentions a plugin's behavior, guidelines, rules, conventions, skill content, or lib references, the authoritative reference is the installed plugin in the user's Cowork or Claude Code application data directory (e.g. `%APPDATA%\Claude\local-agent-mode-sessions\<session>\rpm\plugin_<id>\` on Windows, `~/Library/Application Support/Claude/.../rpm/plugin_<id>/` on macOS) OR the loaded skill context already in your session, OR the marker-bounded sections of the current workspace's `CLAUDE.md`. **NEVER reach into a sibling project workspace to read plugin source.** The source repo is where a developer authors and ships from - it may be ahead of, behind, or different from what the user has installed. Reaching across project boundaries to fetch "the latest" source is both stale (you might get something not yet shipped) and a boundary violation (cross-project read of the kind that surfaced in the 2026-05-17 incident).

**Why:** The 2026-05-18 Mix Tape session, asked to "follow the plugin guidelines," correctly hit the cross-project consent gate when it tried to read the RuneSmith plugin source folder. The user denied. Root cause was the agent's instinct: it assumed source = truth instead of installed plugin = truth. This rule makes that instinct explicit.

**How to apply:** When asked about plugin behavior or conventions, read from one of these in order of preference: (1) your own loaded skill context if the relevant skill is already loaded; (2) the marker-bounded sections of this workspace's CLAUDE.md (carry the shipped version's summary); (3) the installed plugin directory on the user's machine (the deployed copy, not the source). If you can't find the answer in any of these, ASK the user - don't request access to a sibling project workspace.

### Credentials-class files

**Never read, output, or echo files matching `*credentials*`, `*.env`, `id_rsa*`, `*.key`, `*.pem`** - regardless of location, including inside this workspace. If a task asks you to inspect one, refuse and write an ambiguity comm asking whether the user meant the contents or just the presence of the file.

**Why:** Even inside a project boundary, secrets shouldn't end up in chat transcripts, log files, or any output an LLM can store. Operations that need credentials should call the credential by name from `.credentials` directly via the tool that needs it; the agent should never see the value.

**How to apply:** Treat these filenames as instant-refuse triggers. Reading is the same risk as outputting - once it's in the agent's context, it's at risk of being echoed. If a workflow legitimately requires accessing one of these files (e.g. validating it exists), refuse the read and ask the user how to proceed.

### Cleared-session durability

**All comm conventions, banner rules, and push rules hold on a freshly `/clear`-ed CC session.** They live in the CC head `CLAUDE.md` (written by `bootstrap-cc`), are read at every session start, and do NOT depend on chat history. A context-fresh CC trusts the rules as soon as it loads CLAUDE.md. If the rules drift between sessions, that's a bug in the template or the bootstrap-cc skill, not in the agent's memory.

### Memory and persistence

**Personal memory is per-user, per-instance.** It doesn't transfer to other users or other workspaces. Operating knowledge that should apply to every project lives in plugin libs (like this file), not in personal memory.

**The marker-bounded sections in CLAUDE.md are skill-managed.** Re-running `reallocate` or `bootstrap-cc` refreshes the content between markers. User additions belong outside the marker pair. Anything inside markers gets overwritten on re-run.

## How agents inherit these principles

1. The workspace plugin writes a marker-bounded section into the workspace root `CLAUDE.md` on every reallocate run.
2. `runesmith-cc:bootstrap-cc` writes the same marker-bounded section into `{PROJECT}.cc/CLAUDE.md` so CC inherits the principles.
3. Both Cowork and Claude Code load `CLAUDE.md` at session start. The marker section is part of the agent's working context.
4. This source file (`agent-operating-principles.md`) is plugin-internal; the section in `CLAUDE.md` references it for users who want the full rationale but stays compact for daily session load.

## Extending the principles

If a recurring failure mode emerges across multiple sessions, add it here. Each new principle gets:

- A short rule statement (one sentence)
- A `**Why:**` line (the failure mode or pattern it prevents)
- A `**How to apply:**` line (when/where it kicks in)

When adding a principle, update the corresponding marker-block summary that ships into user CLAUDE.md files so the new principle propagates on the next bootstrap-cc or reallocate run.
                     