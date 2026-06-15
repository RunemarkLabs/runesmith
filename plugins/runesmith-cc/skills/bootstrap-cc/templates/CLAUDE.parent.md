# Claude Code Workspace - {PROJECT}

Monorepo head for the {PROJECT} Claude Code workspace. Repos live as
subdirectories. Each repo has its own CLAUDE.md.

## Workflow

You receive tasks via `comms/open/` folders written by Cowork. You DO NOT
contact the user directly.

For ambiguity, blockers, or user-only actions, write a reply comm in the
SAME folder as the task you're responding to:

```
comms/open/{PREFIX}-{NNN}-{slug}/{PREFIX}-{NNN}-{slug}-reply.md
```

with frontmatter:

```yaml
---
id: {PREFIX}-{NNN}-{slug}-reply
from: cc
to: cowork
type: answer | blocker | ambiguity
parent: {PREFIX}-{NNN}-{slug}
status: resolved
created: {ISO}
---
```

Set BOTH the task file and the reply file to `status: resolved` and
**leave them in `comms/open/`**. Archiving is Cowork's job (via
`runesmith-sprint:check-comms`). CC's last filesystem action on a comm
is writing the reply and flipping status.

The user is reached only through Cowork. You communicate with Cowork via
files in `comms/`.

## Memory hierarchy

- This file: monorepo-level rules (always loaded)
- `./{repo}/CLAUDE.md`: repo-shared
- `./{repo}/{subfolder}/CLAUDE.md`: scoped

## Reference

- Active plans: `@../plans/active/`  (read-only - Cowork owns these)
- Active comms: `@comms/open/`
- Comms protocol: `@comms/README.md`

<!-- atlassian-section:start -->
<!-- This block is empty until /runesmith-sprint:enable runs and applies sprint workflow rules. -->
<!-- atlassian-section:end -->

<!-- agent-ops:start -->
## Agent operating principles

**File operations**
- Project root is real; bash sandbox is a shadow. Default to direct file tools (Read/Write/Edit/Glob). Bash is for scripts and shell pipelines.
- When bash fails with "No such file" on an existing path, the shadow is stale. Switch vectors - direct tools, parent-dir-replace, or copy-to-/tmp/-and-back. Don't retry the same bash command.
- File ops in this CC head are agent territory. Delete, move, rename - do it. Don't defer file chores to the user. (Repo internals - inside `{repo}/` - are handled by repo-scoped tooling and per-repo CLAUDE.md rules.)

**Destructive operations**
- Confirm scope before mutating external systems (Jira, Confluence, git push). Wait for the trigger phrase from your task comm.

**User interaction**
- You communicate with the user only via Cowork through `comms/`. Never address the user directly.
- For ambiguity, blockers, or user-only actions, write a `{PREFIX}-{NNN}-{slug}-reply.md` in the SAME folder as the task with the appropriate `to:` and `type:`.

**Repo read boundary**
- You can only read files **inside this repo**. If a task references paths outside the repo and they are not attached under the comm's `attachments/` folder, use reasonable defaults and FLAG the gap in the reply. Never guess silently. Never reach across the workspace to satisfy a task's reference - that's how credential leaks happen.

**Comms hygiene (reply STATUS line)**
- Every reply comm MUST start with an explicit `STATUS:` line immediately after the `# Title` header, BEFORE any "Done" section or prose. Allowed values:
  - `STATUS: complete` - every goal in the original task is met. No follow-up required.
  - `STATUS: partial` - some goals met, others deferred. Include a `Why partial:` line explaining what got skipped and why.
  - `STATUS: blocked` - nothing landed, waiting on user/Cowork action. Include a `Blocker:` line summarizing.
  - `STATUS: failed` - attempted but errored unrecoverably. Include an `Error:` line with the relevant message verbatim.
- The STATUS line is for scannability - Cowork and the user need to know at a glance whether to read the rest as a celebration, a triage, or a fix request.

**Comm type enum**
- Reply `type:` is one of four core values: `task` (cowork → cc), `answer` (cc → cowork, done), `blocker` (cc → cowork, cannot proceed), `ambiguity` (cc → cowork, need a decision).
- Two gated extras apply only where they fit: `ticket-transition` (atlassian-enabled projects only) and `user-action` (cc → user via cowork, manual step required).

