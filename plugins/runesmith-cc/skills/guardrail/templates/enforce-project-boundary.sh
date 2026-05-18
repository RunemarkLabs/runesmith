#!/usr/bin/env bash
# enforce-project-boundary.sh
#
# RuneSmith CC project-boundary enforcement hook.
# Fires on PreToolUse events. Reads JSON from stdin.
#
# Catches what the permission system can't see cleanly:
#   1. Bash subprocess commands that read files (cat, head, tail, less, more,
#      python -c "open(...)", node -e "fs.readFileSync(...)")
#   2. Bash file-write commands targeting paths outside $CLAUDE_PROJECT_DIR
#   3. Sensitive file path patterns regardless of tool (defense in depth on
#      top of the permission system's categorical denies)
#
# Exit codes:
#   0 - proceed (no decision)
#   2 - deny (stderr fed back to Claude as tool error)
#
# Logs deny decisions to ~/.claude/hooks/boundary.log for audit.

set -uo pipefail

LOG_FILE="${HOME}/.claude/hooks/boundary.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

INPUT=$(cat)

# Parse hook event fields. Fail loudly only if jq is missing.
if ! command -v jq >/dev/null 2>&1; then
  echo "boundary hook: jq not installed, skipping enforcement (open in advisory mode)" >&2
  exit 0
fi

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"

# Without a project dir we can't enforce a boundary. Allow with a warning.
if [[ -z "$PROJECT_DIR" ]]; then
  echo "boundary hook: CLAUDE_PROJECT_DIR not set, no boundary to enforce" >&2
  exit 0
fi

# Normalize project dir (resolve symlinks, trailing slashes)
PROJECT_DIR=$(cd "$PROJECT_DIR" 2>/dev/null && pwd -P) || PROJECT_DIR="$PROJECT_DIR"

deny() {
  local reason="$1"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)|DENY|${TOOL}|${reason}" >> "$LOG_FILE" 2>/dev/null
  echo "Blocked by RuneSmith guardrail: ${reason}" >&2
  exit 2
}

# ---- Sensitive-name patterns (apply to all tools) ----
check_sensitive_name() {
  local target="$1"
  case "$target" in
    *.credentials*|*credentials*|*.env|*.env.*|*id_rsa*|*id_ed25519*|*.key|*.pem)
      deny "sensitive file pattern matched: $target"
      ;;
    */.ssh/*|*/.aws/*|*/.gnupg/*)
      deny "sensitive directory pattern matched: $target"
      ;;
  esac
}

# ---- Tool-specific checks ----

case "$TOOL" in
  Read|Edit|Write)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    [[ -z "$FILE_PATH" ]] && exit 0
    check_sensitive_name "$FILE_PATH"
    # Note: project-boundary file_path check is handled by the permission
    # system's Read(/**) / Edit(/**) / Write(/**) allow rules with
    # defaultMode: "dontAsk". This hook is for defense-in-depth.
    ;;

  Bash)
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    [[ -z "$COMMAND" ]] && exit 0

    # Block sensitive-name reads in any form
    if echo "$COMMAND" | grep -qE '(\.credentials|\.env[^a-zA-Z]|id_rsa|id_ed25519|\.key[^a-zA-Z]|\.pem)' ; then
      # only deny if it's a read-class command
      if echo "$COMMAND" | grep -qE '\b(cat|head|tail|less|more|type|Get-Content|cp|mv|scp|rsync|grep|awk|sed)\b' ; then
        deny "Bash read of sensitive-pattern file: $COMMAND"
      fi
    fi

    # Block exfil verbs categorically
    if echo "$COMMAND" | grep -qE '^\s*(curl|wget|nc|ssh|scp|rsync)\b' ; then
      deny "exfil-class Bash command: $COMMAND"
    fi

    # Look for absolute paths outside the project dir in read-class commands
    # This is best-effort — adversarial Bash can evade.
    READ_CMDS_RE='\b(cat|head|tail|less|more|type|Get-Content|python|python3|node|ruby|perl)\b'
    if echo "$COMMAND" | grep -qE "$READ_CMDS_RE" ; then
      # Extract absolute-ish paths from the command (anything starting with / or ~)
      for tok in $(echo "$COMMAND" | tr ' ' '\n' | grep -E '^(/|~/|[A-Z]:[/\\])' || true); do
        # strip quotes
        tok=$(echo "$tok" | tr -d '"' | tr -d "'")
        # expand ~
        tok="${tok/#\~/$HOME}"
        # resolve to absolute
        abs=$(readlink -f "$tok" 2>/dev/null || echo "$tok")
        # check sensitive name first
        check_sensitive_name "$abs"
        # check inside project dir
        case "$abs" in
          "$PROJECT_DIR"|"$PROJECT_DIR"/*)
            : # inside, fine
            ;;
          /tmp/*|/var/tmp/*|/dev/null|/dev/stdin|/dev/stdout|/dev/stderr)
            : # transient/system, allowed
            ;;
          *)
            deny "Bash read outside project boundary: $tok (resolved: $abs)"
            ;;
        esac
      done
    fi
    ;;

  *)
    # Unknown tool — let it through. Permission system is still in effect.
    ;;
esac

exit 0
