---
name: check-comms
description: "Check Claude Code's work: read the goal status and every reply, verify against the repository read-only, look at the screenshots, archive finished tasks, log the outcome, report what needs the owner and give the next goal line. Use when the user says \"check comms\", \"what did CC do\", \"is CC done\", \"any messages from CC\", \"what does CC need\", or when a finished goal status comm is waiting."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Check Comms

Run when the owner says "check comms", and on your own when you see a goal finished with replies waiting. The protocol is `lib/comms-protocol.md`.

## References

- `agents/comms-triager.md` - verifies one task folder in isolation
- `lib/comms-protocol.md` - layout, types, lifecycle
- `lib/planner-task-method.md` - for fix tasks and the next goal line
- `lib/comms-check.md` - the lighter on-entry check other skills run
- `lib/qa-checklist.md` - the qa checklist page and gate
- `lib/atlassian-enabled.md`, `lib/jira-tags.md` - `ticket-transition` handling
- `lib/user-prompts.md` - structured prompts for every decision

## User input rules

Every decision that is the owner's is a structured prompt with the recommended option first. Report results plainly; ask only when the answer changes what happens next.

## Pre-Flight Checks

### 1. Locate comms

`{PROJECT}.cc/comms/open/`. Missing: the project has no head; point at `runesmith-workspace:init`. Empty: say so and stop.

### 2. Atlassian enabled?

Read the marker. Decides whether `ticket-transition` comms are handled.

## Workflow

### 1. Read the goal status comm first

The newest `open/{UTC}-goal-status/`. Note the goal text, the tasks it covered, anything the owner changed mid-goal, each task's state and the build number. If it's still `in-progress`, the goal is running: report its state and stop unless the owner asks for more.

### 2. Verify each task folder

For each `open/{UTC}-{slug}/` with a reply, run the `comms-triager` agent. It returns, per task:

- the reply's STATUS line, summary, Acceptance with proof, owner actions, what was left out;
- **repository checks, read only:** the branch and commit named exist; the build tag `v{number}` is on that commit; the goal's branch is gone after merge; no AI attribution in the new commits; the changelog is in the right shape; `dev` contains `qa`, `qa` contains `beta`, `beta` contains `main`;
- any `ambiguity`, `blocker`, `user-action` or `ticket-transition` comm in the folder.

Never run git write commands, including fetch, from the planner side.

### 3. Look at the evidence yourself

Open every screenshot in each `evidence/` folder. Compare it with the task and with how the rest of the app looks. Easy to miss:
- squeezed controls;
- raw ids or codes where names belong;
- wording the owner would reject;
- test data left in the owner's data;
- a home-made version of something the app already has.

### 4. Pressure-test the builder's choices

A choice that adds friction for the owner or users (an extra required setting, an extra step) is raised with a recommendation, even if the owner agreed to it in the builder's session.

### 5. Handle what the builder asked

- **`ambiguity` / `blocker`:** put the question to the owner as a structured prompt, then write an `answer` comm in that task's folder (`from: cowork`, `parent:` the question's id). The work resumes with a new goal line.
- **`ticket-transition`** (Atlassian only): ask the owner, then move the ticket through the Jira REST API and write an `answer`. Update tags per `lib/jira-tags.md`.
- **`user-action`:** list it for the owner. It stays in `open/` until he's done it.

### 6. Read the qa checklist page (after a promotion to qa)

Run `runesmith-sprint:qa-checklist` read (the page id is in the workspace CLAUDE.md; format and gate in `lib/qa-checklist.md`). Record each item's result in the promotion's comm folder and in `decisions.md`. For each failed item, write a fix task through `runesmith-sprint:task` with the owner's description and screenshot in `references/`; the builder opens the GitHub issue as the task's first step. The qa gate is clear when every owner item has passed and nothing is failing.

### 7. Archive

For each task whose reply is `complete`, or whose remaining items are all owner actions: move the whole folder to `comms/archive/{YYYY-MM}/{UTC}-{slug}/`. Move a finished goal status comm to `comms/archive/{YYYY-MM}/goal-status/`. Folders with an open question stay.

### 8. Log

Append to the plan's `decisions.md`: what merged, the build number, decisions made, anything still open.

### 9. Do what you can yourself

A file chore, a non-secret line in a settings file: do it. Don't hand it to the owner.

### 10. Report, briefly

- what's done, in plain words;
- what needs the owner: numbered actions, or questions as structured prompts;
- small issues spotted, queued or offered;
- any mistake the planner made, owned in one line;
- the next goal line.

## Guard Rails

- [ ] Goal status comm read first
- [ ] Every reply verified against the repository, read only; no git write commands
- [ ] Every screenshot opened and compared
- [ ] Builder choices that add friction raised with a recommendation
- [ ] Questions answered in the task's folder through `answer` comms
- [ ] Finished folders archived whole; open questions left in place
- [ ] Outcome appended to `decisions.md`
- [ ] Report is short and ends with the next goal line

## Error Cases

**Reply missing for a task the status comm calls merged:** report it; don't archive; the next goal line asks for the reply.
**Repository check fails** (tag missing, branch not deleted, attribution found, drift): report what failed and write a fix task; don't archive that task.
**Malformed front matter:** report the file and the parse error; leave it.
**Legacy numbered folders (`{PREFIX}-{NNN}-{slug}/`) or loose files in `open/`:** treat them as tasks; report them as legacy. `runesmith-workspace:init` renames them.
**Jira transition fails:** report the status code; leave the comm open.
