#!/usr/bin/env bash
# Common CLI stub. Usage: _stub.sh <cli-name> <args...>
# Logs every call to $AI_TEST_LOG. STUB_FAIL="<word> ..." makes any call whose
# arguments contain one of the words exit 1. `plugin list` prints $STUB_STATE.
name=$1; shift
echo "$name $*" >> "${AI_TEST_LOG:-/dev/null}"
for w in ${STUB_FAIL:-}; do
    case " $* " in *" $w "*) echo "stub $name: forced failure ($w)" >&2; exit 1;; esac
done
case "$1 $2" in
    "plugin list") if [ -n "${STUB_STATE:-}" ] && [ -f "$STUB_STATE" ]; then cat "$STUB_STATE"; else echo "[]"; fi;;
    "marketplace list") if [ -n "${STUB_MARKETPLACES:-}" ] && [ -f "$STUB_MARKETPLACES" ]; then cat "$STUB_MARKETPLACES"; else echo "[]"; fi;;
esac
case "$1 $2 $3" in
    "plugin marketplace list") if [ -n "${STUB_MARKETPLACES:-}" ] && [ -f "$STUB_MARKETPLACES" ]; then cat "$STUB_MARKETPLACES"; else echo "[]"; fi;;
esac
exit 0
