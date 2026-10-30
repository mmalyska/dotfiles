#!/usr/bin/env bash
# run.sh contract: exit 77 means NOT RUN only for native e2e-*.sh; for deterministic test_*.sh any non-zero exit is FAIL.
. "$(dirname "$0")/lib.sh"
T=$(new_tmp)
mkdir -p "$T/tests/ai"
cp "$AI_ROOT/tests/ai/run.sh" "$T/tests/ai/run.sh"
printf '#!/usr/bin/env bash\nexit 77\n' > "$T/tests/ai/test_exit77.sh"
printf '#!/usr/bin/env bash\nexit 77\n' > "$T/tests/ai/e2e-exit77.sh"

# deterministic test exiting 77 -> FAIL, overall non-zero
OUT=$(AI_NATIVE_TESTS=1 bash "$T/tests/ai/run.sh" 2>&1); RC=$?
assert_contains "test_ 77 is FAIL" "$OUT" "FAIL test_exit77"
assert_not_contains "test_ 77 not NOT RUN" "$OUT" "NOT RUN test_exit77"
[ "$RC" != 0 ] || _fail "runner exited 0 although a deterministic test exited 77"
# native test exiting 77 -> NOT RUN (opt-in on), and does not fail the run on its own
assert_contains "e2e 77 is NOT RUN" "$OUT" "NOT RUN e2e-exit77"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/tests/ai/test_ok.sh"
rm "$T/tests/ai/test_exit77.sh"
OUT=$(AI_NATIVE_TESTS=1 bash "$T/tests/ai/run.sh" 2>&1); RC=$?
assert_contains "e2e 77 NOT RUN alone" "$OUT" "NOT RUN e2e-exit77"
assert_eq "e2e 77 alone rc" "$RC" "0"
# a native test failing with another code is FAIL
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/tests/ai/e2e-exit77.sh"
OUT=$(AI_NATIVE_TESTS=1 bash "$T/tests/ai/run.sh" 2>&1); RC=$?
assert_contains "e2e 1 is FAIL" "$OUT" "FAIL e2e-exit77"
[ "$RC" != 0 ] || _fail "runner exited 0 although a native test failed"
