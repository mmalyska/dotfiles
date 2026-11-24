#!/usr/bin/env bash
# Every action in .github/workflows is pinned to a full 40-char SHA with a version comment, every workflow has top-level
# permissions, and nothing uses @main or @master.
#
# One exception, on purpose: the owner's own reusable workflows, mmalyska/github-workflows/.github/workflows/<name>.yaml@main.
# That repository has no tags to pin to, and the other repositories (home-ops, claude-plugins) call it the same way, so a fix
# there reaches all of them. The exception is narrow: only a reusable workflow file of that one repository, only @main.
# Every other action, another owner's workflow, a composite action in that repository, or any other ref stays rejected.
. "$(dirname "$0")/lib.sh"
shopt -s nullglob

OWN_SHARED='mmalyska/github-workflows/\.github/workflows/[A-Za-z0-9._-]+\.ya?ml@main'

# own_shared <ref>: the ref (with an optional trailing comment) is one of the owner's reusable workflows at @main.
own_shared() { printf '%s\n' "$1" | grep -Eq "^${OWN_SHARED}( +#.*)?\$"; }

# check_dir <workflows dir>: prints each violation to stderr, returns 1 if there is one.
check_dir() {
    local dir=$1 bad=0 f line ref
    for f in "$dir"/*.yml "$dir"/*.yaml; do
        while IFS= read -r line; do
            ref=${line#*uses:}; ref=${ref# }
            case "$ref" in ./*) continue;; esac
            own_shared "$ref" && continue
            if ! printf '%s\n' "$ref" | grep -Eq '^[^@ ]+@[0-9a-f]{40} +# +v?[0-9][^ ]*'; then
                echo "  unpinned: $f: $line" >&2; bad=1
            fi
        done < <(grep -E '^\s*-?\s*uses:' "$f")
        # any other line that names @main or @master (a comment included) is still a violation
        if grep -E '@(main|master)\b' "$f" | grep -Evq "uses: +${OWN_SHARED}( +#.*)?\$"; then
            echo "  @main/@master in $f" >&2; bad=1
        fi
        grep -Eq '^permissions:' "$f" || { echo "  no top-level permissions in $f" >&2; bad=1; }
    done
    return "$bad"
}

# 1. the repository's own workflows
check_dir "$AI_ROOT/.github/workflows" || _fail "workflow pinning rules violated"

# 2. self-checks of the rule, on sample workflows
T=$(new_tmp)
mk() { # name uses-ref  -> $T/<name>/x.yml with top-level permissions and one job calling the ref
    mkdir -p "$T/$1"
    printf 'name: x\non: push\npermissions:\n  contents: read\njobs:\n  j:\n    uses: %s\n' "$2" > "$T/$1/x.yml"
}
expect_ok() { mk "$1" "$2"; check_dir "$T/$1" 2>/dev/null || _fail "rule rejects a valid ref: $2"; }
expect_bad() { mk "$1" "$2"; ! check_dir "$T/$1" 2>/dev/null || _fail "rule accepts an invalid ref: $2"; }

expect_ok pinned 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1'
expect_ok own 'mmalyska/github-workflows/.github/workflows/pr-triage-label.yaml@main'
expect_ok own-comment 'mmalyska/github-workflows/.github/workflows/pr-triage-label.yml@main # shared'
expect_bad bare-tag 'actions/checkout@v4'
expect_bad sha-no-comment 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'
expect_bad main 'actions/checkout@main'
expect_bad master 'actions/checkout@master'
expect_bad other-owner 'someone/github-workflows/.github/workflows/pr-triage-label.yaml@main'
expect_bad other-repo 'mmalyska/other-repo/.github/workflows/x.yaml@main'
expect_bad lookalike-repo 'mmalyska/github-workflows-evil/.github/workflows/x.yaml@main'
expect_bad composite-action 'mmalyska/github-workflows/actions/setup@main'
expect_bad own-not-main 'mmalyska/github-workflows/.github/workflows/pr-triage-label.yaml@v1'
expect_bad traversal 'mmalyska/github-workflows/.github/workflows/../../x.yaml@main'

# a workflow without top-level permissions fails even when every ref is fine
mkdir -p "$T/noperm"
printf 'name: x\non: push\njobs:\n  j:\n    uses: mmalyska/github-workflows/.github/workflows/pr-triage-label.yaml@main\n' > "$T/noperm/x.yml"
! check_dir "$T/noperm" 2>/dev/null || _fail "rule accepts a workflow without top-level permissions"

# @main hidden in another line of a workflow that also calls the own shared workflow is still a violation
mkdir -p "$T/mixed"
printf 'name: x\non: push\npermissions:\n  contents: read\njobs:\n  j:\n    uses: mmalyska/github-workflows/.github/workflows/pr-triage-label.yaml@main\n  k:\n    steps:\n      - uses: actions/checkout@main\n' > "$T/mixed/x.yml"
! check_dir "$T/mixed" 2>/dev/null || _fail "rule accepts a second, unpinned action next to the exception"
exit 0
