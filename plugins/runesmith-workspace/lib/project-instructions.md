# Project Instructions vs CLAUDE.md

Cowork has **two distinct project-context surfaces**. They look similar but carry fundamentally different content. Skills in this marketplace must address both - and must NOT mix the two.

## The distinction (HARD RULE)

| Surface | Carries | Why it lives there |
|---|---|---|
| **Project Instructions** (Cowork UI field) | **Behavioral**: project mission, Cowork's role, rules that apply to every conversation | Doesn't change with files. Loaded as system prompt for every chat. |
| **`CLAUDE.md`** (file at workspace root) | **Structural**: folder layout, where things live, plugin paths, file conventions | Changes as the workspace grows. Auto-loaded as file context at session start. |

The line: **behavior vs structure**.

- "Use structured prompts" → behavioral → Project Instructions
- "Plans live at `plans/active/<slug>/`" → structural → CLAUDE.md
- "Never push commits without consent" → behavioral → Project Instructions
- "The marketplace source lives at `runesmith.cc/runesmith/`" → structural → CLAUDE.md
- "You are Cowork, the planning partner" → behavioral → Project Instructions
- "8 plugins under plugins/*" → structural → CLAUDE.md (and changes as plugins are added)

Why this matters: if behavior bleeds into CLAUDE.md, the role drifts whenever the file structure changes. If structure bleeds into Project Instructions, the role becomes stale the moment a folder moves. They have different update cadences and must stay separate.

## What Project Instructions MUST NOT contain

- File paths
- Plugin names / counts
- Folder layouts
- Version numbers
- Command names with file refs (e.g. "run `python scripts/audit.py`" - the path could change)
- Anything that would have to be re-edited when the workspace is restructured

If you find yourself writing a path or a file detail, it belongs in CLAUDE.md.

## What Project Instructions MUST contain

- Project mission / purpose (what is this project?)
- Cowork's role within the project (who are you?)
- Behavioral rules (when do you act / not act?)
- Consent gates and trigger phrases
- Reference to `@CLAUDE.md` for structure ("see CLAUDE.md for folder layout")
- Optionally: how-we-work principles, communication preferences

## What CLAUDE.md handles

Everything structural - folder layout, where files live, marker-bounded skill-managed sections (folder-conventions, agent-ops), workspace state. It changes as the project grows. Skill operations like `reallocate`, `bootstrap-cc`, etc. all edit CLAUDE.md.

## Agent access

- I can read + write CLAUDE.md directly via file tools.
- I CANNOT see or edit Project Instructions. It lives only in Cowork's UI. I can only produce TEXT for the user to paste.

## Why agents forget this distinction

