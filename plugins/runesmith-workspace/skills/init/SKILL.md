---
name: init
description: "Set up a project: workspace folders, plans, CLAUDE.md and Project Instructions, then for code projects the Claude Code head with its skills and comms, Jira and Confluence if wanted, and runestack's init when installed. Re-run any time to normalize and refresh. Use when the user says \"init\", \"set up this project\", \"initialize the workspace\", \"new project\", \"reallocate\", \"normalize the workspace\", or \"refresh the project setup\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Init

The single entry point for a project. It replaces `reallocate`. Safe to re-run: it normalizes what's there, refreshes the skill-managed parts, and never touches what the project added itself.

## References

- `lib/folder-conventions.md` - canonical layout, root keep-list, destination map
- `lib/claude-md-section.md`, `lib/claude-md-agent-ops-section.md` - the two marker sections written into CLAUDE.md
- `lib/STRUCTURE.template.md` - written to the root as `STRUCTURE.md`
- `lib/project-instructions.md` - what goes in the Project Instructions block
- `lib/project-mission-inference.md` - drafting the project description from workspace signal
- `lib/credentials.md` - where keys live and how they're read
- `lib/agent-operating-principles.md` - file access, deleting, snapshots
- `lib/naming.md` - folder name normalization
- `lib/comms-check.md` - runs first on a re-run
- `lib/user-prompts.md` - structured prompts

## Interview rule

Show first, then ask. Ask only when the answer changes what gets built. When there's an obvious default, do it and say so. Every question is a structured prompt with the recommended option first.

## Workflow

### 1. Find the project (no question)

- Read the session's connected folders. The project is the folder the user named, or the only connected folder. If it isn't connected, or the connected folder is the wrong one (empty, or a different project), request access to the right folder before anything else.
- Work on the user's files through the shell on their computer or the connected-folder tools. Never through the chat's own file tools, which write somewhere the user never sees.
- On a re-run, run `lib/comms-check.md` first.

### 2. Read what's there (no question)

Classify every root entry against the keep-list in `lib/folder-conventions.md`: canonical folders and files, git repos (any subfolder with `.git/`), an existing `{PROJECT}.cc/` or legacy `claude-code/`, legacy root `tickets/`, legacy numbered comm folders in an existing head, and everything else. Read CLAUDE.md, including any marker sections and whether each has both its start and end marker.

**A start marker without an end marker** means the file is damaged. Stop and report the file and the marker; never append a second copy.

### 3. What is this project?

Draft one to three sentences from workspace signal per `lib/project-mission-inference.md` (README, source documents, CLAUDE.md preamble outside markers, package manifest). Show the draft and ask:
- **Use this** (default)
- **Edit** (text input)

With no signal, offer two short drafted descriptions built from what the owner has said in the chat (the question tool needs at least two options), with "Other" for his own words. There is no placeholder option.

### 4. Will this project hold code?

- **Yes:** builds the Claude Code head (steps 8 to 13). The Project Instructions role becomes "planner, writes no application code".
- **No:** stops after the workspace. The role becomes "plans and does the work directly".

On a re-run with a head already present, skip this question.

### 5. Track work in Jira and Confluence?

