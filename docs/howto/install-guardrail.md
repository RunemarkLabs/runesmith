# How-to: Install the Project-Boundary Guardrail

The guardrail keeps every Claude Code session on your machine inside the project it was launched from. It enforces at the harness level what the builder's `CLAUDE.md` already says in words.

Install it once per machine. Without it, a misdirected session can read `.credentials` from a sibling project and print the keys into its transcript.

## Why an installer

The guardrail is user-level configuration (`~/.claude/settings.json` and `~/.claude/hooks/`). The chat session can't reach your home folder, and Claude Code's own permissions stop it from writing its own boundary. So the skill hands you a self-contained installer to run once.

## Install

1. In the planner chat:

   ```
   /runesmith-cc:guardrail
   ```

   Pick your system and the action (install, verify or uninstall). The skill copies `install-guardrail.ps1` (Windows) or `install-guardrail.sh` (macOS and Linux) into the workspace and gives you the command.

2. Open a terminal in the workspace and run it:
   - Windows: `.\install-guardrail.ps1`
   - macOS and Linux: `./install-guardrail.sh`

3. The installer writes the settings block and the hook, tests one allowed and one denied call, and reports what it did.

4. Restart any open Claude Code sessions.

`/runesmith-workspace:init` prints the same command for code projects.

## Prerequisites

- `jq` (`brew install jq`, `apt install jq`, or `choco install jq`).
- On Windows, Git Bash for the bash hook; otherwise the PowerShell hook is used.

## Modes

| Action | PowerShell | Bash |
|---|---|---|
| Install (default) | `.\install-guardrail.ps1` | `./install-guardrail.sh` |
| Verify | `.\install-guardrail.ps1 -Mode verify` | `./install-guardrail.sh verify` |
| Uninstall | `.\install-guardrail.ps1 -Mode uninstall` | `./install-guardrail.sh uninstall` |

Installing again repairs drift. Verify also reports AI attribution in every head it finds (settings, the `CLAUDE.md` rule, the commit hook, attributed commits on default branches); it changes nothing.

## What gets installed

- A marked block in `~/.claude/settings.json`: `permissions.defaultMode: "dontAsk"`, allow rules scoped to the active project, deny rules for credential-class files and network copy commands, and a `PreToolUse` hook on shell commands. Settings outside the block are kept, and uninstall removes only the block.
- The hook script `~/.claude/hooks/enforce-project-boundary.sh` (plus a PowerShell version on Windows).

## What it prevents

- **Reads outside the project.** Only the active project's root is allowed; everything else is denied.
- **Credential-class reads anywhere:** `.credentials*`, `.env*`, `id_rsa*`, `*.key`, `*.pem`, `~/.ssh/`, `~/.aws/`. Deny rules win over allow rules.
- **Network copy commands** such as `curl`, `wget`, `nc`, `ssh` and `scp`, best effort.
- **Shell reads of sensitive or outside paths.** The hook inspects each command. Best effort against accidents, not attacks.

## What it does not prevent

- **Subagents.** Work launched through the Task tool doesn't inherit hooks or permission rules (platform issues [#27661](https://github.com/anthropics/claude-code/issues/27661) and [#23983](https://github.com/anthropics/claude-code/issues/23983)). Only the written rules apply there.
- **Determined shell tricks on Windows.** Pipes, indirect invocation and escaping can slip past the matcher. Real containment needs an operating-system sandbox.
- **MCP tool calls.** They aren't boundary-aware.
- **Secrets with unusual names inside the project.** `prod-keys.txt` isn't caught by the name rules; the written rule is the backstop.

## Legitimate cross-project access

When a project genuinely needs to read outside its root (a shared library, a sibling's exports), add the path to `permissions.additionalDirectories` in `{PROJECT}.cc/.claude/settings.json` (the head creates the list empty) and record it in the approval table in `{PROJECT}.cc/.claude/README.md`. You can't allow what the user-level guardrail denies: credential-class and network denies always apply.

## Organization-wide (Team and Enterprise)

An admin can deliver the same block as managed settings with `allowManagedHooksOnly` and `allowManagedPermissionRulesOnly` set to `true`. Every session then loads only managed hooks and rules, and users can't turn the boundary off. See the Claude admin documentation.

## Troubleshooting

**The hook runs but doesn't block.** Check `~/.claude/hooks/boundary.log`. If it's empty, the hook isn't called: run install again to repair `settings.json`.

**`jq: command not found`.** Install `jq`, or use the PowerShell hook. Without `jq` the hook only warns.

**`CLAUDE_PROJECT_DIR not set` in the log.** The hook ran outside a Claude Code project session. Harmless.

**The settings file looks wrong.** The installer stops and rolls back when its test fails. If something is left over, run uninstall, then look for keys starting with `_runesmith_guardrail_` in `~/.claude/settings.json`.

**Verify fails after an update.** Run install again.
