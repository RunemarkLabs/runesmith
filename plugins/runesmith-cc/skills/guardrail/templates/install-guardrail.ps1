# install-guardrail.ps1
#
# Self-contained installer for the RuneSmith CC project-boundary guardrail.
# Run once per Windows machine. Writes user-level ~/.claude/settings.json
# permission block + PreToolUse hook script that constrain every Claude Code
# session to its launch project's root.
#
# Usage:
#   .\install-guardrail.ps1                # install (or update existing)
#   .\install-guardrail.ps1 -Mode verify   # verify install
#   .\install-guardrail.ps1 -Mode uninstall # remove
#
# What this writes:
#   %USERPROFILE%\.claude\settings.json  (merged - preserves your user keys)
#   %USERPROFILE%\.claude\hooks\enforce-project-boundary.sh  (Git Bash variant)
#   %USERPROFILE%\.claude\hooks\enforce-project-boundary.ps1 (PowerShell shim)
#
# What this enforces:
#   - Cross-project filesystem reads blocked (Read/Edit/Write outside CLAUDE_PROJECT_DIR denied)
#   - Categorical secret-name deny (.credentials, .env, id_rsa*, *.key, *.pem, ~/.ssh, ~/.aws, ~/.gnupg)
#   - Bash exfil-verb deny (curl, wget, nc, ssh, scp, rsync)
#   - Bash subprocess file-access hook for paths the permission system can't see
#
# Known residual risks (not solved):
#   - Subagents bypass the hook + permission rules (platform bugs #27661, #23983)
#   - Bash on Windows is unsandboxed; substring matchers evadeable
#   - MCP tool calls are not boundary-aware

param(
    [ValidateSet('install', 'verify', 'uninstall')]
    [string]$Mode = 'install'
)

$ErrorActionPreference = 'Stop'

$ClaudeDir   = "$env:USERPROFILE\.claude"
$HooksDir    = "$ClaudeDir\hooks"
$SettingsP   = "$ClaudeDir\settings.json"
$HookBash    = "$HooksDir\enforce-project-boundary.sh"
$HookPs1     = "$HooksDir\enforce-project-boundary.ps1"
$MarkerKey   = '_runesmith_guardrail_marker'
$KeysKey     = '_runesmith_guardrail_keys'

# ---------- Hook script bodies (embedded) ----------

$HookBashBody = @'
#!/usr/bin/env bash
# enforce-project-boundary.sh - RuneSmith CC project-boundary hook.
# Reads PreToolUse event from stdin. Exit 0 = proceed, exit 2 = block.

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

if [[ -z "$PROJECT_DIR" ]]; then
  echo "boundary hook: CLAUDE_PROJECT_DIR not set, no boundary to enforce" >&2
  exit 0
fi
PROJECT_DIR=$(cd "$PROJECT_DIR" 2>/dev/null && pwd -P) || PROJECT_DIR="$PROJECT_DIR"

deny() {
  local reason="$1"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)|DENY|${TOOL}|${reason}" >> "$LOG_FILE" 2>/dev/null
  echo "Blocked by RuneSmith guardrail: ${reason}" >&2
  exit 2
}

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