The agent sees only files. The UI field is invisible. Without an explicit reminder, the agent:
- Treats CLAUDE.md as the only project context (it isn't - the role lives elsewhere)
- Misses that the user has separate UI instructions
- Conflates the two when refactoring project context
- Writes structural details into the Project Instructions text it generates (bug: those details belong in CLAUDE.md, not Project Instructions)

## Why agents forget this distinction

The agent only sees files. The UI field is invisible to it. Without an explicit reminder, the agent will:
- Assume CLAUDE.md carries everything (it doesn't - it can't carry the role/persona effectively because it's also describing folder state)
- Miss that the user has separate UI instructions
- Conflate the two when refactoring project context

## Skill responsibility

Any skill that mutates project-level context (`reallocate`, `bootstrap-cc`, `enable`, similar) MUST:

1. **Edit `CLAUDE.md`** for folder/state changes (marker sections, structure references)
2. **Produce Project Instructions text** for the user to paste into Cowork's UI when the project's role/mission has shifted (or on first bootstrap)
3. **Surface the proposed text explicitly** - don't bury it. The user has to manually paste, so the text should be in a single copy-friendly code block at the end of the skill's output.

## Template: Project Instructions for a RuneSmith-bootstrapped workspace

This is the canonical template. It is PURELY behavioral - no file paths, no folder layouts, no version numbers. Everything structural lives in CLAUDE.md and is referenced via `@CLAUDE.md`.

When reallocate emits this for a user, it substitutes `{PROJECT_NAME}` (workspace folder name) and, per `lib/project-mission-inference.md`, attempts to fill the PROJECT section by scanning workspace signal (README, source-docs, prior CLAUDE.md preamble, package manifest). The user always sees the draft via a structured prompt and can Accept / Edit / Skip. If no signal hits or the user picks Skip, the placeholder shown below is emitted instead. If atlassian is enabled (`.atlassian-enabled` marker present), append the atlassian block at the bottom.

```
# {PROJECT_NAME}

## PROJECT
{One- to three-sentence description of the project. Reallocate scans workspace
signal (README, source-docs, prior CLAUDE.md preamble, package manifest) and
proposes a draft via structured prompt; user can Accept, Edit, or Skip. This
placeholder appears only when no signal hits or the user picks Skip.}

## ROLE
You are Cowork - a pair-programming and planning partner for {PROJECT_NAME}.
Your job is to help plan changes before they happen, structure the workspace,
co-author documentation and tickets, capture decisions, and coordinate
between Cowork-side planning and Claude Code-side implementation when CC is
in play.

You do not write application code directly in this workspace. Code work
happens inside the project's CC head - see @CLAUDE.md for that boundary.

## RULES
- Read @CLAUDE.md at session start. It carries the current folder structure,
  the canonical workspace conventions, and the agent operating principles
  that govern how you interact with files and external systems.
- Git commits and pushes require an explicit user trigger ("commit and push",
  "push it", "ship it"). Stage freely; never push on your own judgment.
- Use structured prompts (single-pick / multi-pick / text-input forms) for
  any user decision - including consent before destructive operations.
  Never freeform yes/no in chat.
- Confirm scope before mutating files. Restate the plan; wait for explicit go.
- Snapshot before destructive operations. Per the operating principles in
  CLAUDE.md, every move or delete goes through archive/_pre-{operation}/.
- File operations in this workspace are your job. When something needs to
  be moved, renamed, or deleted, do it directly. Don't defer file chores
  to the user.

## HOW WE WORK
- Plans before destructive work. Capture intent before execution.
- Notes accumulate across sessions - they're shared working memory.
- Surface tech debt when you see it. Don't paper over.
- Be direct. Pressure-test ideas before validating them. Lead with the
  weakest point.
```

## Atlassian supplement block

Emitted ONLY by `runesmith-sprint:enable` for the user to paste into their Project Instructions (appended below the base content). If atlassian is not enabled, this block must NOT appear in the Project Instructions - don't mention Jira or Confluence rules speculatively.

Wrapped in HTML-comment markers so the block can be removed cleanly by `runesmith-sprint:disable`:

```
<!-- runesmith:atlassian-start -->
## ATLASSIAN
This project uses Atlassian Cloud (Jira + Confluence). Sprint workflow is
active; plans flow into Jira tickets, decisions and design docs flow into
Confluence pages.

- Jira owns work state. Confluence owns durable docs.
- Read freely. Mutations (ticket create, page publish, transition, comment)
  require an explicit user trigger phrase: "make the ticket", "create the
  document", "publish the page".
- For Claude Code-side work on tickets, see the comms-protocol details in
  @CLAUDE.md.
<!-- runesmith:atlassian-end -->
```

`runesmith-sprint:enable` emits this for the user to paste at the end of their existing Project Instructions. `runesmith-sprint:disable` emits instructions to remove everything between (and including) the `<!-- runesmith:atlassian-start -->` and `<!-- runesmith:atlassian-end -->` markers.

Same marker pattern lets future opt-in features add bounded sections without conflicting:
- `<!-- runesmith:atlassian-start/end -->` - sprint:enable / sprint:disable
- `<!-- runesmith:{feature}-start/end -->` - future feature plugins

Reallocate's base emission produces no such markers (only the unmarked base sections), so user-managed and skill-managed content remain distinguishable.

## Project Instructions is a Cowork-only feature

Claude Code (CC) does NOT have a Project Instructions UI field. CC's project context is the `CLAUDE.md` inside the repo. So:

- **Cowork-side skills** in this marketplace emit Project Instructions text when they mutate project context.
- **CC-side skills** (anything in `cc-skill-templates/`, and any work happening inside `{PROJECT}.cc/<repo>/`) do NOT emit Project Instructions text - that field doesn't exist for CC.

## Skills that produce Project Instructions text

- `runesmith-workspace:reallocate` - emits proposed text on every run. On a fresh workspace, this is the user's first chance to set the project role/mission. On a re-run, it offers an updated version reflecting any structural changes.
- `runesmith-sprint:enable` - emits a supplemental block to add Atlassian-specific rules to the existing Project Instructions (Jira tickets, Confluence pages, sprint workflow context). The user appends this to their existing Project Instructions; the skill does not replace.

`runesmith-cc:bootstrap-cc` does NOT emit Project Instructions text. It writes the CC head's CLAUDE.md (which is CC's project context, not Cowork's). Keep these concerns separate.
