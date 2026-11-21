# How-to: Set Up a New Project

You have a folder for a new project and want it ready to work in: workspace layout, project context, and for a code project the Claude Code head, its repo and branches.

For the model behind these steps, read `docs/AGENT_PRIMER.md`.

## Prerequisites

- RuneSmith installed (see `INSTALL.md`): at least `runesmith-core` and `runesmith-workspace`; add `runesmith-cc` and `runesmith-sprint` for a code project.
- A Claude Project for this work, with the project folder connected.
- For a new GitHub repo: `RUNESMITH_GITHUB_PAT` in the workspace `.credentials`. Init tells you if it's missing.

## 1. Run init

```
/runesmith-workspace:init
```

Init reads the folder, then asks only what changes the result. Every question is a structured prompt with the recommended option first.

1. **What is this project?** It drafts one to three sentences from what it finds. Use it or edit it.
2. **Will this project hold code?** Yes builds the Claude Code head. No keeps it a workspace-only project.
3. **Track work in Jira and Confluence?** Default no. Yes asks for the site, project key, board and space.
4. **Only when needed:** which repo is primary when there are several, the head name when it can't be derived, where old root `tickets/` belong.
5. **Consent:** a table of every move. Apply, Preview only, or Cancel. Nothing moves before Apply, and everything that moves is snapshotted first to `archive/_pre-init-{UTC}/`.

For a code project it continues:

6. **Repos:** none yet, clone an existing repo, or create a new one (name, description, visibility, owner). Repeat as needed.
7. **Changelog readers:** default "For users" and "For admins".
8. **Dev data:** may Claude Code wipe dev's data when it resets dev? Default no.
9. **Claude Code's Jira token** (Jira projects only): its own read-only token (default) or reuse yours.

## 2. What init builds

- The workspace folders (`_INBOX/`, `plans/`, `notes/`, `drafts/`, `research/`, `source-docs/`, `archive/`), `STRUCTURE.md`, and the `folder-conventions` and `agent-ops` sections of `CLAUDE.md`.
- `.gitignore` patterns for `.credentials`, snapshots, `_INBOX/` and open comms.
- For a code project, through `/runesmith-cc:head`:
  - `{PROJECT}.cc/CLAUDE.md` with the builder's standing rules;
  - `.claude/settings.json` (attribution off, stop hook cap of 3, code-simplifier on, an empty cross-project list) and `.claude/README.md` explaining it;
  - the `runesmith-clean-code`, `runesmith-code-tech-debt` and `runesmith-release` skills;
  - `comms/open/` and `comms/archive/`;
  - the repo, with `dev`, `qa` and `beta` branches created from `main`, the no-attribution commit hook, and a repo `CLAUDE.md` stub kept out of git.
- With Jira on, the `runesmith-sprint:enable` steps (see `docs/howto/enable-atlassian.md`).
- When a stack tool such as runestack is installed, init runs its init last.

## 3. Credentials

Init checks each key the answers need and reports it as set or missing. It never asks for a value in chat. For a missing key it names the file (`.credentials` at the root for yours, `{PROJECT}.cc/.credentials` for Claude Code's) and the key; paste the value and tell it you're done.

## 4. Paste the Project Instructions

Init ends with a complete Project Instructions block in a code block. Paste it into the Claude Project's instructions, replacing what's there. Re-running init produces a fresh block.

## 5. Install the guardrail (once per machine)

Init gives the command for your system. See `docs/howto/install-guardrail.md`.

## 6. Start working

```
/runesmith-core:plan
```

Then `/runesmith-sprint:task` to hand the first piece of work to Claude Code. See `docs/howto/daily-workflow.md`.

## Verify

```
{project}/
├── _INBOX/  plans/  notes/  drafts/  research/  source-docs/  archive/
├── {PROJECT}.cc/          code projects only
│   ├── CLAUDE.md
│   ├── .claude/settings.json
│   ├── .claude/skills/runesmith-*/
│   ├── comms/
│   └── {repo}/            on dev, with qa and beta beside main
├── CLAUDE.md
├── STRUCTURE.md
└── .credentials
```

`/runesmith-devtools:help` lists every installed skill.

## What can go wrong

**Plugins not loading.** Quit the app fully and reopen it.

**Init asks for access to a folder.** The session isn't connected to the project folder. Approve the request, or connect the folder and run init again.

**A marker without its end.** Init stops and names the file. Fix the marker by hand (or restore from the snapshot), then re-run.

**New repo fails with 422.** The name is taken on GitHub. Pick another name, or clone the existing repo.

**Claude Code says code-simplifier is enabled but not installed.** Run once in the head: `claude plugin install code-simplifier@claude-plugins-official --scope project`.
