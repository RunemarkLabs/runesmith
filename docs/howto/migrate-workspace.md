# How-to: Bring an Existing Workspace Up to Date

Two cases, one command:

- A folder that predates RuneSmith: loose files at the root, git repos in odd places, notes scattered around.
- A RuneSmith workspace from an earlier release: `claude-code/` or an old `.cc` head, numbered comm folders, skills deployed under old names.

`/runesmith-workspace:init` handles both. It's safe to re-run: it normalizes what's there, refreshes the skill-managed parts, and never touches what the project added itself.

## Prerequisites

- `runesmith-workspace` installed, plus `runesmith-cc` and `runesmith-sprint` if the project holds code.
- The project folder connected to the session.
- Optional: your own backup outside the project folder. Init snapshots anyway.

## 1. Run init

```
/runesmith-workspace:init
```

On a re-run, init checks comms first, then reads every root entry and classifies it against `lib/folder-conventions.md`. It skips questions it already has answers for (code or not, Jira or not).

## 2. Review the move plan

Init shows a table, one row per move, with the head line on top. Choose:

- **Preview only** for a first run on a messy folder.
- **Apply** when the table looks right.
- **Cancel** to stop.

Unknown root items go to `_INBOX/` without a question each.

## 3. What init changes

- Snapshots everything that will move or change to `archive/_pre-init-{UTC}/`.
- Moves git repos at the root into `{PROJECT}.cc/{repo}/` as whole units, history intact.
- Renames `claude-code/` or an old head to `{PROJECT}.cc/`.
- Renames numbered comm folders in `comms/open/` to `{UTC}-{slug}/`, and `attachments/` to `references/`. `comms/archive/` is left alone.
- Deploys the builder skills as `.claude/skills/runesmith-{name}/` and moves the old unprefixed copies to the snapshot. A deployed skill the project changed is kept and reported.
- Merges the head's settings (attribution off, stop hook cap, code-simplifier) without touching other keys.
- Rewrites each repo's address to `https://{account}@github.com/{owner}/{repo}.git` for the project's GitHub account, replacing SSH or account-less addresses, and reports each change.
- Creates any missing `dev`, `qa` and `beta` branches. Existing branches are never moved.
- Rewrites only its own marker sections in each `CLAUDE.md`. Content outside them, and sections owned by other tools, stay as they are.
- Writes `STRUCTURE.md` and gives you a fresh Project Instructions block.

Nothing is deleted. Init only moves, and every move is snapshotted first.

## 4. After init

- Paste the Project Instructions block into the Claude Project.
- Run `/runesmith-workspace:inbox` to route whatever landed in `_INBOX/`.
- Move any Claude Code keys out of a repo folder into `{PROJECT}.cc/.credentials`. Init reports any it finds.
- Open goals from before the upgrade: finish them, then start new work with `/runesmith-sprint:task`. The new task layout applies from the next task.

## Old skill names

`/runesmith-workspace:reallocate` and `/runesmith-cc:bootstrap-cc` point at `init` and `head` for this release and are then removed.

## Verify

```
ls
```

The root should hold only the canonical folders, `{PROJECT}.cc/` for a code project, `CLAUDE.md`, `STRUCTURE.md`, `.credentials` and standard repo files. Anything else means init left it for you; run the inbox skill.

```
git -C {PROJECT}.cc/{repo} branch -a
git -C {PROJECT}.cc/{repo} remote -v
```

Shows `dev`, `qa`, `beta` and `main`, and the remote without a token in its address.

## Rollback

Everything init moved or changed is in `archive/_pre-init-{UTC}/`. Copy back what you need. Moving content back is itself a destructive step, so check what's at the destination first.

## Troubleshooting

**Init stops on a marker.** A start marker without its end means the file is damaged. Init names the file and marker. Fix it, or restore the file from the snapshot, then re-run.

**A destination is occupied.** Init reports it and moves nothing for that row. Rename one side and re-run.

**A repo wasn't moved.** Only folders with `.git/` directly under the root are moved. Move nested repos yourself, or clone fresh through `/runesmith-cc:head`.

**Remote tracking looks broken after a move.** `.git/config` travels with the repo. If `git remote -v` is empty, restore the repo's `.git/` from the snapshot.

**`STRUCTURE.md` doesn't show my extra folders.** It documents the canonical layout. Describe your extra folders in `CLAUDE.md`, outside the marker sections.
