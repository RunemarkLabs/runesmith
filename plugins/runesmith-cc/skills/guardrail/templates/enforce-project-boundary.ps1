# enforce-project-boundary.ps1
#
# Windows-native PowerShell shim for the RuneSmith CC project-boundary
# guardrail. Use when Git Bash is not available. Mirrors the bash variant's
# semantics. Reads JSON from stdin, writes blocked-reason to stderr on deny,
# exits 0 (proceed) or 2 (deny).

$ErrorActionPreference = 'Continue'

$LogFile = "$env:USERPROFILE\.claude\hooks\boundary.log"
$LogDir  = Split-Path -Parent $LogFile
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }

$Input = [Console]::In.ReadToEnd()
try {
    $Event = $Input | ConvertFrom-Json
} catch {
    # Bad input — let it through, log nothing
    exit 0
}

$Tool        = $Event.tool_name
$ProjectDir  = $env:CLAUDE_PROJECT_DIR

if (-not $ProjectDir) {
    [Console]::Error.WriteLine("boundary hook: CLAUDE_PROJECT_DIR not set, no boundary to enforce")
    exit 0
}

# Normalize project dir
try {
    $ProjectDir = (Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop).Path
} catch { }

function Deny([string]$Reason) {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    Add-Content -Path $LogFile -Value "$ts|DENY|$Tool|$Reason" -ErrorAction SilentlyContinue
    [Console]::Error.WriteLine("Blocked by RuneSmith guardrail: $Reason")
    exit 2
}

function Test-SensitiveName([string]$Target) {
    $sensitivePatterns = @(
        '\.credentials', 'credentials',
        '\.env(?:$|\.|[^a-zA-Z])',
        'id_rsa', 'id_ed25519',
        '\.key$', '\.pem$',
        '\\\.ssh\\', '\\\.aws\\', '\\\.gnupg\\',
        '/\.ssh/', '/\.aws/', '/\.gnupg/'
    )
    foreach ($p in $sensitivePatterns) {
        if ($Target -match $p) { Deny "sensitive pattern matched: $Target" }
    }
}

switch ($Tool) {
    { $_ -in @('Read','Edit','Write') } {
        $FilePath = $Event.tool_input.file_path
        if ($FilePath) { Test-SensitiveName $FilePath }
    }

    'Bash' {
        $Command = $Event.tool_input.command
        if (-not $Command) { exit 0 }

        # Sensitive-name reads
        if ($Command -match '(\.credentials|\.env[^a-zA-Z]|id_rsa|id_ed25519|\.key[^a-zA-Z]|\.pem)' -and
            $Command -match '\b(cat|head|tail|less|more|type|Get-Content|cp|mv|scp|rsync|grep|awk|sed)\b') {
            Deny "Bash read of sensitive-pattern file: $Command"
        }

        # Exfil verbs
        if ($Command -match '^\s*(curl|wget|nc|ssh|scp|rsync)\b') {
            Deny "exfil-class Bash command: $Command"
        }

        # Best-effort path-outside-boundary check
        if ($Command -match '\b(cat|head|tail|less|more|type|Get-Content|python|python3|node|ruby|perl)\b') {
            $tokens = $Command -split '\s+' | Where-Object { $_ -match '^(/|~/|[A-Z]:[/\\])' }
            foreach ($tok in $tokens) {
                $clean = $tok.Trim('"', "'")
                $expanded = $clean -replace '^~', $env:USERPROFILE
                try {
                    $abs = (Resolve-Path -LiteralPath $expanded -ErrorAction Stop).Path
                } catch {
                    $abs = $expanded
                }
                Test-SensitiveName $abs

                $insideProject = $abs.StartsWith($ProjectDir, [StringComparison]::OrdinalIgnoreCase)
                $allowedSystem = $abs -match '^(C:\\Windows\\Temp\\|C:\\Users\\[^\\]+\\AppData\\Local\\Temp\\)' -or
                                 $abs -in @('NUL','CON','PRN')
                if (-not $insideProject -and -not $allowedSystem) {
                    Deny "Bash read outside project boundary: $tok (resolved: $abs)"
                }
            }
        }
    }
}

exit 0
