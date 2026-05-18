# How-to: Install the CC Project-Boundary Guardrail

The guardrail constrains every Claude Code session on your machine to its launch project's root. It's the harness-level enforcement (Layer 2) that backs up the behavioral rules in `CLAUDE.md` (Layer 1).

Install once per machine. Take this seriously — without it, a misdirected CC session can read `.credentials` from a sibling project and echo plaintext keys into the transcript. That's not theoretical; it's the 2026-05-17 incident that drove this skill into the marketplace.

## Prerequisites

- RuneSmith marketplace installed in Cowork (specifically `runesmith-cc`).
- Cowork has access to the user-level `~/.claude/` directory (macOS/Linux) or `%USERPROFILE%\.claude\` (Windows).
- `jq` installed (for the bash hook variant). Install via `brew install jq` (macOS), `apt install jq` (Debian/Ubuntu), `choco install jq` (Windows).

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
      "Bash(ls *)", "Bash(cat *)", ...
    ],
    "deny": [
      "Read(//**/.credentials*)", "Read(//**/.env)", ...,
      "Bash(curl *)", "Bash(wget *)", ...
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

Plus the hook script at `~/.claude/hooks/enforce-project-boundary.sh` (bash) and `enforce-project-boundary.ps1` (PowerShell shim, Windows without Git Bash).

The `/path` syntax in `Read(/**)` is **project-relative** in Claude Code's permission system. It resolves to whichever project the session was launched in. User-level rules with `/path` anchors automatically scope to the active project.

## Install

```
/runesmith-cc:guardrail install
```

What happens:
1. Detects OS (macOS / Linux / Windows). Sets target paths accordingly.
2. Structured prompt: install / cancel.
3. If `~/.claude/settings.json` doesn't exist, creates it as `{}`. If it does, parses it. Fails loudly on invalid JSON; never overwrites unreadable files.
4. JSON-aware merge of the guardrail block. User-managed keys outside the block survive.
5. Writes the hook script. `chmod +x` on Unix.
6. Verify: pipes a synthetic deny case + allow case through the hook, confirms exit codes are 2 and 0.
7. Reports settings path, hook script path, what's covered, residual risks, and the next step (restart open CC sessions).

If the file already contains a `_runesmith_guardrail_marker` from a prior install, the skill prompts: `update existing` / `reinstall fresh` / `cancel`.

## Uninstall

```
/runesmith-cc:guardrail uninstall
```

Removes only the entries the skill added (identified by `_runesmith_guardrail_keys`). User-managed entries in `permissions.allow`, `permissions.deny`, and `hooks.PreToolUse` survive.

Removes both the bash and PowerShell hook scripts from `~/.claude/hooks/`.

Prints a warning: CC sessions on this machine no longer have a project boundary until you re-install.

## Verify

```
/runesmith-cc:guardrail verify
```

Checks:
- `_runesmith_guardrail_marker` is present in settings.
- All curated allow/deny entries are present.
- `hooks.PreToolUse` includes the boundary matcher.
- Hook script smoke-tests pass (synthetic deny case returns exit 2, synthetic allow case returns exit 0).

Reports each check. If anything fails, suggests `install` to repair.

## What this prevents

- **Cross-project filesystem reads.** `Read(/**)` allows reads inside the active project root only. Outside is denied by `defaultMode: "dontAsk"`. Sibling-project `.credentials` reads return permission deny.
- **Categorical credential reads.** `Read(//**/.credentials*)`, `Read(//**/.env*)`, `Read(//**/id_rsa*)`, `Read(//**/*.key)`, `Read(//**/*.pem)`, `Read(~/.ssh/**)`, `Read(~/.aws/**)`. Deny-first precedence wins even if an allow rule would otherwise match.
- **Bash exfil verbs.** `Bash(curl *)`, `Bash(wget *)`, `Bash(nc *)`, `Bash(ssh *)`, `Bash(scp *)`. Best-effort; the hook also scans command strings for sensitive-name reads via `cat`/`head`/`tail`/`type`/`Get-Content`.
- **Bash subprocess file access.** Permission rules don't protect against `python -c "open('../sibling/.env').read()"` — that's a subprocess, not a tool call. The hook inspects Bash command strings and blocks reads of sensitive paths or paths outside the project boundary. Best-effort against accidents.

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

Document the reason in the project's `.claude/README.md`. Future maintainers should know why the boundary was widened.

You cannot allow what the user-level guardrail denies — deny-first precedence wins. Categorical secret-name and exfil denies always apply.

## Sapient Industries managed-settings option (Team / Enterprise)

If your org is on Cowork Team or Enterprise, an admin can ship the guardrail block as **managed settings** instead of user-level. Two extra keys:

```json
{
  "allowManagedHooksOnly": true,
  "allowManagedPermissionRulesOnly": true,
  "permissions": {...},
  "hooks": {...}
}
```

Result: every CC session in the org loads only managed hooks and managed permission rules. Users can't disable the boundary. Stronger guarantee for enforcement-mandated environments.

The marketplace doesn't ship this directly — managed settings deployment is an admin workflow. Use the user-level install pattern as the template; deploy through your org's MDM or managed-settings file delivery mechanism.

## Troubleshooting

**Hook runs but doesn't block.** Check `~/.claude/hooks/boundary.log` for the action trail. If the file is empty, the hook isn't being called — verify `settings.json` includes the `hooks.PreToolUse` entry pointing at the script's absolute path.

**`jq: command not found`.** Install jq or use the PowerShell variant. The hook short-circuits with an advisory-only warning if jq is missing; you don't get the Bash containment in that case.

**`CLAUDE_PROJECT_DIR not set` warning in logs.** The hook is being invoked outside a Claude Code project session. Harmless — the hook allows the call and logs a notice. If you see this on every CC tool call, verify your session was launched with `--cwd` or inside a project root.

**Settings file got mangled.** The skill aborts and rolls back if the install verify step fails. If it didn't roll back cleanly (rare), uninstall to remove the guardrail block, then manually inspect `~/.claude/settings.json` for any leftover `_runesmith_guardrail_*` keys.

**Plugin update broke the guardrail.** Run `/runesmith-cc:guardrail verify`. If anything reports FAIL, run `install` again — it's idempotent and will repair drift.