case "$TOOL" in
  Read|Edit|Write)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    [[ -z "$FILE_PATH" ]] && exit 0
    check_sensitive_name "$FILE_PATH"
    ;;
  Bash)
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    [[ -z "$COMMAND" ]] && exit 0
    if echo "$COMMAND" | grep -qE '(\.credentials|\.env[^a-zA-Z]|id_rsa|id_ed25519|\.key[^a-zA-Z]|\.pem)' ; then
      if echo "$COMMAND" | grep -qE '\b(cat|head|tail|less|more|type|Get-Content|cp|mv|scp|rsync|grep|awk|sed)\b' ; then
        deny "Bash read of sensitive-pattern file: $COMMAND"
      fi
    fi
    if echo "$COMMAND" | grep -qE '^\s*(curl|wget|nc|ssh|scp|rsync)\b' ; then
      deny "exfil-class Bash command: $COMMAND"
    fi
    READ_CMDS_RE='\b(cat|head|tail|less|more|type|Get-Content|python|python3|node|ruby|perl)\b'
    if echo "$COMMAND" | grep -qE "$READ_CMDS_RE" ; then
      for tok in $(echo "$COMMAND" | tr ' ' '\n' | grep -E '^(/|~/|[A-Z]:[/\\])' || true); do
        tok=$(echo "$tok" | tr -d '"' | tr -d "'")
        tok="${tok/#\~/$HOME}"
        abs=$(readlink -f "$tok" 2>/dev/null || echo "$tok")
        check_sensitive_name "$abs"
        case "$abs" in
          "$PROJECT_DIR"|"$PROJECT_DIR"/*) : ;;
          /tmp/*|/var/tmp/*|/dev/null|/dev/stdin|/dev/stdout|/dev/stderr) : ;;
          *) deny "Bash read outside project boundary: $tok (resolved: $abs)" ;;
        esac
      done
    fi
    ;;
esac

exit 0
'@

$HookPs1Body = @'
# enforce-project-boundary.ps1 - RuneSmith CC project-boundary hook (Windows native).
$ErrorActionPreference = 'Continue'
$LogFile = "$env:USERPROFILE\.claude\hooks\boundary.log"
$LogDir  = Split-Path -Parent $LogFile
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
$Input = [Console]::In.ReadToEnd()
try { $Event = $Input | ConvertFrom-Json } catch { exit 0 }
$Tool = $Event.tool_name
$ProjectDir = $env:CLAUDE_PROJECT_DIR
if (-not $ProjectDir) { [Console]::Error.WriteLine("boundary hook: CLAUDE_PROJECT_DIR not set"); exit 0 }
try { $ProjectDir = (Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop).Path } catch { }
function Deny([string]$Reason) {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    Add-Content -Path $LogFile -Value "$ts|DENY|$Tool|$Reason" -ErrorAction SilentlyContinue
    [Console]::Error.WriteLine("Blocked by RuneSmith guardrail: $Reason")
    exit 2
}
function Test-SensitiveName([string]$Target) {
    $patterns = @('\.credentials','credentials','\.env(?:$|\.|[^a-zA-Z])','id_rsa','id_ed25519','\.key$','\.pem$','\\\.ssh\\','\\\.aws\\','\\\.gnupg\\','/\.ssh/','/\.aws/','/\.gnupg/')
    foreach ($p in $patterns) { if ($Target -match $p) { Deny "sensitive pattern matched: $Target" } }
}
switch ($Tool) {
    { $_ -in @('Read','Edit','Write') } {
        $FilePath = $Event.tool_input.file_path
        if ($FilePath) { Test-SensitiveName $FilePath }
    }
    'Bash' {
        $Command = $Event.tool_input.command
        if (-not $Command) { exit 0 }
        if ($Command -match '(\.credentials|\.env[^a-zA-Z]|id_rsa|id_ed25519|\.key[^a-zA-Z]|\.pem)' -and
            $Command -match '\b(cat|head|tail|less|more|type|Get-Content|cp|mv|scp|rsync|grep|awk|sed)\b') {
            Deny "Bash read of sensitive-pattern file: $Command"
        }
        if ($Command -match '^\s*(curl|wget|nc|ssh|scp|rsync)\b') {
            Deny "exfil-class Bash command: $Command"
        }
        if ($Command -match '\b(cat|head|tail|less|more|type|Get-Content|python|python3|node|ruby|perl)\b') {
            $tokens = $Command -split '\s+' | Where-Object { $_ -match '^(/|~/|[A-Z]:[/\\])' }
            foreach ($tok in $tokens) {
                $clean = $tok.Trim('"', "'")
                $expanded = $clean -replace '^~', $env:USERPROFILE
                try { $abs = (Resolve-Path -LiteralPath $expanded -ErrorAction Stop).Path } catch { $abs = $expanded }
                Test-SensitiveName $abs
                $insideProject = $abs.StartsWith($ProjectDir, [StringComparison]::OrdinalIgnoreCase)
                $allowedSystem = $abs -match '^(C:\\Windows\\Temp\\|C:\\Users\\[^\\]+\\AppData\\Local\\Temp\\)' -or $abs -in @('NUL','CON','PRN')
                if (-not $insideProject -and -not $allowedSystem) {
                    Deny "Bash read outside project boundary: $tok (resolved: $abs)"
                }
            }
        }
    }
}
exit 0
'@

# ---------- Settings block (the guardrail's permission rules + hook entry) ----------

function Get-GuardrailBlock([bool]$UseGitBash) {
    $hookCmd = if ($UseGitBash) {
        'bash "$HOME/.claude/hooks/enforce-project-boundary.sh"'
    } else {
        'powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.claude\hooks\enforce-project-boundary.ps1"'
    }

    return @{
        $MarkerKey = [guid]::NewGuid().ToString()
        $KeysKey = @(
            "permissions.defaultMode",
            "permissions.allow[runesmith-guardrail]",
            "permissions.deny[runesmith-guardrail]",
            "hooks.PreToolUse[runesmith-guardrail]"
        )
        permissions = @{
            defaultMode = "dontAsk"
            allow = @(
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
            )
            deny = @(
                "Read(//**/.credentials*)","Read(//**/.env)","Read(//**/.env.*)",
                "Read(//**/id_rsa*)","Read(//**/id_ed25519*)",
                "Read(//**/*.key)","Read(//**/*.pem)",
                "Read(~/.ssh/**)","Read(~/.aws/**)","Read(~/.gnupg/**)",
                "Edit(//**/.credentials*)","Edit(//**/.env)","Edit(//**/.env.*)",
                "Write(//**/.credentials*)","Write(//**/.env)","Write(//**/.env.*)",
                "Bash(curl *)","Bash(wget *)","Bash(nc *)",
                "Bash(ssh *)","Bash(scp *)","Bash(rsync *)",
                "Bash(cat *credentials*)","Bash(cat *.env*)","Bash(cat *id_rsa*)",
                "Bash(cat *.key)","Bash(cat *.pem)",
                "Bash(type *credentials*)","Bash(type *.env*)",
                "Bash(Get-Content *credentials*)","Bash(Get-Content *.env*)"
            )
        }
        hooks = @{
            PreToolUse = @(
                @{
                    matcher = "Bash"
                    hooks = @(
                        @{
                            type = "command"
                            command = $hookCmd
                        }
                    )
                }
            )
        }
    }
}

