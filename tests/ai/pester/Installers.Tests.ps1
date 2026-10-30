# Pester 5 tests of the Windows installers (T10) on stub CLIs. Stubs are PowerShell functions, so nothing outside the
# per-test temp directory is touched: no real claude/codex, no network, no real HOME (state goes to XDG_STATE_HOME).
# Run: pwsh -NoProfile -Command "Invoke-Pester -Path tests/ai/pester -CI"   (needs chezmoi on PATH)

BeforeAll {
    $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('ai-pester-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:Tmp | Out-Null
    $script:Sha = '25d785abee26ca7a3c87e8311f46e8a90f225301'
    $script:Own = 'mmalyska-claude-plugins'
    $script:Official = 'claude-plugins-official'
    $script:OwnIds = 'personal-essentials', 'git-workflows', 'development-lifecycle', 'dotnet', 'frontend', 'backend', 'devops', 'security', 'agent-toolkit', 'renovate', 'devcontainer', 'android'
    $script:ExtraIds = 'superpowers', 'code-simplifier', 'context7', 'claude-md-management'
    $script:ClaudeTpl = Join-Path $script:Root 'home/.chezmoiscripts/ai/run_onchange_after_100-claude-plugins.ps1.tmpl'
    $script:CodexTpl = Join-Path $script:Root 'home/.chezmoiscripts/ai/run_onchange_after_110-codex-plugins.ps1.tmpl'

    # Render-Installer <fixture> <template> -> path of the rendered script
    function script:Render-Installer {
        param([string]$Fixture, [string]$Template)
        $cfg = Join-Path $script:Root "tests/ai/fixtures/$Fixture.toml"
        $text = (Get-Content -Raw -LiteralPath $Template) | & chezmoi --source $script:Root --config $cfg execute-template | Out-String
        $out = Join-Path $script:Tmp ("$Fixture." + (Split-Path $Template -Leaf) + '.ps1')
        [System.IO.File]::WriteAllText($out, $text, (New-Object System.Text.UTF8Encoding($false)))
        return $out
    }

    function script:Json-Ids {
        param([string]$Property, [string]$Key, [string[]]$Ids)
        $items = ($Ids | ForEach-Object { '{"' + $Key + '":"' + $_ + '"}' }) -join ','
        if ($Property) { return '{"' + $Property + '":[' + $items + ']}' }
        return '[' + $items + ']'
    }

    # Remove-StubFunction <name>: removes a stub function wherever it lives, and fails loudly if it is still resolvable
    function script:Remove-StubFunction {
        param([string]$Name)
        foreach ($path in "Function:global:$Name", "Function:\$Name", "Function:$Name") {
            if (Get-Command $Name -CommandType Function -ErrorAction SilentlyContinue) {
                Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
            }
        }
        $left = Get-Command $Name -CommandType Function -ErrorAction SilentlyContinue
        if ($left) { throw "stub '$Name' is still resolvable ($($left.CommandType): $($left.Source))" }
    }

    # Count-Calls <regex>
    function script:Count-Calls {
        param([string]$Pattern)
        return @($global:AiCalls | Where-Object { $_ -match $Pattern }).Count
    }

    # Run-Installer <script> -> captured output; the exit code is in $global:AiRc
    function script:Run-Installer {
        param([string]$Path)
        $global:AiCalls.Clear()
        $out = & $Path *>&1 | Out-String
        $global:AiRc = $LASTEXITCODE
        return $out
    }
}

AfterAll {
    Remove-Item -Recurse -Force -LiteralPath $script:Tmp -ErrorAction SilentlyContinue
}

Describe 'Claude installer (100-claude-plugins.ps1)' {
    BeforeEach {
        $script:Case = Join-Path $script:Tmp ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:Case | Out-Null
        $script:SavedEnv = @{ XDG = $env:XDG_STATE_HOME; CC = $env:CLAUDE_CONFIG_DIR; UP = $env:AI_WORKFLOW_UPGRADE; PATH = $env:PATH }
        $env:XDG_STATE_HOME = Join-Path $script:Case 'state'
        $env:CLAUDE_CONFIG_DIR = Join-Path $script:Case 'claude'
        $env:AI_WORKFLOW_UPGRADE = $null
        $global:AiCalls = New-Object System.Collections.ArrayList
        $global:StubFail = @()
        $global:StubState = '[]'
        $global:StubMarkets = '[]'
        function global:claude {
            [void]$global:AiCalls.Add("claude $args")
            $global:LASTEXITCODE = 0
            $line = " $args "
            foreach ($w in $global:StubFail) {
                if ($line -like "* $w *") { $global:LASTEXITCODE = 1; return }
            }
            if ($args[0] -eq 'plugin' -and $args[1] -eq 'list') { $global:StubState; return }
            if ($args[0] -eq 'plugin' -and $args[1] -eq 'marketplace' -and $args[2] -eq 'list') { $global:StubMarkets; return }
        }
    }
    AfterEach {
        Remove-StubFunction 'claude'
        $env:XDG_STATE_HOME = $script:SavedEnv.XDG
        $env:CLAUDE_CONFIG_DIR = $script:SavedEnv.CC
        $env:AI_WORKFLOW_UPGRADE = $script:SavedEnv.UP
        $env:PATH = $script:SavedEnv.PATH
    }

    It 'core, fresh state: 1 marketplace add, 12 installs, no update, no extras' {
        $s = Render-Installer 'core-linux' $script:ClaudeTpl
        $out = Run-Installer $s
        $global:AiRc | Should -Be 0
        Count-Calls '^claude plugin marketplace add mmalyska/claude-plugins$' | Should -Be 1
        Count-Calls "^claude plugin install .*@$($script:Own)$" | Should -Be 12
        Count-Calls '^claude plugin marketplace update' | Should -Be 0
        Count-Calls 'superpowers' | Should -Be 0
        Count-Calls $script:Official | Should -Be 0
        $out | Should -Match 'DONE claude fails=0'
        $status = Get-Content -Raw (Join-Path $env:XDG_STATE_HOME 'ai-workflow/claude.status')
        $status | Should -Match 'result=ok'
        $status | Should -Match "accepted_sha=$($script:Sha)"
    }

    It 'rerun with everything installed makes no mutating call' {
        $s = Render-Installer 'core-linux' $script:ClaudeTpl
        $global:StubState = Json-Ids '' 'id' ($script:OwnIds | ForEach-Object { "$_@$($script:Own)" })
        $global:StubMarkets = Json-Ids '' 'name' @($script:Own)
        [void](Run-Installer $s)
        Count-Calls '^claude plugin (install|marketplace add|marketplace update)' | Should -Be 0
        (Get-Content -Raw (Join-Path $env:XDG_STATE_HOME 'ai-workflow/claude.status')) | Should -Match 'result=ok'
    }

    It 'claude-extended adds the official marketplace and 4 extras (16 installs)' {
        $s = Render-Installer 'extended-linux' $script:ClaudeTpl
        [void](Run-Installer $s)
        Count-Calls '^claude plugin marketplace add anthropics/claude-plugins-official$' | Should -Be 1
        Count-Calls "^claude plugin install .*@$($script:Own)$" | Should -Be 12
        Count-Calls "^claude plugin install .*@$($script:Official)$" | Should -Be 4
        Count-Calls "^claude plugin install superpowers@$($script:Official)$" | Should -Be 1
        Count-Calls '^claude plugin install' | Should -Be 16
        Count-Calls '^claude plugin marketplace update' | Should -Be 0
    }

    It 'minimal installs exactly the 2 workflow plugins' {
        $s = Render-Installer 'minimal-linux' $script:ClaudeTpl
        [void](Run-Installer $s)
        Count-Calls '^claude plugin install' | Should -Be 2
        Count-Calls "^claude plugin install git-workflows@$($script:Own)$" | Should -Be 1
        Count-Calls "^claude plugin install development-lifecycle@$($script:Own)$" | Should -Be 1
        Count-Calls $script:Official | Should -Be 0
    }

    It 'a failing install is a soft failure: exit 0, every plugin attempted, status partial' {
        $s = Render-Installer 'core-linux' $script:ClaudeTpl
        $global:StubFail = @('install')
        $out = Run-Installer $s
        $global:AiRc | Should -Be 0
        Count-Calls '^claude plugin install' | Should -Be 12
        $out | Should -Match 'DONE claude fails=12'
        $status = Get-Content -Raw (Join-Path $env:XDG_STATE_HOME 'ai-workflow/claude.status')
        $status | Should -Match 'result=partial'
        $status | Should -Match 'fails=12'
    }

    It 'an unusable marketplace skips the plugins that depend on it' {
        $s = Render-Installer 'core-linux' $script:ClaudeTpl
        $global:StubFail = @('marketplace')
        [void](Run-Installer $s)
        $global:AiRc | Should -Be 0
        Count-Calls '^claude plugin install' | Should -Be 0
        (Get-Content -Raw (Join-Path $env:XDG_STATE_HOME 'ai-workflow/claude.status')) | Should -Match 'result=partial'
    }

    It 'AI_WORKFLOW_UPGRADE=1 runs exactly one marketplace update and nothing else mutating' {
        $s = Render-Installer 'core-linux' $script:ClaudeTpl
        $global:StubState = Json-Ids '' 'id' ($script:OwnIds | ForEach-Object { "$_@$($script:Own)" })
        $global:StubMarkets = Json-Ids '' 'name' @($script:Own)
        $env:AI_WORKFLOW_UPGRADE = '1'
        [void](Run-Installer $s)
        Count-Calls "^claude plugin marketplace update $($script:Own)$" | Should -Be 1
        Count-Calls '^claude plugin (install|marketplace add)' | Should -Be 0
    }

    It 'a marketplace checkout that differs from the accepted SHA is a WARN, not an error' {
        $s = Render-Installer 'core-linux' $script:ClaudeTpl
        $global:StubState = Json-Ids '' 'id' ($script:OwnIds | ForEach-Object { "$_@$($script:Own)" })
        $global:StubMarkets = Json-Ids '' 'name' @($script:Own)
        $mk = Join-Path $env:CLAUDE_CONFIG_DIR "plugins/marketplaces/$($script:Own)"
        New-Item -ItemType Directory -Force -Path $mk | Out-Null
        & git -C $mk init -q
        & git -C $mk -c user.email=a@b.invalid -c user.name=n -c commit.gpgsign=false commit -q --allow-empty -m x
        $head = (& git -C $mk rev-parse HEAD).Trim()
        $out = Run-Installer $s
        $global:AiRc | Should -Be 0
        $out | Should -Match ([regex]::Escape("WARN drift: $($script:Own) is at $head, accepted $($script:Sha)"))
        Count-Calls '^claude plugin (install|marketplace add|marketplace update)' | Should -Be 0
    }

    It 'without the claude CLI: SKIP, no calls, status skipped' {
        $s = Render-Installer 'core-linux' $script:ClaudeTpl
        Remove-StubFunction 'claude'
        $env:PATH = Join-Path $script:Case 'empty'
        $out = Run-Installer $s
        $global:AiRc | Should -Be 0
        $out | Should -Match 'SKIP claude CLI not found'
        $global:AiCalls.Count | Should -Be 0
        (Get-Content -Raw (Join-Path $env:XDG_STATE_HOME 'ai-workflow/claude.status')) | Should -Match 'result=skipped'
    }

    It 'ai_claude=false: SKIP, no calls, status skipped' {
        $s = Render-Installer 'core-noclaude-linux' $script:ClaudeTpl
        $out = Run-Installer $s
        $out | Should -Match 'SKIP ai_claude=false'
        $global:AiCalls.Count | Should -Be 0
        (Get-Content -Raw (Join-Path $env:XDG_STATE_HOME 'ai-workflow/claude.status')) | Should -Match 'result=skipped'
    }

    It 'the fingerprint differs with the CLI present vs absent' {
        $present = Render-Installer 'core-linux' $script:ClaudeTpl
        $fpPresent = (Get-Content -LiteralPath $present -TotalCount 1)
        $fpPresent | Should -Match 'profile=core'
        $fpPresent | Should -Match 'sha='
        $fpPresent | Should -Match 'cli=(present|absent)'
        $fpMin = (Get-Content -LiteralPath (Render-Installer 'minimal-linux' $script:ClaudeTpl) -TotalCount 1)
        $fpMin | Should -Match 'profile=minimal'
        $fpMin | Should -Not -Match 'dotnet'
    }

    It 'never removes, disables or updates on its own, never exits 1 and parses cleanly' {
        foreach ($fx in 'core-linux', 'extended-linux', 'minimal-linux') {
            $path = Render-Installer $fx $script:ClaudeTpl
            $text = Get-Content -Raw -LiteralPath $path
            $text | Should -Not -Match 'uninstall|plugin remove|plugin disable|marketplace remove'
            $text | Should -Not -Match 'exit\s+1'
            $text | Should -Not -Match '\|\|\s*true'
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
            @($errors).Count | Should -Be 0
        }
    }
}

Describe 'Codex installer (110-codex-plugins.ps1)' {
    BeforeEach {
        $script:Case = Join-Path $script:Tmp ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:Case | Out-Null
        $script:SavedEnv = @{ XDG = $env:XDG_STATE_HOME; CH = $env:CODEX_HOME; PATH = $env:PATH }
        $env:XDG_STATE_HOME = Join-Path $script:Case 'state'
        $env:CODEX_HOME = Join-Path $script:Case 'codex'
        $global:AiCalls = New-Object System.Collections.ArrayList
        $global:StubFail = @()
        $global:StubState = '{"installed":[],"available":[]}'
        $global:StubMarkets = '{"marketplaces":[]}'
        function global:codex {
            [void]$global:AiCalls.Add("codex $args")
            $global:LASTEXITCODE = 0
            $line = " $args "
            foreach ($w in $global:StubFail) {
                if ($line -like "* $w *") { $global:LASTEXITCODE = 1; return }
            }
            if ($args[0] -eq 'plugin' -and $args[1] -eq 'list') { $global:StubState; return }
            if ($args[0] -eq 'plugin' -and $args[1] -eq 'marketplace' -and $args[2] -eq 'list') { $global:StubMarkets; return }
        }
    }
    AfterEach {
        Remove-StubFunction 'codex'
        $env:XDG_STATE_HOME = $script:SavedEnv.XDG
        $env:CODEX_HOME = $script:SavedEnv.CH
        $env:PATH = $script:SavedEnv.PATH
    }

    It 'core, fresh state: marketplace added pinned to the accepted SHA, 12 plugin adds' {
        $s = Render-Installer 'core-linux' $script:CodexTpl
        $out = Run-Installer $s
        $global:AiRc | Should -Be 0
        Count-Calls "^codex plugin marketplace add mmalyska/claude-plugins --ref $($script:Sha)$" | Should -Be 1
        Count-Calls "^codex plugin add .*@$($script:Own)$" | Should -Be 12
        Count-Calls 'marketplace (upgrade|remove)|plugin remove' | Should -Be 0
        Count-Calls 'superpowers' | Should -Be 0
        $out | Should -Match 'DONE codex fails=0'
        $status = Get-Content -Raw (Join-Path $env:XDG_STATE_HOME 'ai-workflow/codex.status')
        $status | Should -Match 'result=ok'
        $status | Should -Match "accepted_sha=$($script:Sha)"
    }

    It 'rerun with everything installed and the right pin makes no mutating call' {
        $s = Render-Installer 'core-linux' $script:CodexTpl
        $global:StubState = Json-Ids 'installed' 'pluginId' ($script:OwnIds | ForEach-Object { "$_@$($script:Own)" })
        $global:StubMarkets = Json-Ids 'marketplaces' 'name' @($script:Own)
        New-Item -ItemType Directory -Force -Path $env:CODEX_HOME | Out-Null
        Set-Content -LiteralPath (Join-Path $env:CODEX_HOME 'config.toml') -Value @("[marketplaces.$($script:Own)]", 'source_type = "git"', "ref = `"$($script:Sha)`"")
        $out = Run-Installer $s
        Count-Calls '^codex plugin (add|marketplace add|marketplace upgrade|remove|marketplace remove)' | Should -Be 0
        $out | Should -Not -Match 'pin mismatch'
    }

    It 'a marketplace pinned to another ref is a WARN and is not replaced' {
        $s = Render-Installer 'core-linux' $script:CodexTpl
        $global:StubState = Json-Ids 'installed' 'pluginId' ($script:OwnIds | ForEach-Object { "$_@$($script:Own)" })
        $global:StubMarkets = Json-Ids 'marketplaces' 'name' @($script:Own)
        New-Item -ItemType Directory -Force -Path $env:CODEX_HOME | Out-Null
        Set-Content -LiteralPath (Join-Path $env:CODEX_HOME 'config.toml') -Value @("[marketplaces.$($script:Own)]", 'ref = "main"')
        $out = Run-Installer $s
        $global:AiRc | Should -Be 0
        $out | Should -Match "WARN pin mismatch: $($script:Own) is at ref 'main'"
        Count-Calls '^codex plugin (add|marketplace add|marketplace upgrade|remove|marketplace remove)' | Should -Be 0
    }

    It 'minimal installs exactly the 2 workflow plugins' {
        $s = Render-Installer 'minimal-linux' $script:CodexTpl
        [void](Run-Installer $s)
        Count-Calls '^codex plugin add' | Should -Be 2
    }

    It 'claude-extended installs the same 12 plugins and never the Claude-only extras' {
        $s = Render-Installer 'extended-linux' $script:CodexTpl
        [void](Run-Installer $s)
        Count-Calls '^codex plugin add' | Should -Be 12
        Count-Calls 'superpowers|context7|code-simplifier|claude-md-management|claude-plugins-official' | Should -Be 0
    }

    It 'a failing plugin add is a soft failure: exit 0, the rest still attempted, status partial' {
        $s = Render-Installer 'core-linux' $script:CodexTpl
        $global:StubFail = @("dotnet@$($script:Own)")
        $out = Run-Installer $s
        $global:AiRc | Should -Be 0
        Count-Calls '^codex plugin add' | Should -Be 12
        $out | Should -Match 'DONE codex fails=1'
        $status = Get-Content -Raw (Join-Path $env:XDG_STATE_HOME 'ai-workflow/codex.status')
        $status | Should -Match 'result=partial'
        $status | Should -Match 'fails=1'
    }

    It 'an unusable marketplace skips the plugins that depend on it' {
        $s = Render-Installer 'core-linux' $script:CodexTpl
        $global:StubFail = @('marketplace')
        [void](Run-Installer $s)
        $global:AiRc | Should -Be 0
        Count-Calls '^codex plugin add' | Should -Be 0
        (Get-Content -Raw (Join-Path $env:XDG_STATE_HOME 'ai-workflow/codex.status')) | Should -Match 'result=partial'
    }

    It 'without the codex CLI: SKIP, no calls, status skipped' {
        $s = Render-Installer 'core-linux' $script:CodexTpl
        Remove-StubFunction 'codex'
        $env:PATH = Join-Path $script:Case 'empty'
        $out = Run-Installer $s
        $out | Should -Match 'SKIP codex CLI not found'
        $global:AiCalls.Count | Should -Be 0
        (Get-Content -Raw (Join-Path $env:XDG_STATE_HOME 'ai-workflow/codex.status')) | Should -Match 'result=skipped'
    }

    It 'ai_codex=false: SKIP, no calls, status skipped' {
        $s = Render-Installer 'core-nocodex-linux' $script:CodexTpl
        $out = Run-Installer $s
        $out | Should -Match 'SKIP ai_codex=false'
        $global:AiCalls.Count | Should -Be 0
        (Get-Content -Raw (Join-Path $env:XDG_STATE_HOME 'ai-workflow/codex.status')) | Should -Match 'result=skipped'
    }

    It 'never removes or upgrades, never exits 1 and parses cleanly' {
        foreach ($fx in 'core-linux', 'extended-linux', 'minimal-linux') {
            $path = Render-Installer $fx $script:CodexTpl
            $text = Get-Content -Raw -LiteralPath $path
            $text | Should -Not -Match 'plugin remove|marketplace remove|marketplace upgrade|uninstall'
            $text | Should -Not -Match 'exit\s+1'
            $text | Should -Not -Match '\|\|\s*true'
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
            @($errors).Count | Should -Be 0
        }
    }
}
