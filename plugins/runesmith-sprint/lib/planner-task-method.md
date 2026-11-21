# Planner task method: writing task comms and goal lines

How the planner writes a task comm that Claude Code (the builder) can act on from a cleared session, and the `/goal` line that starts it. Each rule is here because skipping it caused a real miss. Replaces `cowork-prompt-methodology.md`.

## Principles

1. **Self-contained.** The builder remembers nothing between sessions. Each task restates what already exists (by commit or "this exists now"), what's wanted and how it will be judged. Never "as we discussed".
2. **Describe the problem, not the solution.** Say what's wrong and what must hold. Don't tell the builder how to code it.
3. **Combine related issues** into one task. **Always state backward compatibility.**
4. **Name the existing part to follow.** When the app already has a component or pattern for the thing (a table, a pager, a dialog, a settings card), name it. For a new pattern, describe it once, decide it with the owner and record it as the app's standard. Never invent an interaction pattern in a task without asking.
5. **Ask for visual references** for anything visual. Put the owner's screenshots in `references/` and say what each shows.
6. **One proof, not more testing.** Never ask for more testing than the head's rules (test the change once, one proof; the full suite runs at promotion). No "full suite", repeated live checks or rehearsals unless the task changes the release flow.
7. **Ask the builder to say what it chose and why** wherever the task leaves room.
8. **Owner-only steps are owner actions,** never Acceptance the builder must meet.
9. **Check the plan first.** A request that contradicts the plan or an earlier decision is raised before writing.
10. **Log it.** Append the decision to `decisions.md`; snapshot and edit `plan.md` when scope changes.

## Template

```markdown
---
id: {UTC}-{slug}
from: cowork
to: cc
type: task
parent:
plan: {plan slug}
status: open
created: {ISO time, UTC}
---

# {Title in plain words}

Issues: {#numbers, or "none open at the time this task was written"}

## The problem
What's wrong or missing, from the owner, in plain words, with evidence: his words quoted, screenshots in `references/` (say what each shows), what the code does today if you read it.

## What the owner decided ({date})
His decisions, verbatim where it matters.

## Requirements
What must hold. Not how to code it. Name the existing component or pattern to follow.

## Backward compatibility
What existing data, settings and behavior keep working.

## Testing
The head's testing rule, and the one proof that shows this change works (a screenshot, the one live check, or a read-back). Nothing more.

## Git
Part of the goal's branch; pull request into `dev`; changelog lines, or "No changelog: {why}"; no promotion unless asked; no AI attribution.

## Acceptance
- {observable result}
- {observable result}
- Done when each Acceptance item is met, or each item that needs the owner is named in the reply as an owner action.
- Reply comm in this folder with `parent: {id}`.
```

## The `/goal` line

```
/goal {What must not happen}. Do {path to task A}, then {path to task B}. No promotion. Done when each task's Acceptance is met, or each item that needs the owner is named in the reply as an owner action.
```

- **Chaining is fine:** several tasks of the same plan in one goal, in order, with one banner at the end. Use separate goals only when the owner wants to look at something between tasks.
- **Name the task comms and their outcome only.** Never mention the banner, replies or the finishing order; those live in the builder's rules. A goal that said "one banner at the end" made the stop hook demand the banner be the last message, and it looped nine times.
- **Never put an owner-only outcome in a goal line** (a token, a click, a promotion). The stop hook reads the line literally and re-prompts until its cap.
- **Always end with the escape clause,** exactly: "Done when each task's Acceptance is met, or each item that needs the owner is named in the reply as an owner action."
- **State what must not happen** ("No promotion", "Hold the beta promotion (owner's word)").
- **While a goal runs,** queue the next line for after its banner. To add a task mid-run, the owner can send a new `/goal` with the full list; the builder records the change in the status comm.
- **Promotion goals** are written the same way and name the build number being promoted.

## When the owner reports a problem with a screenshot

- Find the root cause before writing a task: read the code or the last reply; check whether a goal is still running or a branch is unmerged.
- Write the fix as a task with the screenshot in `references/`, and give the goal line.
- If a goal is running, queue the task for after its banner. Never edit a task the builder has already started.
