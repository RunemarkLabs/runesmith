# Project-level Claude Code settings

This folder holds project-scoped configuration for Claude Code sessions launched inside this repo. RuneSmith's `bootstrap-cc` skill wrote it; review and tune as needed.

## What it does

Combined with the user-level RuneSmith guardrail (installed via `/runesmith-cc:guardrail install`), this project's CC sessions are constrained to the project root. Reads, writes, and edits outside the project boundary are blocked by Claude Code's permission system. Bash subprocess access to files outside the boundary is blocked by a `PreToolUse` hook (best-effort against accidents).

## When to edit `settings.json`

`additionalDirectories` — add absolute paths or `~`-relative paths the project legitimately needs to access. Examples:

- **Monorepo sibling**: `"../shared-libs"` so CC can read shared code in a sibling package.
- **System config**: `"/etc/myapp"` for an ops project that touches a service config.
- **Cross-project handoff**: `"../other-project/exports"` when another team drops data files here.

Every entry is an escape hatch. Document the reason inline (`_comment` per entry, or in this README's "Approved cross-project access" section below) so future maintainers know why the boundary was widened.

`permissions.allow` / `permissions.deny` — project-specific overrides. Use sparingly:

- Allow a `Bash(npm run *)` that the user-level config blocked.
- Deny a path inside the project that should never be touched (e.g. `Read(./.secrets/**)`).

The user-level guardrail's `defaultMode: "dontAsk"` plus categorical denies (`.credentials`, `.env`, `id_rsa*`, etc.) still apply on top of these. You cannot allow what the user-level config denies — deny-first precedence wins.

## What's still NOT protected

Even with the guardrail installed:

1. **Subagents bypass the hook and permission rules.** Anything launched via the Task tool inside a CC session does NOT inherit these constraints. Known platform issue. Be careful with subagent-heavy workflows.
2. **Bash on Windows is unsandboxed.** Adversarial commands can evade substring matchers via PowerShell pipes, shell escaping, indirect invocation. The hook catches accidents.
3. **Project-internal files are still accessible.** A `.env` inside the project boundary is denied by the categorical secret-name rules, but a custom-named secret file is not. Don't rely on the guardrail; keep secrets out of the project tree where you can.
4. **MCP tool calls are not boundary-aware.** Any installed MCP can be called from any project.

## How to disable

User-level: `/runesmith-cc:guardrail uninstall`. Removes the hook + permission block from `~/.claude/settings.json`. CC sessions immediately lose the boundary on next launch.

Project-level: edit this folder's `settings.json` directly. Removing the file or emptying `additionalDirectories` only affects this project; the user-level guardrail still applies.

## Approved cross-project access

List any non-empty `additionalDirectories` entries here with the reason and the approver:

| Path | Reason | Approved by | Date |
|------|--------|-------------|------|
| _(none)_ | _(initial install)_ | _(N/A)_ | _(N/A)_ |