- **No** (default for a new project)
- **Yes:** site address, Jira project key, the board (picked from the project's boards), and the Confluence space. Then run the `runesmith-sprint:enable` workflow with those values, after the head exists for code projects.

On a re-run, skip this question when `.atlassian-enabled` exists. `runesmith-sprint:enable` and `disable` change it later.

### 6. Only when triggered

- **Several git repos at the root:** which is the primary repo (it names the head).
- **The head name can't be derived:** text input, with the normalized form shown.
- **Legacy `tickets/` at the root:** which plan each ticket belongs to, or archive it.

### 7. Consent to the move plan

Show the plan as a table, one row per move, with the head line on top:
- **Apply** (default)
- **Preview only**
- **Cancel**

Unknown root items go to `_INBOX/` with no per-item question. Nothing moves before Apply.

Then, before the first move: ask once for delete permission on the project folder (git and moves need it). Snapshot everything that will move or change to `archive/_pre-init-{UTC}/`.

### 8. Code projects: the head

Run the `runesmith-cc:head` workflow:
- move git repos found at the root into `{PROJECT}.cc/`;
- rename `claude-code/` to `{PROJECT}.cc/`;
- write or refresh the head's files, settings and skills;
- rename legacy numbered comm folders in `comms/open/` to `{created UTC}-{slug}/`.

### 9. Code projects: the GitHub account

Which GitHub account pushes this project's repos (Ben, 2026-11-21: every project names its account, so one machine can push for several accounts without them crossing)? Show what's known, then ask:
- **{login}** (default): the account behind `RUNESMITH_GITHUB_PAT`, from `GET https://api.github.com/user`, when the key is set
- **Another account:** text input, the GitHub username

On a re-run, skip this when the head already records an account. Recorded as `githubAccount` in the head's marker file; `runesmith-cc:head` writes it into every repo address.

### 10. Code projects: repos

Show the repos already in the head, then ask:
- **None yet** (default when repos exist)
- **Clone an existing repo:** its address
- **Create a new repo:** name, description, visibility (private or public), owner. Needs `RUNESMITH_GITHUB_PAT`.

Repeat until the owner picks None.

### 11. Code projects: changelog readers

Default "For users" and "For admins". Ask only to change them. Written into the head's rules.

### 12. Code projects: dev data

"May Claude Code wipe dev's data when it resets dev?"
- **No, keep dev's data** (default)
- **Yes**

Written into the head's rules as the owner's answer.

### 13. Code projects with Jira: Claude Code's token

- **Its own read-only token** (default)
- **Reuse yours** (Claude Code can then change Jira directly)

### 14. Workspace (no question)

- Create the required folders from `lib/folder-conventions.md`, including `drafts/handoffs/` and `plans/active/` (every plan carries `decisions.md`).
- A new CLAUDE.md gets a short preamble: the project name and the description from step 3. An existing preamble is left as it is.
- Write `STRUCTURE.md` from `lib/STRUCTURE.template.md`.
- Write or refresh the `folder-conventions` and `agent-ops` marker sections in the root CLAUDE.md. Never touch content outside them, or any other tool's marker sections.
- Add `.gitignore` patterns: `_INBOX/*`, `archive/_pre-*/`, `.credentials`, `{PROJECT}.cc/.credentials`, `{PROJECT}.cc/comms/open/*`.

### 15. Credentials (no question)

Per `lib/credentials.md`: check each key the answers above need, in the right file (the planner's at the root, Claude Code's in the head). Create a missing file with the key names and empty values. Report each key as set or missing. For missing keys, tell the owner which file to open and which keys to paste, then run the health checks once he says it's done. Never ask for a value in chat.

### 16. Guardrail (no question)

The guardrail installs into the user's Claude Code settings, which this session can't reach. Code projects get the one command to run for their system (from `runesmith-cc:guardrail`).

### 17. runestack (no question)

Code projects only. If runestack is installed, run `runestack-index:init`. It checks the head, loads its `runestack-*` skills, writes its `runestack-credentials` and `runestack-stack` sections, and asks the stack questions. If it isn't installed, say so in one line.

### 18. Project Instructions (no question)

A fresh, complete block every run, per `lib/project-instructions.md`: the project description from step 3, the role from step 4, the rules, and the Atlassian supplement when Jira is on. No file paths in it; it points at CLAUDE.md. Show it in a code block for the owner to paste into the Project's instructions on claude.ai, replacing what's there.

### 19. Report

```
Project: {name}  ({code project | workspace only})
Moved: {n} items (snapshot: archive/_pre-init-{UTC}/)
Head: {PROJECT}.cc/  (repos: {list}; skills refreshed: {list})
GitHub account: {account}  (login check: {ok | run the line shown})
Jira and Confluence: {on: project, space | off}
runestack: {ran runestack-index:init | not installed}
Credentials: {all set | missing: KEY in file, ...}
Guardrail: run {command}

Project Instructions (paste into the Project's instructions on claude.ai):
{block}
```

## Re-running

- No moves needed: skip the snapshot and consent.
- Refresh `STRUCTURE.md`, both marker sections, the head's files, settings and skills, and the Project Instructions block.
- Skip questions already answered: the project description (reused from CLAUDE.md's preamble), code or not, Jira on or off.
- Plans with `status: done` move to `plans/archive/{YYYY-MM}/{slug}/`.

## Guard Rails

- [ ] The right folder is connected before any file work
- [ ] All file work on the user's disk, never through the chat's own file tools
- [ ] Only the reviewed questions asked; edge-case questions only when triggered
- [ ] A damaged marker stops the run
- [ ] Delete permission asked once, before the first move
- [ ] Snapshot before any move or change
- [ ] Consent before any move
- [ ] Repos moved as whole units; never entered
- [ ] Other tools' marker sections untouched
- [ ] Credentials never asked for, printed or read beyond a set-or-missing check
- [ ] runestack's init called when installed
- [ ] Fresh Project Instructions block with no file paths

## Error Cases

**Wrong or empty folder connected:** request access to the project folder; stop until granted.
**Delete permission declined:** carry on with moves (they don't need it); skip git work and say which steps need it; never delete.
**Destination exists with different content:** structured choice: keep existing / replace from source / skip.
**Several `*.cc/` folders:** structured choice of which is the head.
**A health check is refused by the session's network allowlist:** say the host isn't reachable from this session; the key may be fine.
