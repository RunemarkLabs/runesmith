#!/usr/bin/env bash
# install-guardrail.sh
#
# Self-contained installer for the RuneSmith CC project-boundary guardrail.
# Run once per machine. Writes user-level ~/.claude/settings.json permission
# block + PreToolUse hook script that constrain every Claude Code session
# to its launch project's root.
#
# Usage:
#   ./install-guardrail.sh                  # install (or update existing)
#   ./install-guardrail.sh verify [WORKSPACE]  # verify install + AI attribution audit of {PROJECT}.cc heads
#   ./install-guardrail.sh uninstall        # remove

set -uo pipefail

MODE="${1:-install}"

CLAUDE_DIR="${HOME}/.claude"
HOOKS_DIR="${CLAUDE_DIR}/hooks"
SETTINGS_P="${CLAUDE_DIR}/settings.json"
HOOK_SH="${HOOKS_DIR}/enforce-project-boundary.sh"
MARKER_KEY='_runesmith_guardrail_marker'
KEYS_KEY='_runesmith_guardrail_keys'

# ---------- Hook script body (embedded) ----------

read -r -d '' HOOK_BODY <<'HOOK_EOF' || true
#!/usr/bin/env bash
# enforce-project-boundary.sh - RuneSmith CC project-boundary hook.
# Portable across macOS (BSD), Linux (GNU), Git Bash on Windows.
set -uo pipefail
LOG_FILE="${HOME}/.claude/hooks/boundary.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
INPUT=$(cat)
if ! command -v jq >/dev/null 2>&1; then
  echo "boundary hook: jq not installed, skipping enforcement (advisory mode)" >&2
  exit 0
fi
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
if [[ -z "$PROJECT_DIR" ]]; then exit 0; fi
PROJECT_DIR=$(cd "$PROJECT_DIR" 2>/dev/null && pwd -P) || PROJECT_DIR="$PROJECT_DIR"

# Portable realpath: GNU readlink -f, BSD/macOS realpath, or python3 fallback
resolve_path() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1" 2>/dev/null || echo "$1"
  elif readlink -f "$1" >/dev/null 2>&1; then
    readlink -f "$1"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$1" 2>/dev/null || echo "$1"
  else
    echo "$1"
  fi
}

deny() {
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)|DENY|${TOOL}|$1" >> "$LOG_FILE" 2>/dev/null
  echo "Blocked by RuneSmith guardrail: $1" >&2
  exit 2
}
check_sensitive() {
  case "$1" in
    *.credentials*|*credentials*|*.env|*.env.*|*id_rsa*|*id_ed25519*|*.key|*.pem) deny "sensitive file pattern: $1" ;;
    */.ssh/*|*/.aws/*|*/.gnupg/*) deny "sensitive directory pattern: $1" ;;
  esac
}
case "$TOOL" in
  Read|Edit|Write)
    FP=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    [[ -z "$FP" ]] && exit 0
    check_sensitive "$FP"
    ;;
  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    [[ -z "$CMD" ]] && exit 0
    if echo "$CMD" | grep -qE '(\.credentials|\.env[^a-zA-Z]|id_rsa|id_ed25519|\.key[^a-zA-Z]|\.pem)' && \
       echo "$CMD" | grep -qE '\b(cat|head|tail|less|more|grep|awk|sed|cp|mv|scp|rsync)\b'; then
      deny "Bash read of sensitive-pattern file: $CMD"
    fi
    if echo "$CMD" | grep -qE '^\s*(curl|wget|nc|ssh|scp|rsync)\b'; then
      deny "exfil-class Bash command: $CMD"
    fi
    READ_RE='\b(cat|head|tail|less|more|python|python3|node|ruby|perl)\b'
    if echo "$CMD" | grep -qE "$READ_RE"; then
      for tok in $(echo "$CMD" | tr ' ' '\n' | grep -E '^(/|~/)' || true); do
        tok=$(echo "$tok" | tr -d '"' | tr -d "'")
        tok="${tok/#\~/$HOME}"
        abs=$(resolve_path "$tok")
        check_sensitive "$abs"
        case "$abs" in
          "$PROJECT_DIR"|"$PROJECT_DIR"/*) : ;;
          /tmp/*|/var/tmp/*|/private/tmp/*|/private/var/folders/*|/dev/null|/dev/stdin|/dev/stdout|/dev/stderr) : ;;
          *) deny "Bash read outside project boundary: $tok (resolved: $abs)" ;;
        esac
      done
    fi
    ;;
esac
exit 0
HOOK_EOF

# ---------- Helpers ----------

step()   { printf "  \033[36m%s\033[0m\n" "$1"; }
ok()     { printf "  \033[32m%s\033[0m\n" "$1"; }
warn()   { printf "  \033[33m%s\033[0m\n" "$1"; }
fail()   { printf "  \033[31m%s\033[0m\n" "$1" >&2; }

need_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    fail "jq is required. Install: brew install jq (macOS), apt install jq (Debian/Ubuntu)."
    exit 1
  fi
}

guardrail_block_json() {
  local marker
  marker=$(uuidgen 2>/dev/null || python3 -c 'import uuid; print(uuid.uuid4())')
  cat <<JSON
{
  "${MARKER_KEY}": "${marker}",
  "${KEYS_KEY}": [
    "permissions.defaultMode",
    "permissions.allow[runesmith-guardrail]",
    "permissions.deny[runesmith-guardrail]",
    "hooks.PreToolUse[runesmith-guardrail]"
  ],
  "permissions": {
    "defaultMode": "dontAsk",
    "allow": [
      "Read(/**)","Edit(/**)","Write(/**)",
      "Grep","Glob",
      "Bash(ls *)","Bash(cat *)","Bash(echo *)","Bash(pwd)",
      "Bash(head *)","Bash(tail *)","Bash(grep *)","Bash(find *)",
      "Bash(wc *)","Bash(which *)","Bash(diff *)",
      "Bash(git status)","Bash(git diff *)","Bash(git log *)",
      "Bash(git branch *)","Bash(git show *)","Bash(git add *)",
      "Bash(git commit *)","Bash(git fetch *)",
      "Bash(npm test*)","Bash(npm run *)","Bash(npx *)",
      "Bash(pytest*)","Bash(python *)","Bash(node *)"
    ],
    "deny": [
      "Read(//**/.credentials*)","Read(//**/.env)","Read(//**/.env.*)",
      "Read(//**/id_rsa*)","Read(//**/id_ed25519*)",
      "Read(//**/*.key)","Read(//**/*.pem)",
      "Read(~/.ssh/**)","Read(~/.aws/**)","Read(~/.gnupg/**)",
      "Edit(//**/.credentials*)","Edit(//**/.env)","Edit(//**/.env.*)",
      "Write(//**/.credentials*)","Write(//**/.env)","Write(//**/.env.*)",
      "Bash(curl *)","Bash(wget *)","Bash(nc *)",
      "Bash(ssh *)","Bash(scp *)","Bash(rsync *)",
      "Bash(cat *credentials*)","Bash(cat *.env*)","Bash(cat *id_rsa*)",
      "Bash(cat *.key)","Bash(cat *.pem)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"\$HOME/.claude/hooks/enforce-project-boundary.sh\""
          }
        ]
      }
    ]
  }
}
JSON
}

