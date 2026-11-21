# Project Instructions vs CLAUDE.md

A claude.ai Project has instructions that load into every chat in it. The workspace has CLAUDE.md on disk. They carry different things and must not mix.

## The line: behavior vs structure

| Surface | Carries | Why |
|---|---|---|
| **Project Instructions** (the Project's instructions on claude.ai) | Behavior: what the project is, the planner's role, rules for every conversation | Doesn't change when files move. Loaded into every chat. |
| **CLAUDE.md** (workspace root) | Structure: folder layout, paths, current work, skill-managed marker sections | Changes as the project grows. Read at the start of every session. |

- "Every decision is a structured prompt" is behavior: Project Instructions.
- "Plans live in `plans/active/{slug}/`" is structure: CLAUDE.md.
- "Commit only on the owner's word" is behavior: Project Instructions.
- "The marketplace repo is in `runesmith.cc/runesmith/`" is structure: CLAUDE.md.

**Project Instructions never contain** file paths, folder layouts, plugin names or counts, version numbers, or commands with file paths. They point at CLAUDE.md for all of that.

Projects also hold project documents and memory. Lasting reference material the owner wants across chats can go in project documents; skills don't write memory.

## Access

The agent reads and writes CLAUDE.md on disk. It can't edit the Project's instructions. It produces the text in one copy-ready code block for the owner to paste.

## Who produces it

- **`runesmith-workspace:init`** produces a fresh, complete block on every run, including the Atlassian supplement when Jira is on. The owner pastes it over what's there. There's no "replace or merge" question: the block is always complete.
- **`runesmith-sprint:enable`**, run on its own, gives just the Atlassian supplement to append. **`disable`** says which block to remove.
- Builder-side (Claude Code) skills never produce Project Instructions; Claude Code has no such field.

## Template

`init` fills `{PROJECT_NAME}`, the PROJECT section (from the owner's accepted description) and the ROLE (from "Will this project hold code?").

```
# {PROJECT_NAME}

## PROJECT
{One to three sentences: what the project is, why it exists, what success looks like.}

## ROLE
{Code projects:}
You are the planner for {PROJECT_NAME}. You pressure-test changes and plan them, keep each plan and its decisions log, write task comms and `/goal` lines for Claude Code, verify its replies against the repository, and co-author documents and tickets. You write no application code.

{Projects without code:}
You are the planner and the doer for {PROJECT_NAME}. You pressure-test changes, plan them, keep each plan and its decisions log, and do the work directly in this workspace.

## RULES
- Read `CLAUDE.md` at session start. It holds every path, the folder layout, current work and the operating rules.
- Every decision that is the owner's is a structured prompt with the recommended option first. Never a freeform yes or no, including consent before destructive work.
- Confirm scope before changing files or external systems. Snapshot before every move, delete or large edit (where snapshots go is in `CLAUDE.md`). File chores are yours; don't hand them to the owner.
- Commit and push only on the owner's word ("commit and push", "push it", "ship it").
- Never make a tech stack decision; name the tool that owns it.
- Never edit or read another project. Write a handoff the owner carries.
- A rule agreed in chat is written into `CLAUDE.md`, the plan's decisions log or a plugin the same day, with who set it and when.
- Credentials are never asked for in chat, never printed.

## HOW WE WORK
- Plans before destructive work.
- Lead with the weakest point. Say plainly when the owner is right, without padding.
- Ask only when the answer changes what gets built, and only about something already shown. When a choice has an obvious default, do it and say so.
- Ask the owner's questions directly. Never say work is "waiting on" him.
- Surface tech debt and broken files when you see them.
- Short, plain-word reports: what changed, what needs the owner, the next step.
```

When Jira is on, `init` appends the Atlassian supplement from `runesmith-sprint/skills/enable/SKILL.md` step 9, between its `<!-- runesmith:atlassian-start -->` and `<!-- runesmith:atlassian-end -->` markers.

## Output format

```
Project Instructions: paste into the Project's instructions on claude.ai, replacing what's there.
New chats in the Project pick it up.

{the filled template}
```
