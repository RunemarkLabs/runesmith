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

**End-of-task terminal signal**
- Every task ends with a high-visibility terminal banner as the LAST thing printed before stopping. No prose after the banner. The banner makes "I'm done" unmissable in the terminal scrollback.
- Required steps BEFORE the banner prints, in this order:
  1. Reply comm written to `comms/open/{reply-id}.md` with the STATUS line per "Comms hygiene" above.
  2. Original task comm AND reply comm BOTH moved to `comms/archive/{YYYY-MM}/{task-slug}/`.
  3. Any commits signed + staged. Do NOT push unless the task explicitly says push.
- Banner format (use ANSI green for `complete`, yellow for `partial`, red for `blocked` / `failed`):
  ```
  echo -e "\n\033[1;32m===================================================================\033[0m"
  echo -e "\033[1;32m  TASK COMPLETE\033[0m"
  echo -e "\033[1;32m===================================================================\033[0m"
  echo -e "  Status:   STATUS: complete"
  echo -e "  Reply:    comms/archive/{YYYY-MM}/{task-slug}/{reply-id}.md"
  echo -e "  Archive:  comms/archive/{YYYY-MM}/{task-slug}/"
  echo -e "  Commits:  {hash} staged, not pushed   (or: no commits)"
  echo -e "  Next:     {one-line next-task suggestion, or 'awaiting cowork'}"
  echo -e "\033[1;32m===================================================================\033[0m\n"
  ```
- Color + headline by STATUS value:
  - `complete` -> `\033[1;32m` (bold green) + `TASK COMPLETE`
  - `partial` -> `\033[1;33m` (bold yellow) + `TASK PARTIAL`
  - `blocked` -> `\033[1;31m` (bold red) + `TASK BLOCKED`
  - `failed` -> `\033[1;31m` (bold red) + `TASK FAILED`
- If ANSI cannot be printed for any reason, fall back to the same text with `===` dividers - the banner shape must still be unmistakable.
- The banner is the contract: until the user sees the banner, the task is NOT done, even if all the work landed in files. No banner = keep working (write the reply, archive the files, then print).

**Placeholder syntax**
- Curly braces `{PLACEHOLDER}` only when authoring plugin metadata. Never angle brackets `<placeholder>` - Cowork's upload validator rejects them.

**Workspace boundaries**
- The CC head (this directory) is yours to organize. Repos under `<repo>/` are yours to work in. The workspace root (the parent directory) is Cowork's territory - don't reach into it.
- For repo-level cleanup (dead code, unused exports, unused deps), use `/code-tech-debt` (deployed in `.claude/skills/code-tech-debt/`).

**Sandbox vs permissions**
- "Permission denied" → request permission.
- "No such file" on an existing path → sandbox bug. Switch vector.
- Don't conflate the two.

This section is skill-managed. Re-running `/runesmith-cc:bootstrap-cc` (from Cowork) refreshes the content between markers. User additions belong outside the marker pair.
<!-- agent-ops:end -->

<!--
  Deployed from RuneSmith marketplace.
  Copyright 2026 Runemark Labs. Licensed under Apache-2.0.
  Source: https://github.com/runemarklabs/runesmith
-->
