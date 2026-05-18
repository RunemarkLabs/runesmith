---
name: guardrail
description: >
  Install, uninstall, or verify the CC project-boundary guardrail. Writes user-level ~/.claude/settings.json with default-deny permissions and a PreToolUse hook that contains Bash subprocess access to the launch project. Prevents cross-project filesystem reads (the credential-leak class of bug). Run once per machine. Use when the user says "install the guardrail", "set up CC boundaries", "lock CC to project root", "guardrail install", "guardrail verify", "uninstall the guardrail".
---

# CC Project-Boundary Guardrail

Two-layer enforcement for Claude Code's project-root boundary. Layer 1 (behavioral) ships as part of `bootstrap-cc`'s CLAUDE.md template — every CC head gets it on bootstrap. Layer 2 (harness enforcement) is this skill: a user-level `~/.claude/settings.json` block plus a `PreToolUse` hook script that stays put once installed and protects every CC session on the machine.

## References

- `lib/agent-operating-principles.md` — Layer 1 source, includes the cross-project and credentials-class refusal rules.
- `lib/consent.md` — trigger phrases (install / uninstall / verify each require explicit consent).
- `lib/user-prompts.md` — structured-prompt protocol.
- `templates/user-settings-block.json` — the JSON block this skill merges into the user's `settings.json`.
- `templates/enforce-project-boundary.sh` — bash hook script (primary).
- `templates/enforce-project-boundary.ps1` — PowerShell shim (Windows without Git Bash).
- `templates/project-settings.json` — project-level escape-hatch scaffolding (also written by `bootstrap-cc`).
- `templates/project-claude-readme.md` — the project-level `.claude/README.md` explaining the boundary.

## What this enforces

**File access boundary** — user-level permission rules with `defaultMode: "dontAsk"` and project-relative `Read(/**)` / `Edit(/**)` / `Write(/**)` allow rules. Permission system auto-denies any file op outside the active project's root.

**Categorical secret deny** — `Read(//**/.credentials*)`, `Read(//**/.env*)`, `Read(//**/id_rsa*)`, `Read(//**/*.key)`, `Read(//**/*.pem)`, `Read(~/.ssh/**)`, `Read(~/.aws/**)`. Wins over any allow rule (deny-first precedence). Catches the Mix Tape credential-leak class even from inside the boundary.

**Bash exfil deny** — `Bash(curl *)`, `Bash(wget *)`, `Bash(nc *)`, `Bash(ssh *)`, `Bash(scp *)`. Best-effort against accidents; not airtight against adversarial Bash escaping. Documented.

**Bash file-access hook** — for cases the permission system can't see (Python/Node scripts that open files), `PreToolUse` hook inspects Bash commands and blocks reads of known sensitive paths or paths outside `$CLAUDE_PROJECT_DIR`.

**Project escape hatch** — `{PROJECT}/.claude/settings.json` can list `additionalDirectories` to extend the boundary for legitimate cross-project access (monorepo siblings, shared configs). Documented in the per-project `{PROJECT}/.claude/README.md` written by bootstrap-cc.

## Known residuals

