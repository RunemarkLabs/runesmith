# {PROJECT} - Claude Code Workspace

This is the Claude Code workspace for the **{PROJECT}** project.

When opening this folder in Claude Code, you are working inside the {PROJECT}
monorepo head. Cowork plans and writes tasks here; this Claude Code instance
executes.

## What lives here

- `CLAUDE.md` - monorepo-level rules (always loaded by Claude Code)
- `.claude/` - skills, commands, agents, hooks scoped to this workspace
- `comms/` - file-based exchange with Cowork (open/ is ephemeral, archive/ is committed)
- `{repo}/` - actual code repositories

## How Cowork ↔ Claude Code communicate

Through files in `comms/`. See `comms/README.md` for the protocol. The user
is reached only through Cowork.

## Marker file

`.claude-code-workspace` (JSON) carries metadata about this workspace,
including atlassian config when applicable.

## Bootstrap

This workspace was created by Cowork's `/runesmith-cc:head` skill.
Re-run it to add more repos or refresh missing files.

<!--
  Deployed from RuneSmith marketplace.
  Copyright 2026 Runemark Labs. Licensed under Apache-2.0.
  Source: https://github.com/runemarklabs/runesmith
-->
