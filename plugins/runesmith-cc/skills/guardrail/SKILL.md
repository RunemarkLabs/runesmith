---
name: guardrail
description: "Install, verify, or uninstall the CC project-boundary guardrail with a single command. Copies a self-contained PowerShell (Windows) or bash (macOS/Linux) installer to the workspace root that handles the entire user-level setup - writes ~/.claude/settings.json permission block, hook scripts, runs synthetic verification. Constrains every Claude Code session on the machine to its launch project's root. Run once per machine. Verify also audits AI attribution in every {PROJECT}.cc head (settings, CLAUDE.md rule, commit-msg hook, count of attributed commits on default branches; report only). Use when the user says \"install the guardrail\", \"set up CC boundaries\", \"lock CC to project root\", \"guardrail install\", \"guardrail verify\", \"uninstall the guardrail\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# CC Project-Boundary Guardrail (one-shot installer)

The guardrail is **user-level config** (`~/.claude/settings.json` permission rules + `PreToolUse` hook). Cowork's sandbox can't write to user-home. CC's own session can't either (its own permissions block the install of its own boundary - chicken-and-egg). So this skill takes a different approach: **copy a self-contained installer script to the workspace root and tell the user to run it once.**

One user action: run `.\install-guardrail.ps1` (Windows) or `./install-guardrail.sh` (macOS/Linux). The script does everything.

## References

- `templates/install-guardrail.ps1` - full self-contained Windows installer
- `templates/install-guardrail.sh` - full self-contained installer for **macOS + Linux** (portable: handles BSD realpath on macOS, GNU readlink on Linux, python3 fallback)

## What the installer does

When the user runs the copied installer:

1. **Detects environment** - Git Bash + jq on Windows (chooses hook variant), or `jq` on Unix (required).
2. **Creates `~/.claude/hooks/`** if absent.
3. **Writes the hook script** - `enforce-project-boundary.sh` (and `.ps1` on Windows). The hook body is embedded in the installer; no extra files to copy.
4. **Reads existing `~/.claude/settings.json`** if present. Fails loudly on invalid JSON; never overwrites unreadable files.
5. **Merges the guardrail block** - marker key, `permissions.defaultMode: "dontAsk"`, curated allow/deny arrays (union with any user-managed entries), `hooks.PreToolUse` matcher. User-managed keys outside the guardrail block survive.
6. **Synthetic-tests the hook** - pipes one allow case and one deny case through, confirms exit codes (0 / 2).
7. **Reports** - paths, status, known residual risks, restart-CC reminder.

## What this skill does (Cowork-side, one shot)

When invoked from Cowork, this skill:

1. **Comms check on entry** (per `lib/comms-check.md`).
2. **OS detection** - structured prompt: Windows / macOS / Linux / "auto-detect both."
3. **Confirms action** - structured prompt: install / verify / uninstall / cancel.
4. **Copies the appropriate installer** from this skill's `templates/` folder to the user's workspace root:
   - Windows: `install-guardrail.ps1`
   - macOS/Linux: `install-guardrail.sh` (with `chmod +x`)
   - "Both": copies both files
5. **Reports the single command** the user runs to complete the action.

That's it. No multi-step copy-paste. No "where is jq." No JSON merge by hand.

## Action mapping

The installer script accepts a mode argument:

| User intent | PowerShell command | Bash command |
|---|---|---|
| Install | `.\install-guardrail.ps1` | `./install-guardrail.sh` |
| Verify | `.\install-guardrail.ps1 -Mode verify` | `./install-guardrail.sh verify` |
| Uninstall | `.\install-guardrail.ps1 -Mode uninstall` | `./install-guardrail.sh uninstall` |

This skill copies the installer once. The user runs whichever mode they need.

## Pre-flight checks

### 0. Comms check (always first)

See `lib/comms-check.md`.

### 1. Confirm action (structured prompt)

Single-pick: `install` / `verify` / `uninstall` / `cancel`.

### 2. Detect target OS (structured prompt)

Single-pick:
- `Windows` - copies `install-guardrail.ps1`
- `macOS` - copies `install-guardrail.sh` (works with default macOS bash; requires `brew install jq`)
- `Linux` - copies `install-guardrail.sh` (requires `apt install jq` or distro equivalent)
- `Copy both (cross-platform team)` - copies both .ps1 and .sh

Defaults to the OS the user's session indicates if known. "Copy both" is the right pick for cross-platform teams (e.g. Sapient where some run Windows, some run macOS).

