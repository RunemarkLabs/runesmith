# Claude Code Workspace - {PROJECT}

Monorepo head for the {PROJECT} Claude Code workspace. Repos live as
subdirectories. Each repo has its own CLAUDE.md.

## Workflow

You receive tasks via `comms/open/` files written by Cowork. You DO NOT
contact the user directly.

For ambiguity, blockers, or user-only actions, write a comm file:

```
comms/open/<ISO>-<slug>.md
```

with frontmatter:

```yaml
---
id: <id>
from: cc
to: cowork | user
type: ambiguity | blocker | user-action
parent: <id of comm you're responding to, if any>
status: open
created: <ISO>
---
```

Block on that work item until a reply arrives in `comms/open/` with
`parent: <your-id>, type: answer`. Then archive both files to
`comms/archive/<YYYY-MM>/<slug>/`.

The user is reached only through Cowork. You communicate with Cowork via
files in `comms/`.

## Memory hierarchy

- This file: monorepo-level rules (always loaded)
- `./<repo>/CLAUDE.md`: repo-shared
- `./<repo>/<subfolder>/CLAUDE.md`: scoped

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
- Never commit or push unless told. Stop at staged.

**User interaction**
- You communicate with the user only via Cowork through `comms/`. Never address the user directly.
- For ambiguity, blockers, or user-only actions, write a `comms/open/{ISO}-{slug}.md` comm with the appropriate `to:` and `type:`.

**Comms hygiene (reply STATUS line)**
- Every reply comm MUST start with an explicit `STATUS:` line immediately after the `# Title` header, BEFORE any "Done" section or prose. Allowed values:
  - `STATUS: complete` - every goal in the original task is met. No follow-up required.
  - `STATUS: partial` - some goals met, others deferred. Include a `Why partial:` line explaining what got skipped and why.
  - `STATUS: blocked` - nothing landed, waiting on user/Cowork action. Include a `Blocker:` line summarizing.
  - `STATUS: failed` - attempted but errored unrecoverably. Include an `Error:` line with the relevant message verbatim.
- The STATUS line is for scannability - Cowork and the user need to know at a glance whether to read the rest as a celebration, a triage, or a fix request.

**End-of-task signal banner**
- Every task ends with a high-visibility banner as the LAST thing in your text response - NOT echoed via bash. Bash tool output collapses to "Ran a command" rows in the CC UI; the user can't see it without expanding. The banner must appear as markdown in your final assistant message so it renders inline as a code block, visible without interaction.
- Required steps BEFORE printing the banner, in this order:
  1. Reply comm written to `comms/open/{reply-id}.md` with the STATUS line per "Comms hygiene" above.
  2. Original task comm AND reply comm BOTH moved to `comms/archive/{YYYY-MM}/{task-slug}/`.
  3. Any commits signed + staged. Do NOT push unless the task explicitly says push.
- Banner format - paste verbatim into your final assistant text response, fill in the placeholders. Use a fenced code block so the box-drawing characters render monospaced:

  ````
  ```
  ===================================================================
    [GLYPH] TASK [HEADLINE]
  ===================================================================
    Status:   {complete | partial | blocked | failed}
    Reply:    comms/archive/{YYYY-MM}/{task-slug}/{reply-id}.md
    Archive:  comms/archive/{YYYY-MM}/{task-slug}/
    Commits:  {hash} staged, not pushed   (or: no commits)
    Next:     {one-line next-task suggestion, or "awaiting cowork"}
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
- Curly braces `{PLACEHOLDER}` only when authoring plugin metadata. Never angle brackets `<placeholder>` - Cowork's upload validator rejects them.

**Workspace boundaries**
- The CC head (this directory) is yours to organize. Repos under `<repo>/` are yours to work in. The workspace root (the parent directory) is Cowork's territory - don't reach into it.
- For repo-level cleanup (dead code, unused exports, unused deps), use `/code-tech-debt` (deployed in `.claude/skills/code-tech-debt/`).

**Sandbox vs permissions**
- "Permission denied" → request permission.
- "No such file" on an existing path → sandbox b