**Push policy (OVERRIDES the generic "never push / stop at staged" agent-ops default)**
- On a CLEAN completion (`STATUS: complete` with the task's verification - typecheck / build / tests - passing): push to `origin/dev` as the final filesystem step, THEN print the banner. Do NOT wait to be told to push `dev`.
- **NEVER push `main`.** Promotion (dev → main) stays a user/Cowork operation.
- On `partial` / `blocked` / `failed`: commit + stage but do NOT push. Stop and banner so the human sees the halt.
- The banner's `Commits:` line reflects reality: `{hash} pushed to origin/dev` on a clean push, or `{hash} staged, not pushed` on a non-clean stop, or `no commits` if nothing changed.

**End-of-task signal banner**
- Every task ends with a high-visibility banner as the LAST thing in your text response - NOT echoed via bash. Bash tool output collapses to "Ran a command" rows in the CC UI; the user can't see it without expanding. The banner must appear as markdown in your final assistant message so it renders inline as a code block, visible without interaction.
- Required steps BEFORE printing the banner, in this order:
  1. Reply comm written to `comms/open/{PREFIX}-{NNN}-{slug}/{PREFIX}-{NNN}-{slug}-reply.md` with the STATUS line per "Comms hygiene" above.
  2. Original task comm AND reply comm BOTH set to `status: resolved`. LEAVE both files in `comms/open/` - Cowork moves them on triage.
  3. Commits per the push policy above (pushed on clean complete, staged on halt).
- Banner format - paste verbatim into your final assistant text response, fill in the placeholders. Use a fenced code block so the box-drawing characters render monospaced:

  ````
  ```
  ===================================================================
    [GLYPH] TASK [HEADLINE]
  ===================================================================
    Status:   {complete | partial | blocked | failed}
    Reply:    comms/open/{PREFIX}-{NNN}-{slug}/{PREFIX}-{NNN}-{slug}-reply.md
    Commits:  {hash} pushed to origin/dev   (or: {hash} staged, not pushed / no commits)
    Next:     {one-line next step, or "awaiting cowork"}
  ===================================================================
  ```
  ````

- Headline + glyph by STATUS:
  - `complete` -> `[OK] TASK COMPLETE`
  - `partial`  -> `[!] TASK PARTIAL`   (include a `Why partial:` line above the banner)
  - `blocked`  -> `[X] TASK BLOCKED`   (include the `Blocker:` line above the banner)
  - `failed`   -> `[X] TASK FAILED`    (include the `Error:` line above the banner)
- The banner applies to ANY CC stopping point, not just successful completion. Blocker comms, ambiguity comms, partial completions all require a banner. The only no-banner case is when CC is continuing work in the same response (no halt).
- Until the user sees the banner code block in your final response, the task is NOT done. No banner = keep working.
- Do NOT write any prose AFTER the banner. The banner is terminal in the response - literally the last thing in your message.
- Do NOT echo the banner via bash. Always render as markdown in your text response.

**Placeholder syntax**
- Curly braces `{PLACEHOLDER}` only when authoring plugin metadata. Never angle brackets `{placeholder}`-shaped tokens with `<>` - Cowork's upload validator rejects them.

**Workspace boundaries**
- The CC head (this directory) is yours to organize. Repos under `{repo}/` are yours to work in. The workspace root (the parent directory) is Cowork's territory - don't reach into it.
- For repo-level cleanup (dead code, unused exports, unused deps), use `/code-tech-debt` (deployed in `.claude/skills/code-tech-debt/`).

**Sandbox vs permissions**
- "Permission denied" → request permission.
- "No such file" on an existing path → sandbox bug. Switch vector.
- Don't conflate the two.

**Cleared-session durability**
- All comm conventions, banner rules, and push rules above hold on a freshly `/clear`-ed session. They live in this `CLAUDE.md`, read at every session start, and do NOT depend on chat history.

This section is skill-managed. Re-running `/runesmith-cc:bootstrap-cc` (from Cowork) refreshes the content between markers. User additions belong outside the marker pair.
<!-- agent-ops:end -->

<!--
  Deployed from RuneSmith marketplace.
  Copyright 2026 Runemark Labs. Licensed under Apache-2.0.
  Source: https://github.com/runemarklabs/runesmith
-->
