#!/usr/bin/env bash
# T10: PowerShell installers. Runs the Pester suite (tests/ai/pester), which renders both .ps1.tmpl, parse-checks them and
# exercises them on function stubs. Needs pwsh with Pester 5 and chezmoi on PATH.
# Without pwsh the test reports NOT RUN, unless AI_REQUIRE_PWSH=1 (set in CI), where a missing pwsh is a FAIL.
. "$(dirname "$0")/lib.sh"

if ! command -v pwsh >/dev/null 2>&1; then
    [ "${AI_REQUIRE_PWSH:-}" != 1 ] || _fail "AI_REQUIRE_PWSH=1 but pwsh is not installed"
    echo "  NOT RUN pwsh parse-check and Pester (pwsh not installed)"
    exit 0
fi

# relative path + cwd at the repo root: works for native Windows pwsh called from Git Bash too
cd "$AI_ROOT" || _fail "cannot cd to $AI_ROOT"
# shellcheck disable=SC2016  # the PowerShell script is meant to be literal
pwsh -NoProfile -NonInteractive -Command '
    Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
    $r = Invoke-Pester -Path tests/ai/pester -PassThru -Output Detailed
    if ($r.TotalCount -eq 0 -or $r.FailedCount -gt 0 -or $r.FailedBlocksCount -gt 0 -or $r.FailedContainersCount -gt 0) { exit 1 }
' || _fail "Pester failed"