### 3. Pick destination (structured prompt, optional)

Default: workspace root. Alternative: `_INBOX/` if the workspace's root keep-list is strict and the user prefers not to track temp installers there. The installer is gitignored by default if the workspace has a RuneSmith-canonical `.gitignore` (it matches `install-guardrail.*`).

## Install flow

1. Copy `templates/install-guardrail.ps1` and/or `templates/install-guardrail.sh` to the chosen destination (workspace root by default).
2. On Unix, `chmod +x install-guardrail.sh`.
3. Report:
   ```
   Installer copied:
     Windows: {workspace}/install-guardrail.ps1
     Unix:    {workspace}/install-guardrail.sh

   Next: run the installer.

   PowerShell:
     cd {workspace}
     .\install-guardrail.ps1

   Bash:
     cd {workspace}
     ./install-guardrail.sh

   Once it completes successfully, restart any open Claude Code sessions.
   ```

No structured-prompt consent for the copy step itself - the consent for the install action already happened in step 1 of pre-flight. Copying a file to workspace root is trivially reversible and doesn't touch user-home.

## Verify flow

Same copy step. User runs the installer with `verify` / `-Mode verify` from the workspace root (or passes the workspace path). Skill reports the verify command:

```
.\install-guardrail.ps1 -Mode verify [-Workspace {WORKSPACE}]
./install-guardrail.sh verify [{WORKSPACE}]
```

Verify runs two checks and prints one status line at the end:

1. **Guardrail** - marker key, hook script, synthetic allow + deny hook tests (user-level `~/.claude/settings.json`).
2. **AI attribution audit** - for every `{PROJECT}.cc/` head under the workspace (or the workspace itself if it is a head):
   - `.claude/settings.json` merged with `.claude/settings.local.json` turns attribution off: `attribution.commit` and `attribution.pr` are empty strings and `attribution.sessionUrl` is `false` (or `attribution` is `false`).
   - `CLAUDE.md` carries the attribution hard rule.
   - Each repo in the head has a `commit-msg` hook (resolved through `core.hooksPath` when set) that strips attribution. The hook is tested by running it on a sample message through `git hook run`, so a custom hook that already strips attribution passes too.
   - Number of commits on each repo's default branch (`origin/HEAD`, else `main` / `master`) whose message carries attribution. Report only: verify never rewrites history. Shallow clones are flagged because the count only covers fetched history.
   - User-level attribution state is shown for information; the head settings override it.

Exit code is non-zero when the guardrail or any head's attribution setup fails. Commit counts never fail the run. Fix attribution setup with `/runesmith-cc:head` (re-run on the existing head).

## Uninstall flow

Same copy step. User runs the installer with `uninstall` / `-Mode uninstall`:

```
.\install-guardrail.ps1 -Mode uninstall
./install-guardrail.sh uninstall
```

The installer removes its marker keys from settings.json, removes the hook scripts. Does NOT strip permission rule entries by content (the user may have added their own copies of the same rules). Prints a warning and lists what stayed for manual review.

## Known residual risks (documented, not solved by this skill)

- **Subagents bypass the hook and permission rules** (platform bugs #27661, #23983). Layer 1 advisory rules in CLAUDE.md are the only protection inside a subagent.
- **Bash on Windows is unsandboxed.** Substring matchers in the hook are evadeable via PowerShell pipes, indirect invocation, shell escaping. Hook catches accidents, not adversarial Bash.
- **MCP tool calls are not boundary-aware.** Any installed MCP can be called from any project regardless of which project enabled the workflow. Follow-up plan tracked separately.

## Why this design (and what changed)

Earlier versions tried to install the guardrail from inside Claude Code. That failed because CC's own permission system blocks writes to `~/.claude/` from a CC session (it's enforcing the boundary it doesn't yet have, against itself). The CC-side install path is retired in v0.8.0. The one-shot installer eliminates the multi-step manual path: open PowerShell or Terminal, run one command, done.

## Output reporting (all flows)

End every flow with a single structured summary. No prose preamble.

```
Guardrail action:  install | verify | uninstall
Installer copied:  {WORKSPACE}/install-guardrail.ps1
                   {WORKSPACE}/install-guardrail.sh
Command to run:    .\install-guardrail.ps1
                   ./install-guardrail.sh

Next step: open PowerShell / Terminal, cd to the workspace, run the
command above. Then restart any open Claude Code sessions.
```
