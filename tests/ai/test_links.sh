#!/usr/bin/env bash
# Every relative markdown link in docs/**/*.md (and README.md) resolves to an existing path.
. "$(dirname "$0")/lib.sh"
cd "$AI_ROOT" || exit 1
python3 -I - <<'PY' || exit 1
import pathlib, re, sys
bad = []
for md in list(pathlib.Path("docs").rglob("*.md")):
    text = re.sub(r"```.*?```", "", md.read_text(encoding="utf-8"), flags=re.S)
    for target in re.findall(r"\]\(([^)\s]+)\)", text):
        if re.match(r"^[a-z]+:|^#", target):
            continue
        path = (md.parent / target.split("#")[0]).resolve()
        if not path.exists():
            bad.append(f"{md}: {target}")
if bad: print("\n".join(bad), file=sys.stderr)
sys.exit(1 if bad else 0)
PY
