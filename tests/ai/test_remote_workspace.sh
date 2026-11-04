#!/usr/bin/env bash
# Remote workspace (Coder on Kubernetes), docs/remote-workspace.md: the flag, the signing key, the repository clones and
# the non-interactive init. With the flag unset nothing may change: gitconfig is byte-identical to the golden files taken
# before the feature, and the clone script renders to nothing. No network: git and gh are stubs.
. "$(dirname "$0")/lib.sh"

CLONE="$AI_ROOT/home/.chezmoiscripts/workspace/run_onchange_after_200-clone-repos.sh.tmpl"
DATA="$AI_ROOT/home/.chezmoidata/remote-workspace.yaml"
DEFAULT_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHhoXNF9/VXWVZiH92yUIXTYOLNe1zaKiD/Yuyh3vgIn"

# 1. flag unset: gitconfig byte-identical to the golden files
for f in legacy-devcontainer legacy-linux core-linux; do
    out=$(render "$f" home/dot_gitconfig.tmpl) || _fail "render gitconfig with $f"
    assert_eq "gitconfig unchanged with the flag unset ($f)" "$out" "$(cat "$GOLDEN/gitconfig.$f")"
done

# 2. flag set: the workspace key replaces the owner's key; no key set keeps the owner's key; never both
out=$(render remote-workspace-linux home/dot_gitconfig.tmpl) || _fail "render gitconfig, flag set"
assert_contains "workspace signing key used" "$out" "signingkey = ssh-ed25519 AAAATESTKEY"
assert_not_contains "owner's key absent when the workspace key is set" "$out" "$DEFAULT_KEY"
assert_eq "exactly one signingkey line" "$(printf '%s\n' "$out" | grep -c signingkey)" "1"
out=$(render remote-workspace-emptykey-linux home/dot_gitconfig.tmpl) || _fail "render gitconfig, flag set, empty key"
assert_contains "empty workspace key: the default key stays" "$out" "signingkey = $DEFAULT_KEY"
# the key committed in the data file is used when nothing overrides it
DATA_KEY=$(sed -n 's/^  signing_key: "\(.*\)"$/\1/p' "$DATA")
out=$(render remote-workspace-nokey-linux home/dot_gitconfig.tmpl) || _fail "render gitconfig, flag set, data-file key"
if [ -n "$DATA_KEY" ]; then
    assert_contains "data-file workspace key used" "$out" "signingkey = $DATA_KEY"
    assert_not_contains "owner's key absent with the data-file key" "$out" "$DEFAULT_KEY"
    case "$DATA_KEY" in "ssh-"*) ;; *) _fail "the workspace signing key is not an SSH public key line";; esac
    case "$DATA_KEY" in *PRIVATE*) _fail "a private key in the data file";; esac
fi

# 3. the clone script: nothing without the flag, one clone per listed repository with it
out=$(render legacy-devcontainer "${CLONE#"$AI_ROOT"/}") || _fail "render clone script, flag unset"
[ -z "$(printf '%s' "$out" | tr -d '[:space:]')" ] || _fail "clone script must render to nothing with the flag unset"
out=$(render remote-workspace-linux "${CLONE#"$AI_ROOT"/}") || _fail "render clone script, flag set"
n=$(grep -cE '^    - ' "$DATA" || true)
assert_eq "one clone call per repository" "$(printf '%s\n' "$out" | grep -c '^clone_missing ')" "$n"
assert_contains "script root" "$out" 'root="/workspaces"'
[ "$n" -ge 1 ] || _fail "the repository list is empty"

# 4. run the rendered script against stubs: clones missing, skips existing, reports a failure and carries on
T=$(new_tmp)
mkdir -p "$T/bin" "$T/root"
cat > "$T/bin/gh" <<'STUB'
#!/usr/bin/env bash
# gh repo clone <repo> <dest> -- --quiet
[ "$1 $2" = "repo clone" ] || exit 2
echo "gh $3" >> "$STUB_LOG"
case "$3" in */fails-in-gh) exit 1;; esac
mkdir -p "$4"
STUB
cat > "$T/bin/git" <<'STUB'
#!/usr/bin/env bash
echo "git $*" >> "$STUB_LOG"
exit 1
STUB
chmod +x "$T/bin/gh" "$T/bin/git"
out=$(render remote-workspace-linux "${CLONE#"$AI_ROOT"/}")
printf '%s\n' "$out" | sed "s|^root=.*|root=\"$T/root\"|" > "$T/clone.sh"
mkdir -p "$T/root/claude-plugins"                      # already there: must be left alone
printf 'keep' > "$T/root/claude-plugins/marker"
# add a clone that fails in gh and then in git, before the final `exit 0` (portable: no sed -i, no \n in a replacement)
grep -v '^exit 0$' "$T/clone.sh" > "$T/clone2.sh"
printf 'clone_missing "someone/fails-in-gh"\nexit 0\n' >> "$T/clone2.sh"
mv "$T/clone2.sh" "$T/clone.sh"
grep -q 'fails-in-gh' "$T/clone.sh" || _fail "test setup: the failing clone was not added"
export STUB_LOG="$T/log"; : > "$STUB_LOG"
res=$(PATH="$T/bin:$PATH" bash "$T/clone.sh" 2>&1); rc=$?
assert_eq "script exits 0 even with a failed clone" "$rc" "0"
[ -d "$T/root/home-ops" ] || _fail "home-ops was not cloned"
assert_eq "existing directory untouched" "$(cat "$T/root/claude-plugins/marker")" "keep"
assert_contains "existing directory reported" "$res" "claude-plugins exists, skipped"
assert_contains "failure reported" "$res" "FAILED to clone someone/fails-in-gh"
[ ! -e "$T/root/fails-in-gh" ] || _fail "a failed clone left a directory behind"
assert_contains "git fallback was tried" "$(cat "$STUB_LOG")" "git clone --quiet https://github.com/someone/fails-in-gh.git"

