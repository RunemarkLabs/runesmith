# Comms-Check Helper

The quick check every planning skill runs before it starts. The full triage is `runesmith-sprint:check-comms`.

## When to run

At the start of:
- `runesmith-core:plan`
- `runesmith-sprint:task`, `runesmith-sprint:check-comms`, `runesmith-sprint:start-sprint`, `runesmith-sprint:sprint-status`, `runesmith-sprint:plan-to-tickets`
- every `runesmith-confluence` publish skill (`feature-doc`, `architecture-doc`, `project-overview`, `decisions-log`, `known-issues`, `roadmap`, `session-log`)
- `runesmith-workspace:init`, `runesmith-cc:head`

If the workspace has no `{PROJECT}.cc/comms/open/`, skip silently.

## Check sequence

### 1. Locate comms

The head is the folder at the workspace root holding `.claude-code-workspace`. Comms are in its `comms/open/`.

### 2. Read what's open

- **Goal status:** the newest `{UTC}-goal-status/` folder. `in-progress` means a goal is running; `done` means replies are waiting.
- **Task folders:** each `{UTC}-{slug}/`. Note whether it has a reply, and any `ambiguity`, `blocker`, `user-action` or `ticket-transition` file.
- **Legacy items:** `{PREFIX}-{NNN}-{slug}/` folders or loose `.md` files from the old layout. Count them; `runesmith-workspace:init` renames them.

Parse front matter only; don't read bodies here.

### 3. Tell the owner what matters, briefly

Only when there's something to say:

```
Comms: goal finished (build {number}), {n} replies waiting.
       {k} questions from Claude Code need you.
```

or

```
Comms: a goal is running ({task count} tasks, {done} done).
```

If replies are waiting or questions need the owner, offer `runesmith-sprint:check-comms` as a structured prompt before continuing:

- **Check comms first** (recommended when a goal finished)
- **Continue with {this skill}**

### 4. Continue

Then carry on with the calling skill's own work. The check doesn't run again in the same invocation.

## Implementation note

Skills that use this lib start their workflow with:

```markdown
### 0. Comms check (always first)

See `lib/comms-check.md`.
```

Skipping it leaves finished goals and the builder's questions invisible.