test_hook() {
  local hook_path="$1"
  CLAUDE_PROJECT_DIR="$HOME" \
    bash -c 'echo "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$HOME/ok.txt\"}}" | bash "'"$hook_path"'"' 2>/dev/null
  local allow_code=$?
  CLAUDE_PROJECT_DIR="$HOME" \
    bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat /tmp/.credentials\"}}" | bash "'"$hook_path"'"' 2>/dev/null
  local deny_code=$?
  echo "allow=$allow_code deny=$deny_code"
  [[ "$allow_code" == 0 && "$deny_code" == 2 ]]
}

# ---------- Main flows ----------

cmd_install() {
  echo
  echo "RuneSmith CC Project-Boundary Guardrail - Install"
  echo "================================================="
  need_jq

  step "Creating $HOOKS_DIR"
  mkdir -p "$HOOKS_DIR"

  step "Writing $HOOK_SH"
  printf '%s\n' "$HOOK_BODY" > "$HOOK_SH"
  chmod +x "$HOOK_SH"

  step "Merging guardrail block into $SETTINGS_P"
  local existing="{}"
  if [[ -f "$SETTINGS_P" ]]; then
    if ! jq -e . "$SETTINGS_P" >/dev/null 2>&1; then
      fail "Existing $SETTINGS_P is not valid JSON. Aborting."
      exit 1
    fi
    existing=$(cat "$SETTINGS_P")
    if echo "$existing" | jq -e ".$MARKER_KEY" >/dev/null 2>&1; then
      warn "Existing guardrail install detected. Re-installing."
      existing=$(echo "$existing" | jq "del(.\"$MARKER_KEY\", .\"$KEYS_KEY\")")
    fi
  fi
  local block
  block=$(guardrail_block_json)
  echo "$existing" | jq --argjson b "$block" '
    . as $e |
    $b * $e * {
      ($b | to_entries[] | select(.key | startswith("_runesmith")) | .key): $b[.key | "$key"],
      permissions: (
        ((.permissions // {}) * ($b.permissions // {})) |
        .allow = (((.allow // []) + ($b.permissions.allow // [])) | unique) |
        .deny  = (((.deny  // []) + ($b.permissions.deny  // [])) | unique)
      ),
      hooks: (
        ((.hooks // {}) * ($b.hooks // {})) |
        .PreToolUse = (((.PreToolUse // []) + ($b.hooks.PreToolUse // [])))
      )
    } |
    .["'"$MARKER_KEY"'"] = $b["'"$MARKER_KEY"'"] |
    .["'"$KEYS_KEY"'"]   = $b["'"$KEYS_KEY"'"]
  ' > "$SETTINGS_P"

  step "Verifying hook (synthetic allow + deny events)"
  if test_hook "$HOOK_SH"; then
    ok "Hook verified."
  else
    warn "Hook test result unexpected - install completed but verify manually."
  fi

  echo
  echo "================================================="
  echo "Guardrail action: install"
  echo "Settings file:    $SETTINGS_P"
  echo "Hook script:      $HOOK_SH"
  echo "Status:           OK"
  echo
  echo "Known residual risks:"
  echo "  - Subagents bypass hook + permission rules (platform bugs)"
  echo "  - MCP tool calls are not boundary-aware"
  echo
  echo "Next step: restart any open Claude Code sessions for the new settings to load."
}

guardrail_verify() {
  if [[ ! -f "$SETTINGS_P" ]]; then
    fail "$SETTINGS_P does not exist. Guardrail not installed."
    return 1
  fi
  if ! jq -e ".$MARKER_KEY" "$SETTINGS_P" >/dev/null 2>&1; then
    fail "Marker key absent. Guardrail not installed."
    return 1
  fi
  local marker
  marker=$(jq -r ".$MARKER_KEY" "$SETTINGS_P")
  ok "Marker present: $marker"
  if [[ ! -f "$HOOK_SH" ]]; then
    fail "Hook script missing: $HOOK_SH"
    return 1
  fi
  ok "Hook script present: $HOOK_SH"
  if test_hook "$HOOK_SH"; then
    ok "Hook synthetic tests: PASS"
    return 0
  fi
  warn "Hook synthetic tests: FAIL - run install to repair."
  return 1
}

# ---------- AI attribution audit (report only, never rewrites history) ----------

ATTR_RE='^[[:space:]]*co-authored-by:.*(anthropic\.com|claude)|generated with \[?claude code|^[[:space:]]*claude-session:|claude\.ai/code/session_'

# Prints "off" when the merged settings files turn every attribution part off.
attribution_state() {
  local merged="{}" f
  for f in "$@"; do
    if [[ -f "$f" ]] && jq -e . "$f" >/dev/null 2>&1; then
      merged=$(jq -s '.[0] * .[1]' <(echo "$merged") "$f")
    fi
  done
  echo "$merged" | jq -r '
    if .attribution == false then "off"
    elif (.attribution | type) == "object"
         and .attribution.commit == "" and .attribution.pr == ""
         and .attribution.sessionUrl == false then "off"
    else "commit=\(.attribution.commit // "unset" | tojson) pr=\(.attribution.pr // "unset" | tojson) sessionUrl=\(if .attribution.sessionUrl == null then "unset" else .attribution.sessionUrl end)"
    end'
}

# Runs a commit-msg hook on a sample message; succeeds when no attribution survives.
hook_strips() {
  local repo="$1" hook="$2" tmp
  tmp=$(mktemp)
  printf 'chore: runesmith attribution probe\n\nCo-Authored-By: Claude <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_probe\n\nGenerated with [Claude Code](https://claude.com/claude-code)\n' > "$tmp"
  if git -C "$repo" hook run --ignore-missing runesmith-probe-none >/dev/null 2>&1; then
    git -C "$repo" hook run --ignore-missing commit-msg -- "$tmp" >/dev/null 2>&1
  else
    # git older than 2.36 has no "git hook run"; call the hook directly.
    ( cd "$repo" && sh "$hook" "$tmp" ) >/dev/null 2>&1
  fi
  if grep -qiE "$ATTR_RE" "$tmp"; then rm -f "$tmp"; return 1; fi
  rm -f "$tmp"; return 0
}

default_branch_ref() {
  local repo="$1" ref b
  ref=$(git -C "$repo" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) && { echo "$ref"; return; }
  for b in origin/main origin/master main master; do
    if git -C "$repo" rev-parse --verify -q "$b" >/dev/null 2>&1; then echo "$b"; return; fi
  done
  echo "HEAD"
}

attribution_audit() {
  local ws="$1" heads=() h repo problems=0
  echo
  echo "AI attribution (workspace: $ws)"
  echo "------------------------------------------------"
  if [[ -f "$SETTINGS_P" ]]; then
    local us
    us=$(attribution_state "$SETTINGS_P")
    if [[ "$us" == "off" ]]; then ok "User settings: attribution off"; else warn "User settings: attribution not off ($us) - CC heads still override this"; fi
  fi
  if [[ -f "$ws/.claude-code-workspace" ]]; then heads+=("$ws"); fi
  for h in "$ws"/*.cc; do
    [[ -d "$h" ]] && heads+=("$h")
  done
  if [[ ${#heads[@]} -eq 0 ]]; then
    warn "No {PROJECT}.cc head found under $ws. Run from the workspace root or pass its path."
    return 0
  fi
  for h in "${heads[@]}"; do
    echo
    echo "  Head: $h"
    local st
    st=$(attribution_state "$h/.claude/settings.json" "$h/.claude/settings.local.json")
    if [[ "$st" == "off" ]]; then ok "  settings: attribution off"; else fail "  settings: attribution not off ($st)"; problems=$((problems+1)); fi
    if [[ -f "$h/CLAUDE.md" ]] && grep -qiE 'attribution.{0,3}\(?hard rule' "$h/CLAUDE.md"; then
      ok "  CLAUDE.md: attribution rule present"
    else
      fail "  CLAUDE.md: attribution rule missing"; problems=$((problems+1))
    fi
    for repo in "$h"/*/; do
      repo="${repo%/}"
      [[ -e "$repo/.git" ]] || continue
      local name hooks_path hdir hook ref count shallow=""
      name=$(basename "$repo")
      hooks_path=$(git -C "$repo" config core.hooksPath 2>/dev/null || true)
      hdir=$(git -C "$repo" rev-parse --git-path hooks 2>/dev/null)
      [[ "$hdir" = /* ]] || hdir="$repo/$hdir"
      hook="$hdir/commit-msg"
      if [[ ! -f "$hook" ]]; then
        fail "  $name: no commit-msg hook${hooks_path:+ (core.hooksPath=$hooks_path)}"; problems=$((problems+1))
      elif ! hook_strips "$repo" "$hook"; then
        fail "  $name: commit-msg hook does not strip attribution"; problems=$((problems+1))
      elif grep -q 'runesmith-no-attribution' "$hook"; then
        ok "  $name: commit-msg hook (RuneSmith) strips attribution"
      else
        ok "  $name: commit-msg hook (custom) strips attribution"
      fi
      ref=$(default_branch_ref "$repo")
      count=$(git -C "$repo" log "$ref" -E -i --format=%h --grep="$ATTR_RE" 2>/dev/null | wc -l | tr -d ' ')
      [[ "$(git -C "$repo" rev-parse --is-shallow-repository 2>/dev/null)" == "true" ]] && shallow=" (shallow clone: fetched history only)"
      if [[ "$count" == "0" ]]; then
        ok "  $name: 0 commits on $ref carry attribution$shallow"
      else
        warn "  $name: $count commits on $ref carry attribution$shallow (report only; history not rewritten)"
      fi
    done
  done
  return $(( problems > 0 ? 1 : 0 ))
}

cmd_verify() {
  local ws="${1:-$PWD}" rc=0
  echo "RuneSmith CC Project-Boundary Guardrail - Verify"
  echo "================================================"
  need_jq
  guardrail_verify || rc=1
  attribution_audit "$ws" || rc=1
  echo
  if [[ $rc -eq 0 ]]; then echo "Status: OK"; else echo "Status: ATTENTION - see failures above (re-run install for the guardrail, /runesmith-cc:bootstrap-cc for attribution)"; fi
  exit $rc
}

cmd_uninstall() {
  echo "RuneSmith CC Project-Boundary Guardrail - Uninstall"
  echo "==================================================="
  if [[ ! -f "$SETTINGS_P" ]]; then
    warn "$SETTINGS_P does not exist. Nothing to remove."
    exit 0
  fi
  need_jq
  if ! jq -e ".$MARKER_KEY" "$SETTINGS_P" >/dev/null 2>&1; then
    warn "Marker absent. Guardrail does not appear to be installed."
    exit 0
  fi
  step "Removing marker keys from $SETTINGS_P"
  jq "del(.\"$MARKER_KEY\", .\"$KEYS_KEY\")" "$SETTINGS_P" > "$SETTINGS_P.tmp" && mv "$SETTINGS_P.tmp" "$SETTINGS_P"
  step "Removing $HOOK_SH"
  [[ -f "$HOOK_SH" ]] && rm "$HOOK_SH"
  echo
  echo "Status: OK - guardrail uninstalled"
  warn "Claude Code sessions on this machine no longer have a project boundary."
  warn "Permission rule entries added by the guardrail remain in"
  warn "  permissions.allow / permissions.deny. They are no-ops without"
  warn "  the hook, but review manually if you want to clean them."
}

case "$MODE" in
  install)   cmd_install ;;
  verify)    cmd_verify "${2:-$PWD}" ;;
  uninstall) cmd_uninstall ;;
  *) fail "Unknown mode: $MODE (use install | verify | uninstall)"; exit 1 ;;
esac