# ---------- Helpers ----------

function Write-Step([string]$Msg) {
    Write-Host "  $Msg" -ForegroundColor Cyan
}

function Write-Ok([string]$Msg) {
    Write-Host "  $Msg" -ForegroundColor Green
}

function Write-Warn([string]$Msg) {
    Write-Host "  $Msg" -ForegroundColor Yellow
}

function Write-Fail([string]$Msg) {
    Write-Host "  $Msg" -ForegroundColor Red
}

function Test-GitBash {
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    $jq   = Get-Command jq -ErrorAction SilentlyContinue
    return ($bash -ne $null) -and ($jq -ne $null)
}

function Merge-Settings([hashtable]$Existing, [hashtable]$Block) {
    # Top-level marker keys
    $Existing[$MarkerKey] = $Block[$MarkerKey]
    $Existing[$KeysKey]   = $Block[$KeysKey]

    # permissions
    if (-not $Existing.ContainsKey('permissions')) { $Existing['permissions'] = @{} }
    $perms = $Existing['permissions']

    if ($perms -is [PSCustomObject]) { $perms = ConvertTo-Hashtable $perms; $Existing['permissions'] = $perms }
    if (-not $perms.ContainsKey('defaultMode')) { $perms['defaultMode'] = 'dontAsk' }
    if (-not $perms.ContainsKey('allow')) { $perms['allow'] = @() }
    if (-not $perms.ContainsKey('deny'))  { $perms['deny']  = @() }

    $perms['allow'] = @($perms['allow'] + $Block.permissions.allow | Select-Object -Unique)
    $perms['deny']  = @($perms['deny']  + $Block.permissions.deny  | Select-Object -Unique)

    # hooks
    if (-not $Existing.ContainsKey('hooks')) { $Existing['hooks'] = @{} }
    $hooks = $Existing['hooks']
    if ($hooks -is [PSCustomObject]) { $hooks = ConvertTo-Hashtable $hooks; $Existing['hooks'] = $hooks }
    if (-not $hooks.ContainsKey('PreToolUse')) { $hooks['PreToolUse'] = @() }
    $hooks['PreToolUse'] = @($hooks['PreToolUse']) + $Block.hooks.PreToolUse

    return $Existing
}