- **Subagents bypass the hook and permission rules.** Tracked upstream (issues #27661, #23983). Layer 1 (advisory CLAUDE.md rules) is the only protection inside a subagent.
- **Bash on Windows is unsandboxed.** PowerShell pipes, indirect command invocation, and shell escaping can evade the substring matchers. Hook catches accidents, not attacks.
- **MCP tool calls are not boundary-aware.** Any installed MCP tool can be called from any project. Tracked separately for a follow-up plan.

## Pre-flight checks

### 0. Comms check (skip — this is a user-level install, not a project skill)

This skill operates at user-level, not against a project. No comms folder to check.

### 1. OS detection

Detect platform via `uname -s` (macOS/Linux) or `$env:OS` (Windows). Determines:
- User settings file path: `~/.claude/settings.json` on macOS/Linux, `%USERPROFILE%\.claude\settings.json` on Windows.
- Hook script extension and shell: `.sh` with bash on macOS/Linux, `.sh` via Git Bash if available else `.ps1` on Windows.
- jq availability: required for bash variant. If absent, prompt to install (`brew install jq` / `apt install jq` / `choco install jq`).

### 2. Confirm action

Structured prompt — single-pick: `install` / `uninstall` / `verify` / `cancel`. Never proceed without an explicit selection.

For `install`: if the settings file already contains a `runesmith-guardrail:start` marker, prompt: `update existing install` / `reinstall fresh` / `cancel`.

## Install flow

### Step 1 — Resolve target settings file

```
macOS/Linux:  ~/.claude/settings.json
Windows:      %USERPROFILE%\.claude\settings.json
```

If the file doesn't exist, create it as `{}`. If it exists, parse as JSON (fail loudly on invalid JSON; never overwrite an unreadable file).

### Step 2 — Merge the guardrail block

The block is marker-bounded so uninstall can find and remove only what the skill owns:

```
// runesmith-guardrail:start
{
  "permissions": { ... },
  "hooks": { ... }
}
// runesmith-guardrail:end
```

Implementation: settings.json is JSON, not JSON-with-comments, so the markers live as a stable key prefix instead. The skill writes a top-level key `_runesmith_guardrail_marker` set to a known UUID-string at install time, and a parallel `_runesmith_guardrail_keys` array listing every key path it added under `permissions` and `hooks`. Uninstall removes only entries whose key paths match.

Merge semantics:
- `permissions.defaultMode` — set to `"dontAsk"`. If the user already has a different value, prompt: `keep yours` / `use dontAsk` / `cancel`.
- `permissions.allow` — array union. Add the curated allow rules, dedupe.
- `permissions.deny` — array union. Add the curated deny rules, dedupe.
- `hooks.PreToolUse` — array append. Add the boundary hook matcher entry.

See `templates/user-settings-block.json` for the literal block.

### Step 3 — Write the hook script

```
macOS/Linux:  ~/.claude/hooks/enforce-project-boundary.sh
Windows:      %USERPROFILE%\.claude\hooks\enforce-project-boundary.sh (Git Bash present)
              %USERPROFILE%\.claude\hooks\enforce-project-boundary.ps1 (no Git Bash)
```

Source: `templates/enforce-project-boundary.sh` and `templates/enforce-project-boundary.ps1`. Chmod +x on Unix.

### Step 4 — Verify

Run the hook against a synthetic deny case (a `tool_input.file_path` outside `CLAUDE_PROJECT_DIR`) and a synthetic allow case (inside). Confirm exit codes match (2 and 0 respectively). If either fails, abort and roll back the settings merge.

### Step 5 — Report

Single structured summary: settings file path, hook script path, what's covered, residual risks. Tell the user to restart any open Claude Code sessions for the new settings to load.

## Uninstall flow

### Step 1 — Locate marker

Parse user settings file. Find `_runesmith_guardrail_marker` and `_runesmith_guardrail_keys`. If absent, report nothing to remove and exit clean.

### Step 2 — Remove owned entries

Walk `_runesmith_guardrail_keys`. For each key path, remove the value the skill added (not the parent container — only the specific entries). Use the JSON-aware diff so user-managed keys in `permissions.allow` etc. survive.

### Step 3 — Remove marker

Delete `_runesmith_guardrail_marker` and `_runesmith_guardrail_keys`.

### Step 4 — Remove hook script

Delete `enforce-project-boundary.sh` and `enforce-project-boundary.ps1` from `~/.claude/hooks/`.

### Step 5 — Report

Confirm what was removed. Warn that CC sessions no longer have a project boundary; the user should consider re-running install or accepting the residual exposure.

## Verify flow

### Step 1 — Check marker

Confirm `_runesmith_guardrail_marker` exists in user settings. If absent, report "not installed."

### Step 2 — Smoke-test hook

Pipe a synthetic event into the hook (allow case + deny case). Confirm exit codes are 0 and 2.

### Step 3 — Confirm settings shape

Parse settings file. Confirm:
- `permissions.defaultMode === "dontAsk"`
- All entries in the install block's `permissions.allow` are present
- All entries in the install block's `permissions.deny` are present
- `hooks.PreToolUse` includes the boundary matcher

### Step 4 — Report

Structured report. Each check pass/fail. If any fail, suggest `install` to repair.

## Output reporting (all flows)

End every flow with a single structured summary block:

```
Guardrail action: install | uninstall | verify
Settings file:    /Users/ben/.claude/settings.json
Hook script:      /Users/ben/.claude/hooks/enforce-project-boundary.sh
Status:           OK | FAIL
Details:          ...
Next step:        Restart any open Claude Code sessions.
```

No prose preamble. No emoji. No questions about whether to proceed — those happened in the structured-prompt step.
