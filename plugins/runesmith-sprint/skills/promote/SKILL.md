---
name: promote
description: "Move a build along dev, qa, beta, main on the owner's word: check the gate, write the promotion task and its /goal line, record holds and overrides. Use when the user says \"promote to qa\", \"QA passed\", \"promote to beta\", \"ship it\", \"hold beta\", \"don't promote until I say\", or \"lift the hold\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Promote

Promotions happen only on the owner's word, in his words, and Claude Code carries them out. This skill checks the gate, writes the promotion task comm, and gives the goal line. What each branch deploys, and where, belongs to the stack tooling (runestack when installed).

## References

- `lib/comms-protocol.md`, `lib/planner-task-method.md` - the task and goal line
- `lib/qa-checklist.md` - the qa gate
- `runesmith-sprint:qa-checklist` - publishing and reading the checklist page
- `lib/comms-check.md` - runs first
- `lib/user-prompts.md` - structured prompts

## The chain

`dev` to `qa`, `qa` to `beta`, `beta` to `main` (prod). Every branch moves only by pull request after the build check. A number always points at one tested commit: `qa` and `beta` carry the promoted build's number, and "ship it" rebuilds nothing.

## Pre-Flight

### 0. Comms check

See `lib/comms-check.md`. Don't promote while a goal is running or replies are unchecked: offer check comms first.

### 1. The owner's word

Take the request in his words. Confirm the build with a structured prompt showing the build number and what it contains (from the decisions log): **Promote build {number}** / **Cancel**.

## Workflow

### Promote to qa ("promote to qa")

1. **Gate:** dev's newest numbered build (the last goal status comm's build, or the one the owner names). No beta hold matters here.
2. **Task comm:** "Promote build {number} to qa". Requirements:
   - run the full suite and every live check on `dev` at that build, plus the automated checklist items;
   - promote only if everything passed: pull request into `qa` with "Requested by: {owner's words}", fast-forward `qa` to exactly that commit after the build check;
   - keep qa's data;
   - list the owner items from `qa/checklist.md`, with anything the run couldn't check.

   Acceptance: qa runs build {number}; the reply lists test counts and times, and the owner items.
3. **Goal line:** `/goal Promote build {number} from dev to qa only. Do {task path}. No other promotion. Done when ...` with the escape clause.
4. **After the reply** (check comms): run `runesmith-sprint:qa-checklist` publish, then give the owner the page link.

### Promote to beta ("QA passed", "promote to beta")

1. **Gate:** read the checklist page (`runesmith-sprint:qa-checklist` read). Clear when every owner item passed, nothing is failing, and beta isn't held.
   - **Not clear:** name what's blocking. The owner may override in his own words; record the override, verbatim, in `decisions.md` and in the task.
2. **Task comm:** "Promote build {number} to beta". Requirements:
   - a release commit turns the changelog's Unreleased into `## {number} ({date})`, naming the goal builds it includes;
   - pull requests into `qa` and `beta`, both fast-forwarded to it;
   - `qa` merged back into `dev`;
   - the checklist file carries the same numbered version.

   If QA got fixes since the passing run, the full suite runs once on the commit being promoted.
3. **Goal line:** as above, "from qa to beta only".

### Ship it ("ship it")

1. **Gate:** beta has the build; the owner said "ship it".
2. **Task comm:** "Ship build {number}": pull request `beta` into `main` with "Requested by: {owner's words}". Nothing is rebuilt; the next build carries the new MINOR.
3. **Goal line:** as above, "from beta to main only".

### Hold or lift ("hold beta", "don't promote to beta until I say", "lift the hold")

Record it in `decisions.md`, in his words, with the date. While held, the beta gate answers HELD, and every goal line carries "Hold the beta promotion (owner's word)". Lifting needs his word too.

### Fix found in qa or beta

A fix task into that branch (`qa` or `beta`), merged back down in the same task (`beta` into `qa`, `qa` into `dev`), with the changelog and checklist rebuilt from both sides. A fix into beta takes the next build number.

## Report

```
Promotion: build {number}, {from} to {to}
Gate: {clear | overridden: "{owner's words}" | held}
Task: comms/open/{UTC}-{slug}/
Goal line:

/goal ...
```

## Guard Rails

- [ ] Only on the owner's word, recorded in his words
- [ ] One step of the chain per promotion; never skips a stage
- [ ] Build number confirmed through a structured prompt
- [ ] qa gate read from the checklist page; overrides recorded verbatim
- [ ] Holds recorded and carried into every goal line until lifted
- [ ] No branch names or deploy targets invented; what each branch deploys is the stack's
- [ ] No git write commands from the planner side

## Error Cases

**A goal is running:** promote after its banner; offer check comms then.
**No numbered build on dev:** the last goal didn't number its build; write a task to do that first.
**Drift (`dev` lacks a `qa` commit, or `qa` lacks a `beta` one):** promotions refuse; write a merge-back task first.
**Checklist page missing:** publish it with `runesmith-sprint:qa-checklist` before reading the gate.
