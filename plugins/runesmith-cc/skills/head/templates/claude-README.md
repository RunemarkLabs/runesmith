# Claude Code settings for this head

This folder holds the project-level settings for Claude Code sessions launched in this head. `runesmith-cc:head` wrote it and refreshes only the keys it owns; everything else here is yours.

## What `settings.json` does

- **Attribution off:** `attribution` (empty commit and pull request text, no session link) and `includeCoAuthoredBy: false` for older Claude Code releases.
- **Stop hook cap:** `env.CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` is `3`, so a goal can't loop after its banner.
- **code-simplifier:** `enabledPlugins` turns on Anthropic's official plugin. If Claude Code says it's enabled but not installed, run `claude plugin install code-simplifier@claude-plugins-official --scope project` once.
- **The boundary:** with the user-level RuneSmith guardrail installed (`/runesmith-cc:guardrail`), sessions here stay inside this head. Reads, writes and edits outside it are denied by Claude Code's permission system; a `PreToolUse` hook checks shell commands (best effort against accidents).

## Widening the boundary

`permissions.additionalDirectories` lists paths this project legitimately needs outside its root. Examples:

- **A sibling package:** `"../shared-libs"` to read shared code.
- **A service config:** `"/etc/myapp"` for an operations project.
- **A handoff folder:** `"../other-project/exports"` where another team drops files.

Every entry is an escape hatch. Record each one in the table below with the reason and who approved it.

`permissions.allow` and `permissions.deny` take project-specific overrides. Use them sparingly: allow a command the user-level rules block, or deny a path inside the project that must never be touched (for example `Read(./.secrets/**)`). You can't allow what the user-level guardrail denies: deny rules win, and the credential-class denies (`.credentials`, `.env`, `id_rsa*` and the rest) always apply.

## What's still not protected

1. **Subagents.** Work launched through the Task tool doesn't inherit hooks or permission rules.
2. **Shell commands on Windows.** Pipes, escaping and indirect invocation can slip past the hook.
3. **Secrets with unusual names inside the project.** The name rules catch `.env`, not `prod-keys.txt`. Keep secrets out of the project tree.
4. **MCP tool calls.** They aren't boundary-aware.

## Turning it off

- User level: run the guardrail installer with `uninstall`.
- This project: edit this folder's `settings.json`. The user-level guardrail still applies.

## Approved cross-project access

| Path | Reason | Approved by | Date |
|------|--------|-------------|------|
| (none) | | | |
