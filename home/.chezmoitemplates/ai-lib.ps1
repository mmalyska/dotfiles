# Shared helpers for the AI workflow installers on Windows (PowerShell 5.1 and 7 compatible).
# PowerShell counterpart of ai-lib.sh, included by the installer templates via the chezmoi template action.
# Must not contain template delimiters. Reads no chezmoi data and touches no files until Write-AiStatus.
# Callers may set $script:AiAcceptedSha before Invoke-AiSummary; it is only recorded in the status file.
$script:AiFails = 0
$script:AiSkipped = $false
$script:AiAcceptedSha = ''

# Write-AiLog <INFO|SKIP|WARN|DONE> <message>  (information stream, so the output is capturable with *>&1)
function Write-AiLog {
    param([string]$Level, [string]$Message)
    if ($Level -eq 'SKIP') { $script:AiSkipped = $true }
    Write-Host "[ai-workflow] $Level $Message"
}

function Test-AiCommand {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# Invoke-AiSoft <description> { command }: a failing command (exception or non-zero exit code) is a WARN, never an error.
function Invoke-AiSoft {
    param([string]$Description, [scriptblock]$Command)
    $ok = $true
    try {
        $global:LASTEXITCODE = 0
        & $Command | Out-Host
        if ($global:LASTEXITCODE -ne 0) { $ok = $false }
    } catch {
        $ok = $false
    }
    if (-not $ok) {
        Write-AiLog 'WARN' "$Description failed"
        $script:AiFails++
    }
}

# Get-AiJsonItems <command output> <wrapper property>: the array in the output, or in its wrapper property. Empty when unusable.
function Get-AiJsonItems {
    param($Output, [string]$Property)
    try {
        $data = ($Output | Out-String) | ConvertFrom-Json
    } catch {
        return @()
    }
    if ($null -eq $data) { return @() }
    if ($data.PSObject.Properties.Name -contains $Property) { return @($data.$Property) }
    return @($data)
}

# Get-AiMarketplaceHead <dir>: HEAD commit of a marketplace checkout, empty when unavailable.
function Get-AiMarketplaceHead {
    param([string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir)) { return '' }
    if (-not (Test-AiCommand 'git')) { return '' }
    try {
        $head = & git -C $Dir rev-parse HEAD 2>$null
        if ($global:LASTEXITCODE -ne 0) { return '' }
        return ([string]$head).Trim()
    } catch {
        return ''
    }
}

# Write-AiStatus <harness> <ok|partial|skipped> <fails>
function Write-AiStatus {
    param([string]$Harness, [string]$Result, [int]$Fails)
    $base = $env:XDG_STATE_HOME
    if (-not $base) { $base = Join-Path $HOME '.local/state' }
    $dir = Join-Path $base 'ai-workflow'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $tmp = Join-Path $dir ".$Harness.status.$PID"
    $time = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $text = "result=$Result`nfails=$Fails`naccepted_sha=$($script:AiAcceptedSha)`ntime=$time`n"
    [System.IO.File]::WriteAllText($tmp, $text, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination (Join-Path $dir "$Harness.status") -Force
}

# Invoke-AiSummary <harness>: last step of every installer; never fails the apply.
function Invoke-AiSummary {
    param([string]$Harness)
    $result = 'ok'
    if ($script:AiFails -gt 0) {
        $result = 'partial'
    } elseif ($script:AiSkipped) {
        $result = 'skipped'
    }
    Write-AiLog 'DONE' "$Harness fails=$($script:AiFails)"
    try {
        Write-AiStatus $Harness $result $script:AiFails
    } catch {
        Write-AiLog 'WARN' "could not write status for $Harness"
    }
}
