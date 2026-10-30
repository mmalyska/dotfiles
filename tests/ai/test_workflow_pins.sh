#!/usr/bin/env bash
# Every action in .github/workflows is pinned to a full 40-char SHA with a version comment.
. "$(dirname "$0")/lib.sh"
shopt -s nullglob
bad=0
for f in "$AI_ROOT"/.github/workflows/*.yml "$AI_ROOT"/.github/workflows/*.yaml; do
    while IFS= read -r line; do
        ref=${line#*uses:}; ref=${ref# }
        case "$ref" in ./*) continue;; esac
        if ! printf '%s\n' "$ref" | grep -Eq '^[^@ ]+@[0-9a-f]{40} +# +v?[0-9][^ ]*'; then
            echo "  unpinned: $f: $line" >&2; bad=1
        fi
    done < <(grep -E '^\s*-?\s*uses:' "$f")
    ! grep -Eq '@(main|master)\b' "$f" || { echo "  @main/@master in $f" >&2; bad=1; }
    grep -Eq '^permissions:' "$f" || { echo "  no top-level permissions in $f" >&2; bad=1; }
done
[ "$bad" = 0 ] || _fail "workflow pinning rules violated"
# self-check: the rule rejects a bare tag
printf '%s\n' 'uses: actions/checkout@v4' | grep -Eq '^[^@ ]+@[0-9a-f]{40} ' && _fail "pin regex too lax"
exit 0
