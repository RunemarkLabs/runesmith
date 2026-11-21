---
name: qa-checklist
description: "Publish the owner's qa checklist for the build on qa to the project's one checklist page, or read its results for the qa gate. Use when a build is promoted to qa, when the user says \"publish the checklist\", \"update the qa checklist\", \"what's left to test\", \"read the checklist\", or when check-comms needs the qa results."
compatibility: Runs in the planner chat with the project's workspace folder connected and the artifact tools available.
---

# QA Checklist

Keeps the project's one checklist page current and reads it back. Format, data model and gate: `lib/qa-checklist.md`.

## References

- `lib/qa-checklist.md` - the checklist format, the page, the data, the gate
- `page.html` (beside this file) - the page template
- `lib/comms-protocol.md` - where results are recorded
- `lib/user-prompts.md` - structured prompts

## Publish (after a promotion to qa)

1. **Find the page.** Read `QA checklist page: {slug}` from the workspace CLAUDE.md. If it's missing, this is the project's first promotion to qa: create the page in step 3.
2. **Build the item list.** Read `qa/checklist.md` at the promoted commit, read only, from the head's repo (never through git write commands). Keep only owner items ("Checked by the owner, ..."). For each, compute `key` per `lib/qa-checklist.md`.
3. **Create the page (first time only):** read the artifact server's pages guide, then publish `page.html` as a new artifact titled "{Project} QA checklist" with icon "checklist". Then declare capabilities `{db: {}, user: {}, assets: {}}`. Record `QA checklist page: {slug}` in the workspace CLAUDE.md, outside the marker sections. When this template changes in a later RuneSmith release, republish it to the same slug.
4. **Write the data:** `db_write` to `checklist/current`: `{project, build, target: "beta", items}`. Results stay as they are; unchanged items keep their pass.
5. **Report:** the page link, the build, how many owner items, and how many already passed from earlier builds.

## Read (check comms, or "what's left")

1. `db_get` `checklist/current`; `db_list` `results`.
2. Per item: passed, failing (with the owner's note and whether a screenshot is attached) or left.
3. For check comms: record the states in the promotion's comm folder and `decisions.md`; hand failing items to `runesmith-sprint:task` as fix tasks with the note and screenshot in `references/`.
4. **The gate:** clear when every owner item passed, nothing is failing, and beta isn't held.

## Guard Rails

- [ ] One page per project; never a new page per build
- [ ] The page is republished only for a template change; each build only writes data
- [ ] Only owner items on the page
- [ ] Keys computed from wording, so unchanged items keep their pass
- [ ] `qa/checklist.md` read without git write commands
- [ ] The page id recorded in the workspace CLAUDE.md, outside marker sections
- [ ] Failing items become fix tasks; the planner opens no issues itself

## Error Cases

**Artifact tools unavailable in this session:** say so; the owner can tick `qa/checklist.md` in a pull request as a fallback.
**Recorded page no longer exists:** say so and offer to create a new one through a structured prompt.
**`qa/checklist.md` missing or malformed:** report it; the promotion reply should have listed the owner items; write a task for Claude Code to fix the file.
**Database write refused:** report the error code; nothing on the page changes.
