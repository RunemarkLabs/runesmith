# How-to: Install the CC Project-Boundary Guardrail

The guardrail constrains every Claude Code session on your machine to its launch project's root. It's the harness-level enforcement (Layer 2) that backs up the behavioral rules in `CLAUDE.md` (Layer 1).

Install once per machine. Take this seriously - without it, a misdirected CC session can read `.credentials` from a sibling project and echo plaintext keys into the transcript. That's the 2026-05-17 incident that drove this skill into the marketplace.

## One-shot install flow (v0.8.x)

CC's own permission system blocks writes to `~/.claude/` from a CC session, so the install can't run inside CC itself. Instead, a self-contained installer script is copied to your workspace root and you run it once from your OS shell.

1. From Cowork (any workspace), invoke `/runesmith-cc:guardrail install`.
2. The skill copies `install-guardrail.ps1` (Windows) or `install-guardrail.sh` (macOS/Linux) to the workspace root.
3. Open PowerShell or Terminal in the workspace root and run:
   - Windows: `.\install-guardrail.ps1`
   - macOS/Linux: `./install-guardrail.sh`
4. The installer writes the `~/.claude/settings.json` permission block + `~/.claude/hooks/enforce-project-boundary.sh`, runs synthetic verification (allow case returns 0, deny case returns 2), and reports paths and residual risks.
5. Restart any open Claude Code sessions to pick up the new user-level config.

That's the whole install. No multi-step copy-paste. No JSON merge by hand.

## Prerequisites

- RuneSmith marketplace installed in Cowork (specifically `runesmith-cc`).
- `jq` installed. Install via `brew install jq` (macOS), `apt install jq` (Debian/Ubuntu), `choco install jq` (Windows).
- On Windows, Git Bash is required if you want the bash variant of the hook; otherwise the PowerShell variant ships alongside.

## Installer modes

The installer accepts a mode argument so the same script handles install, verify, and uninstall.

| Action | PowerShell | Bash |
|---|---|---|
| Install (default) | `.\install-guardrail.ps1` | `./install-guardrail.sh` |
| Verify | `.\install-guardrail.ps1 -Mode verify` | `./install-guardrail.sh verify` |
| Uninstall | `.\install-guardrail.ps1 -Mode uninstall` | `./install-guardrail.sh uninstall` |

Re-running the install mode is idempotent and repairs drift.

## What gets installed

User-level `~/.claude/settings.json` gains a marker-bounded block (so uninstall can find and remove only what the skill owns):

```json
{
  "_runesmith_guardrail_marker": "<uuid>",
  "_runesmith_guardrail_keys": [...],
  "permissions": {
    "defaultMode": "dontAsk",
    "allow": [
      "Read(/**)", "Edit(/**)", "Write(/**)",
      "Grep", "Glob",
      "Bash(ls *)", "Bash(cat *)", "..."
    ],
    "deny": [
      "Read(//**/.credentials*)", "Read(//**/.env)", "...",
      "Bash(curl *)", "Bash(wget *)", "..."
    ]
  },
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "$HOME/.claude/hooks/enforce-project-boundary.sh"
      }]
    }]
  }
}
```

Plus the hook script at `~/.claude/hooks/enforce-project-boundary.sh` (bash) and `enforce-project-boundary.ps1` (PowerShell shim on Windows).

The `/path` syntax in `Read(/**)` is project-relative in Claude Code's permission system. It resolves to whichever project the session was launched in. User-level rules with `/path` anchors automatically scope to the active project.

## What this prevents

- **Cross-project filesystem reads.** `Read(/**)` allows reads inside the active project root only. Outside is denied by `defaultMode: "dontAsk"`. Sibling-project `.credentials` reads return permission deny.
- **Categorical credential reads.** `Read(//**/.credentials*)`, `Read(//**/.env*)`, `Read(//**/id_rsa*)`, `Read(//**/*.key)`, `Read(//**/*.pem)`, `Read(~/.ssh/**)`, `Read(~/.aws/**)`. Deny-first precedence wins even if an allow rule would match.
- **Bash exfil verbs.** `Bash(curl *)`, `Bash(wget *)`, `Bash(nc *)`, `Bash(ssh *)`, `Bash(scp *)`. Best-effort; the hook also scans command strings for sensitive-name reads via `cat`/`head`/`tail`/`type`/`Get-Content`.
- **Bash subprocess file access.** The hook inspects Bash command strings and blocks reads of sensitive paths or paths outside the project boundary. Best-effort against accidents, not adversarial bash.

## What this does NOT prevent

**Subagents bypass the boundary.** Anything launched via the Task tool inside a CC session does NOT inherit `PreToolUse` hooks or permission rules from `settings.json`. Known platform limitation tracked in [anthropics/claude-code#27661](https://github.com/anthropics/claude-code/issues/27661) and [#23983](https://github.com/anthropics/claude-code/issues/23983). Layer 1 advisory rules in CLAUDE.md are the only protection inside a subagent.

**Adversarial Bash on Windows.** PowerShell pipes, indirect command invocation, and shell escaping can evade the substring matchers. The hook catches accidents, not attacks. Real Bash containment requires OS-level sandboxing (WSL, separate Windows account, VM).

**MCP tool calls are not boundary-aware.** Any installed MCP can be called from any project regardless of which project enabled the workflow. Follow-up plan (MCP scoping) tracked separately.

**Project-internal secrets with custom names.** A file named `prod-keys.txt` inside the project boundary is not caught by the categorical deny rules. The Layer 1 credentials-class refusal rule in CLAUDE.md is the backstop, but it's advisory.

## Project-level escape hatch

`bootstrap-cc` writes `<project>/.claude/settings.json` with `additionalDirectories: []`. Populate this array when a project legitimately needs to read outside its root:

```json
{
  "additionalDirectories": ["../shared-libs", "../other-project/exports"],
  "permissions": {
    "allow": [
      "Bash(npm run my-cross-project-script)"
    ]
  }
}
```

Document the reason in the project's `.claude/README.md`. You cannot allow what the user-level guardrail denies - deny-first precedence wins. Categorical secret-name and exfil denies always apply.

## Sapient Industries managed-settings option (Team / Enterprise)

If your org is on Cowork Team or Enterprise, an admin can ship the guardrail block as managed settings instead of user-level. Two extra keys:

```json
{
  "allowManagedHooksOnly": true,
  "allowManagedPermissionRulesOnly": true,
  "permissions": {...},
  "hooks": {...}
}
```

Result: every CC session in the org loads only managed hooks and managed permission rules. Users can't disable the boundary. Deploy through your org's MDM or managed-settings file delivery mechanism.

## Troubleshooting

**Hook runs but doesn't block.** Check `~/.claude/hooks/boundary.log` for the action trail. If empty, the hook isn't being called - verify `settings.json` includes the `hooks.PreToolUse` entry pointing at the script's absolute path. Re-run install to repair.

**`jq: command not found`.** Install jq or use the PowerShell variant. The hook short-circuits with an advisory-only warning if jq is missing.

**`CLAUDE_PROJECT_DIR not set` warning in logs.** The hook is being invoked outside a Claude Code project session. Harmless - the hook allows the call and logs a notice.

**Settings file got mangled.** The installer aborts and rolls back if verify fails. If rollback didn't run cleanly, run `uninstall` to remove the guardrail block, then inspect `~/.claude/settings.json` for leftover `_runesmith_guardrail_*` keys.

**Verify reports FAIL after a plugin update.** Re-run install. It's idempotent and repairs drift.