# 5. init without a TTY: the flag follows the environment, no prompt is needed, nothing else changes
BEFORE=$(git -C "$AI_ROOT" status --porcelain 2>/dev/null | sha256sum)
SRC="$T/src"; mkdir -p "$SRC"
rsync -a --exclude .git --exclude .worktrees "$AI_ROOT/" "$SRC/"
init_cfg() { # cfg [env assignments...]
    local cfg=$1; shift
    env -u CODER -u REMOTE_WORKSPACE "$@" timeout 30 chezmoi init --source "$SRC" --config "$cfg" --destination "$T/dest" \
        --cache "$T/cache" --persistent-state "$T/state.boltdb" --promptDefaults </dev/null
}
flag_of() { grep -E '^[[:space:]]*is_remote_workspace[[:space:]]*=' "$1" | sed 's/.*= *//'; }
init_cfg "$T/a.toml" || _fail "init without the flag"
assert_eq "init: flag false by default" "$(flag_of "$T/a.toml")" "false"
init_cfg "$T/b.toml" CODER=true || _fail "init with CODER=true"
assert_eq "init: CODER=true sets the flag" "$(flag_of "$T/b.toml")" "true"
init_cfg "$T/c.toml" REMOTE_WORKSPACE=1 || _fail "init with REMOTE_WORKSPACE"
assert_eq "init: REMOTE_WORKSPACE sets the flag" "$(flag_of "$T/c.toml")" "true"
init_cfg "$T/d.toml" CODER=false || _fail "init with CODER=false"
assert_eq "init: CODER=false leaves the flag off" "$(flag_of "$T/d.toml")" "false"
assert_eq "init: the AI defaults are unchanged by the flag" \
    "$(grep -E 'ai_profile' "$T/b.toml")" "$(grep -E 'ai_profile' "$T/a.toml")"
assert_eq "init did not touch the repository" "$(git -C "$AI_ROOT" status --porcelain 2>/dev/null | sha256sum)" "$BEFORE"

# 6. the clone script does not depend on a devcontainer: no environment's ignore patterns hide the workspace/ scripts
# (the script itself renders to nothing unless the flag is set, so it needs no ignore rule)
RENDER="$AI_ROOT/tests/ai/render_ignore.sh"
for e in "linux false" "linux true" "darwin false" "windows false"; do
    # shellcheck disable=SC2086  # intentional word splitting: "<os> <is_devcontainer>"
    pats=$("$RENDER" $e) || _fail "render_ignore $e failed"
    assert_not_contains "workspace scripts not ignored ($e)" "$pats" ".chezmoiscripts/workspace"
done

# 7. peon-ping (sound packs for an audio relay on the owner's host) is skipped in a remote workspace, and only there
PEON=".chezmoiscripts/devcontainer/000-peon-ping.sh"
pats=$("$RENDER" linux true true) || _fail "render_ignore linux true true failed"
assert_contains "workspace: peon-ping ignored" "$pats" "$PEON"
pats=$("$RENDER" linux true false) || _fail "render_ignore linux true false failed"
assert_not_contains "devcontainer without the flag: peon-ping runs" "$pats" "$PEON"
pats=$("$RENDER" linux true) || _fail "render_ignore linux true (default flag) failed"
assert_not_contains "default flag is false: peon-ping runs" "$pats" "$PEON"
if [ "$(uname -s)" = Linux ]; then
    # real chezmoi on a copy of the tree (.chezmoi.os is the real one): which scripts are managed
    SRC2="$T/src2"; mkdir -p "$SRC2"
    cp "$AI_ROOT/.chezmoiroot" "$SRC2/"; cp -R "$AI_ROOT/home" "$SRC2/home"
    managed() { # fixture-toml
        chezmoi managed --include=scripts --source "$SRC2" --config "$1" --destination "$T/dest2" \
            --persistent-state "$T/state2.boltdb" --cache "$T/cache2" </dev/null
    }
    out=$(managed "$FIXTURES/legacy-devcontainer.toml") || _fail "chezmoi managed failed (devcontainer)"
    assert_contains "devcontainer: peon-ping is managed" "$out" "$PEON"
    out=$(managed "$FIXTURES/remote-workspace-linux.toml") || _fail "chezmoi managed failed (workspace)"
    assert_not_contains "workspace: peon-ping is not managed" "$out" "$PEON"
    assert_contains "workspace: the clone script is managed" "$out" ".chezmoiscripts/workspace/200-clone-repos.sh"
else
    echo "  SKIP real chezmoi managed (host is not Linux; the render matrix above is the check)"
fi

echo "  remote workspace: flag, signing key, clones and non-interactive init OK"