function ConvertTo-Hashtable($obj) {
    if ($obj -is [hashtable]) { return $obj }
    if ($obj -is [array]) {
        return @($obj | ForEach-Object { ConvertTo-Hashtable $_ })
    }
    if ($obj -is [PSCustomObject]) {
        $h = @{}
        foreach ($p in $obj.PSObject.Properties) {
            $h[$p.Name] = ConvertTo-Hashtable $p.Value
        }
        return $h
    }
    return $obj
}

function Test-Hook([string]$HookPath, [bool]$UseGitBash) {
    # Allow case: file_path inside CLAUDE_PROJECT_DIR
    $env:CLAUDE_PROJECT_DIR = $env:USERPROFILE
    $allowEvent = @{
        session_id      = "test"
        cwd             = $env:USERPROFILE
        hook_event_name = "PreToolUse"
        tool_name       = "Read"
        tool_input      = @{ file_path = "$env:USERPROFILE\ok.txt" }
    } | ConvertTo-Json -Compress

    # Deny case: bash with credentials read
    $denyEvent = @{
        session_id      = "test"
        cwd             = $env:USERPROFILE
        hook_event_name = "PreToolUse"
        tool_name       = "Bash"
        tool_input      = @{ command = "cat /tmp/.credentials" }
    } | ConvertTo-Json -Compress

    if ($UseGitBash) {
        $allowExit = $allowEvent | & bash $HookPath 2>$null
        $allowCode = $LASTEXITCODE
        $denyExit  = $denyEvent  | & bash $HookPath 2>$null
        $denyCode  = $LASTEXITCODE
    } else {
        $allowExit = $allowEvent | & powershell -ExecutionPolicy Bypass -File $HookPath 2>$null
        $allowCode = $LASTEXITCODE
        $denyExit  = $denyEvent  | & powershell -ExecutionPolicy Bypass -File $HookPath 2>$null
        $denyCode  = $LASTEXITCODE
    }

    return @{
        AllowCode = $allowCode
        DenyCode  = $denyCode
        AllowPass = ($allowCode -eq 0)
        DenyPass  = ($denyCode -eq 2)
    }
}

# ---------- Main flows ----------

