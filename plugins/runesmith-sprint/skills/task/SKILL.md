---
name: task
description: "Write a task comm for Claude Code and give the /goal line that starts it. Reads open issues first, checks for duplicates in open comms, logs the decision. Use when the user says \"write a task\", \"send this to CC\", \"make a task comm\", \"hand this to Claude Code\", \"give me a goal line\", or after planning a change that Claude Code should build."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Task

Turn the owner's intent into one or more task comms in `{PROJECT}.cc/comms/open/` and end with the `/goal` line the owner pastes into Claude Code. The protocol is `lib/comms-protocol.md`; the method is `lib/planner-task-method.md`.

## References

- `lib/comms-protocol.md` - folder layout, naming, front matter, types
- `lib/planner-task-method.md` - how to write a task the builder can act on, and the goal line rules
- `lib/comms-check.md` - runs first
- `lib/plan-format.md` - where the plan and `decisions.md` live
- `lib/credentials.md` - the GitHub or Atlassian credential for reading issues
- `lib/user-prompts.md` - structured prompts for every decision

## User input rules

Every decision that is the owner's is a structured prompt with the recommended option first. Ask only when the answer changes what gets written, and only about something already shown to the owner.

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`. A finished goal status comm means replies are waiting: offer `runesmith-sprint:check-comms` first.

### 1. Head exists

`{PROJECT}.cc/comms/open/` must exist. If not: the project has no Claude Code head; point at `runesmith-workspace:init`.

### 2. Is a goal running?

Read the newest `open/{UTC}-goal-status/` comm. If its `status` is `in-progress`, the new task is queued for after that goal's banner. Never edit a task that goal has already started.

## Workflow

### 1. Pressure-test the request

Find the weakest point first. If the request contradicts the plan or an earlier decision in `decisions.md`, say so and ask before writing anything. If it's a bug the owner reported with a screenshot, find the root cause first: read the code or the last reply, and check whether it's unfinished work (a running goal, an unmerged branch).

### 2. Issues first

Read the repository's open issues, read-only:
- Atlassian-enabled: Jira issues in the project, through the REST API.
- Otherwise: GitHub issues, through the GitHub API with the credential in `lib/credentials.md`. Pull requests in that list are not issues; note open dependency pull requests separately.

For each issue that belongs with this work: investigate (is it already fixed on `dev`, a duplicate, actionable?). Check `comms/open/` for a queued or running task that already names it. Issues that can't be acted on go back to the owner with what's missing. The planner never writes to the issue tracker.

### 3. Ask what is the owner's to decide

Only decisions that change what gets built: a product choice, a new interaction pattern (never invent one; name the existing part to follow or ask), anything that departs from the plan. One structured prompt per decision, recommendation first.

### 4. Write the task comm

Folder `comms/open/{UTC}-{slug}/`, file `{UTC}-{slug}.md`, using the template in `lib/planner-task-method.md`. Copy anything the builder needs from outside its head (the owner's screenshots, source files, designs) into `references/` or `assets/`, and say in the task what each one shows.

Combine related issues into one task. Split work that the owner will want to look at in between into separate goals.

### 5. Log it

Append to the plan's `decisions.md`: the date, what the owner decided, the task id, the issues it covers. If the plan's scope changed, snapshot `plan.md` and edit it.

### 6. Give the goal line

Follow `lib/planner-task-method.md`:

```
/goal {What must not happen, in the owner's words if he gave any}. Do {path to task A}, then {path to task B}. No promotion. Done when each task's Acceptance is met, or each item that needs the owner is named in the reply as an owner action.
```

- Name the task comms and their outcome only. Never mention the banner, replies or the finishing order.
- Never put an owner-only outcome in the line.
- Always end with the escape clause exactly as written.
- If a goal is running, say the line is for after its banner.

### 7. Report

```
Task: comms/open/{UTC}-{slug}/
Issues: {numbers, or none open}
Logged: plans/active/{plan}/decisions.md
Goal line (paste into Claude Code{, after the current goal's banner}):

/goal ...
```

## Guard Rails

- [ ] Comms check ran first; a running goal was detected and respected
- [ ] Request pressure-tested; contradictions with the plan raised before writing
- [ ] Open issues read; every task has an `Issues:` line; no issue doubled up with a queued task
- [ ] Task describes the problem and what must hold, not the code
- [ ] Backward compatibility stated
- [ ] Existing component or pattern named, or a new one decided with the owner
- [ ] Testing asks for no more than the head's rules
- [ ] Owner-only steps are owner actions, never Acceptance
- [ ] References copied into the task's folder
- [ ] Decision appended to `decisions.md`
- [ ] Goal line follows the rules and ends with the escape clause
- [ ] No git write commands run from the planner side

## Error Cases

**No head:** the project isn't set up for code. Point at `runesmith-workspace:init`.
**Issue read refused (no credential, allowlist, 401 or 403):** say which, write the task with `Issues: not read ({reason})`, and tell the owner.
**Request conflicts with an earlier decision:** quote the decision and the date, ask which stands, write nothing until answered.
**A queued task already covers the issue:** add to that task only if its goal hasn't started; otherwise write a new task that names the earlier one.
