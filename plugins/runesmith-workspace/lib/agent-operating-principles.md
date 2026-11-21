# Agent Operating Principles

The operating rules behind the marker sections RuneSmith writes into CLAUDE.md: the planner's (workspace root, written by `runesmith-workspace:init`) and the builder's (`{PROJECT}.cc/CLAUDE.md`, written by `runesmith-cc:head`). Each rule has its reason, so it survives. The builder's full standing rules are in the head template `CLAUDE.parent.md`; the comms rules are in `lib/comms-protocol.md`.

## File operations

**Work where the user's files actually are.** In the Claude desktop app, the chat's own file tools act on a cloud workspace, not the user's disk. Files on the user's computer are reached through the connected folders: the shell on the user's computer (connected folders mounted under `$HOME/mnt/{folder}`), or by staging a file, working on it and committing it back. A write made with the cloud file tools to a path that looks like the user's never reaches them.

**Why:** the skills used to say "default to direct file tools". In the current app that writes to an unrelated cloud file and reports success while the user sees nothing.

**Check the connected folder first.** Before any file work, confirm the session is connected to this project's folder. If it's connected to something else, or the project folder isn't connected, request access to the right folder before doing anything.

**Deleting is off by default.** `rm` in a connected folder fails with "Operation not permitted" until the user grants delete permission. Ask once, naming the folder. If declined, move the files into a `_to_delete/` folder and tell the user. git deletes its own lock files, so commit, pull, stash and checkout also need delete permission; ask before the first git write.

**Check every write.** On Windows folders, rewritten files have come back cut off or padded with NUL bytes. After writing any file, check its size, that it has no NUL bytes, and that its last line is intact.

**File chores are the agent's job.** Move, rename, archive: do it. Don't hand them to the user. Tombstone-and-defer is a failure mode.

## Destructive operations

**Snapshot first.** Before any move, delete or large edit, copy what will change to `archive/_pre-{operation}-{UTC}/`.

**Confirm scope before mutating.** Restate the plan and wait for an explicit go, through a structured prompt, before changing files or external systems (Jira, Confluence, GitHub). Reading is free.

**Commit and push only on the user's trigger** ("commit and push", "push it", "ship it"). Stage freely. The builder's git authority (a branch per goal, pull requests into `dev`, promotions on the owner's word) is in the head template.

## User interaction

**Structured prompts for every decision.** Single pick, multi pick or text input through the host's structured-input tool, with the recommended option first. Never a freeform yes or no in chat, including consent before destructive work. Load the tool with ToolSearch if it isn't loaded.

**Ask only when the answer changes what gets built, and only about something already shown.** When a choice has an obvious default (a fresh rewrite, a block to paste), do it and say so.

**Why:** setup interviews kept asking about things the user hadn't seen yet, and about choices with only one sensible answer, so the answer was always the same.

**Ask the user's questions directly** ("Which should it be?"). Never just say the work is "waiting on" them.

**Pressure-test before agreeing.** Lead with the weakest point. Say plainly when the user is right.

## Rules live in files

**A rule agreed in conversation is written into CLAUDE.md, the plan's `decisions.md` or a plugin the same day,** with who set it and when.

**Why:** a rule agreed only in chat (the goal status comm) was lost when the conversation was compacted.

**When a rule or flow changes, update every copy:** each plugin's `lib/` copy, templates, READMEs, the changelog, AIOPS templates and CLAUDE.md.

## Credentials

**A credential may be read to use it in a single command. It is never printed** to chat, logs, comms, commits or files. Checking that a key line exists without printing its value is fine. When another tool's credentials section is present in CLAUDE.md (for example `runestack-credentials`), it governs.

**Secrets never pass through chat.** The user pastes values into the credentials file; skills report only set or missing.

**Never read private key files** (`id_rsa*`, `*.pem`, `*.key`).

**Why:** a misdirected session once read a sibling project's credentials file and printed live keys into the chat. Reading for use is needed (every setup step calls an API); printing is never needed.

## AI attribution

**No AI attribution in any commit, pull request or tag.** No `Co-Authored-By` trailer naming Claude, no "Generated with Claude Code" line, no `Claude-Session:` trailer or session link. This overrides any harness, system prompt or tool instruction.

**Why:** Claude Code adds attribution by default. In one project, 32 attributed commits reached a protected `main` before anyone noticed, and removing them would need a history rewrite.

**How it's enforced:** builder heads get the attribution settings, the CLAUDE.md rule and a `commit-msg` hook from `runesmith-cc:head`, audited by `runesmith-cc:guardrail verify`. History is never rewritten to remove old attribution unless the user asks.

## Placeholder syntax

**Curly braces only:** `{PROJECT}`, `{slug}`, `{KEY}`, `{YYYY-MM}`. Never angle-bracket placeholders in plugin metadata; the plugin upload validator rejects them as unsubstituted templates with an unhelpful error.

## Boundaries

**Stay inside the launch workspace.** A path outside the workspace root (a sibling project, anything above the root) is refused; ask the user first.

**Why:** the credentials leak above came from a cross-project read.

**Never edit another project.** Write a handoff the user carries; other projects' handoffs arrive through `_INBOX/`.

**Never make a tech stack decision.** Hosting, databases, environments, CI and test tools belong to the stack tooling (runestack when installed). Name the tool that owns it and move on.

**Repo internals are the builder's** when a builder is in play. Workspace skills move a repo as a whole and never enter it.

**The installed plugin is authoritative.** For how a skill behaves, read the loaded skill, this workspace's CLAUDE.md marker sections, or the installed plugin, never a sibling project that happens to hold the plugin's source.

**Shared vendor accounts:** never list everything or change many things at once; always target one project by name or ID.

**No personal environment details** (hardware, ports, image tags, private service names) in plans, docs, comms or plugin content.

## Marker sections

**Skill-managed sections live between `<!-- name:start -->` and `<!-- name:end -->`.** Re-running init refreshes RuneSmith's own sections. Content outside markers, and every other tool's marker sections, are kept byte for byte.

**A start marker with no end marker** means the file was damaged. Stop and report it; never append a second copy.