function Invoke-Install {
    Write-Host "`nRuneSmith CC Project-Boundary Guardrail - Install" -ForegroundColor White
    Write-Host "================================================="

    # 1. Environment detection
    $useGitBash = Test-GitBash
    if ($useGitBash) {
        Write-Ok "Git Bash + jq detected. Using bash hook variant."
    } else {
        Write-Warn "Git Bash or jq not found. Using PowerShell hook variant."
        Write-Warn "  (For richer Bash containment, install Git for Windows + 'choco install jq', then re-run.)"
    }

    # 2. Existing install detection
    $existing = @{}
    if (Test-Path $SettingsP) {
        try {
            $raw = Get-Content $SettingsP -Raw
            if ($raw.Trim()) {
                $existing = ConvertTo-Hashtable ($raw | ConvertFrom-Json)
            }
        } catch {
            Write-Fail "Existing $SettingsP is not valid JSON. Aborting to avoid overwriting an unreadable file."
            Write-Fail "  Error: $($_.Exception.Message)"
            Write-Fail "  Fix the file manually or delete it, then re-run."
            exit 1
        }
        if ($existing.ContainsKey($MarkerKey)) {
            Write-Warn "Existing guardrail install detected (marker: $($existing[$MarkerKey]))."
            Write-Warn "Re-installing will replace owned entries; user-managed keys preserved."
        }
    }

    # 3. Create hooks dir
    Write-Step "Creating $HooksDir"
    New-Item -ItemType Directory -Force -Path $HooksDir | Out-Null

    # 4. Write hook scripts
    Write-Step "Writing $HookBash"
    Set-Content -Path $HookBash -Value $HookBashBody -NoNewline -Encoding UTF8
    Write-Step "Writing $HookPs1"
    Set-Content -Path $HookPs1 -Value $HookPs1Body -NoNewline -Encoding UTF8

    # 5. Merge settings
    Write-Step "Merging guardrail block into $SettingsP"
    $block = Get-GuardrailBlock -UseGitBash $useGitBash

    # Remove any prior guardrail-owned entries before merging (idempotent reinstall)
    if ($existing.ContainsKey($MarkerKey)) {
        $existing.Remove($MarkerKey) | Out-Null
        $existing.Remove($KeysKey) | Out-Null
        # Note: we don't strip prior allow/deny entries by content since the user
        # may have added their own copies; we dedupe on merge instead.
    }

    $merged = Merge-Settings $existing $block
    $json   = $merged | ConvertTo-Json -Depth 20
    Set-Content -Path $SettingsP -Value $json -Encoding UTF8

    # 6. Verify the hook
    Write-Step "Verifying hook (synthetic allow + deny events)"
    $hookPath = if ($useGitBash) { $HookBash } else { $HookPs1 }
    $result = Test-Hook -HookPath $hookPath -UseGitBash $useGitBash
    if ($result.AllowPass -and $result.DenyPass) {
        Write-Ok "Hook verified: allow=$($result.AllowCode), deny=$($result.DenyCode)"
    } else {
        Write-Warn "Hook test result: allow=$($result.AllowCode) (expect 0), deny=$($result.DenyCode) (expect 2)"
        Write-Warn "  Install completed but hook may not fire as expected. Test interactively in a CC session."
    }

    # 7. Report
    Write-Host ""
    Write-Host "================================================="
    Write-Host "Guardrail action: install" -ForegroundColor White
    Write-Host "Settings file:    $SettingsP"
    Write-Host "Hook script:      $hookPath"
    Write-Host "Hook variant:     $(if ($useGitBash) { 'bash + jq' } else { 'PowerShell (no extra deps)' })"
    Write-Host "Status:           OK" -ForegroundColor Green
    Write-Host ""
    Write-Host "Known residual risks (documented, not solved):"
    Write-Host "  - Subagents bypass hook + permission rules (platform bugs)"
    Write-Host "  - Bash on Windows is unsandboxed; substring matchers evadeable"
    Write-Host "  - MCP tool calls are not boundary-aware"
    Write-Host ""
    Write-Host "Next step: restart any open Claude Code sessions for the new settings to load." -ForegroundColor Yellow
}

function Invoke-Verify {
    Write-Host "`nRuneSmith CC Project-Boundary Guardrail - Verify" -ForegroundColor White
    Write-Host "================================================"

    if (-not (Test-Path $SettingsP)) {
        Write-Fail "$SettingsP does not exist."
        Write-Host "Status: NOT INSTALLED" -ForegroundColor Red
        exit 1
    }

    try {
        $raw = Get-Content $SettingsP -Raw
        $existing = ConvertTo-Hashtable ($raw | ConvertFrom-Json)
    } catch {
        Write-Fail "Cannot parse $SettingsP as JSON."
        Write-Fail "  Error: $($_.Exception.Message)"
        exit 1
    }

    if (-not $existing.ContainsKey($MarkerKey)) {
        Write-Fail "Marker key '$MarkerKey' absent. Guardrail not installed."
        Write-Host "Status: NOT INSTALLED" -ForegroundColor Red
        exit 1
    }
    Write-Ok "Marker present: $($existing[$MarkerKey])"

    $useGitBash = Test-GitBash
    $hookPath = if ($useGitBash) { $HookBash } else { $HookPs1 }
    if (-not (Test-Path $hookPath)) {
        Write-Fail "Hook script missing: $hookPath"
        Write-Host "Status: PARTIAL - run install to repair" -ForegroundColor Red
        exit 1
    }
    Write-Ok "Hook script present: $hookPath"

    $perms = $existing['permissions']
    if ($perms -and $perms['defaultMode'] -eq 'dontAsk') {
        Write-Ok "permissions.defaultMode = dontAsk"
    } else {
        Write-Warn "permissions.defaultMode != 'dontAsk' (got: $($perms['defaultMode']))"
    }

    $result = Test-Hook -HookPath $hookPath -UseGitBash $useGitBash
    if ($result.AllowPass) { Write-Ok "Hook allow case: PASS" } else { Write-Fail "Hook allow case: FAIL ($($result.AllowCode))" }
    if ($result.DenyPass)  { Write-Ok "Hook deny case:  PASS" } else { Write-Fail "Hook deny case:  FAIL ($($result.DenyCode))" }

    Write-Host ""
    Write-Host "Status: $(if ($result.AllowPass -and $result.DenyPass) { 'OK' } else { 'PARTIAL - run install to repair' })" `
        -ForegroundColor $(if ($result.AllowPass -and $result.DenyPass) { 'Green' } else { 'Yellow' })
}

function Invoke-Uninstall {
    Write-Host "`nRuneSmith CC Project-Boundary Guardrail - Uninstall" -ForegroundColor White
    Write-Host "==================================================="

    if (-not (Test-Path $SettingsP)) {
        Write-Warn "$SettingsP does not exist. Nothing to remove."
        exit 0
    }

    try {
        $raw = Get-Content $SettingsP -Raw
        $existing = ConvertTo-Hashtable ($raw | ConvertFrom-Json)
    } catch {
        Write-Fail "Cannot parse $SettingsP as JSON. Aborting."
        exit 1
    }

    if (-not $existing.ContainsKey($MarkerKey)) {
        Write-Warn "Marker key absent. Guardrail does not appear to be installed."
        exit 0
    }

    Write-Step "Removing marker keys"
    $existing.Remove($MarkerKey) | Out-Null
    $existing.Remove($KeysKey) | Out-Null

    # We do NOT strip permissions.allow/deny entries by content - they may
    # include user-managed copies. Warn the user instead.
    Write-Warn "Note: permission rule entries added by the guardrail remain in"
    Write-Warn "  permissions.allow / permissions.deny. They are no-ops without"
    Write-Warn "  the hook, but you may want to review them manually."

    Write-Step "Writing $SettingsP"
    $json = $existing | ConvertTo-Json -Depth 20
    Set-Content -Path $SettingsP -Value $json -Encoding UTF8

    Write-Step "Removing hook scripts"
    if (Test-Path $HookBash) { Remove-Item $HookBash -Force }
    if (Test-Path $HookPs1)  { Remove-Item $HookPs1  -Force }

    Write-Host ""
    Write-Host "Status: OK - guardrail uninstalled" -ForegroundColor Green
    Write-Host ""
    Write-Host "Warning: Claude Code sessions on this machine no longer have a project boundary." -ForegroundColor Yellow
    Write-Host "Restart any open CC sessions for the change to take effect." -ForegroundColor Yellow
}

# ---------- Dispatch ----------

switch ($Mode) {
    'install'   { Invoke-Install }
    'verify'    { Invoke-Verify }
    'uninstall' { Invoke-Uninstall }
}
