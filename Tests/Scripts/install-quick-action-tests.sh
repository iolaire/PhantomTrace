#!/bin/bash
# Shell-level tests for Scripts/install-quick-action.sh (task 16.3; Requirements 12.9, 12.11).
#
#   Tests/Scripts/install-quick-action-tests.sh
#
# Every case runs with HOME pointing at a fresh temporary directory and with
# PHANTOMTRACE_SKIP_PBS_FLUSH=1, so the real ~/Library/Services and the real
# Services cache are never touched. Exits 0 when every case passes.
#
# Not covered: rollback after a failed `pbs -flush`, because the script hardcodes the
# pbs path and the test must not run the real one.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)" || exit 2
SCRIPT="$ROOT/Scripts/install-quick-action.sh"
PACKAGED="$ROOT/Packaging/QuickAction/Why Can't I Eject?.workflow"
NAME="Why Can't I Eject?.workflow"

[ -x "$SCRIPT" ] || [ -f "$SCRIPT" ] || { echo "missing $SCRIPT" >&2; exit 2; }
[ -d "$PACKAGED" ] || { echo "missing $PACKAGED" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pt-install-tests.XXXXXX")" || exit 2
REAL_HOME="${HOME:-}"
cleanup() {
  chmod -R u+rwX "$WORK" 2>/dev/null
  rm -rf -- "$WORK"
}
trap cleanup EXIT

# Fingerprint of the real Services folder, to prove it is untouched.
real_fingerprint() {
  if [ -n "$REAL_HOME" ] && [ -d "$REAL_HOME/Library/Services" ]; then
    ls -laR "$REAL_HOME/Library/Services" 2>/dev/null | cksum
  else
    echo "absent"
  fi
}
REAL_BEFORE="$(real_fingerprint)"

PASS=0
FAIL=0
CASE=0
STDERR_FILE=""
STATUS=0

pass() { PASS=$((PASS + 1)); echo "ok   - $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL - $1"; }
check() { # description, command...
  local description="$1"
  shift
  if "$@"; then pass "$description"; else fail "$description"; fi
}

new_home() {
  CASE=$((CASE + 1))
  local home="$WORK/case$CASE/home"
  mkdir -p "$home"
  NEW_HOME="$home" # set a global: calling this in $(...) would lose the CASE increment
}

# run_install <home> [extra env assignments...]; sets STATUS and STDERR_FILE.
run_install() {
  local home="$1"
  shift
  STDERR_FILE="$WORK/case$CASE/stderr"
  env HOME="$home" PHANTOMTRACE_SKIP_PBS_FLUSH=1 "$@" /bin/bash "$SCRIPT" \
    >"$WORK/case$CASE/stdout" 2>"$STDERR_FILE"
  STATUS=$?
}

make_previous() { # home -> creates a recognizable previously installed copy
  local dest="$1/Library/Services/$NAME"
  mkdir -p "$dest/Contents"
  echo "previous-plist" >"$dest/Contents/Info.plist"
  echo "previous-wflow" >"$dest/Contents/document.wflow"
}

previous_intact() { # home
  local dest="$1/Library/Services/$NAME"
  [ "$(cat "$dest/Contents/Info.plist" 2>/dev/null)" = "previous-plist" ] &&
    [ "$(cat "$dest/Contents/document.wflow" 2>/dev/null)" = "previous-wflow" ]
}

no_staging_left() { # home
  ! ls -A "$1/Library/Services" 2>/dev/null | grep -q '^\.phantomtrace-install\.'
}

stderr_nonempty() { [ -s "$STDERR_FILE" ]; }
status_zero() { [ "$STATUS" -eq 0 ]; }
status_nonzero() { [ "$STATUS" -ne 0 ]; }

make_source() { # dir -> valid minimal workflow
  mkdir -p "$1/Contents"
  echo "new-plist" >"$1/Contents/Info.plist"
  echo "new-wflow" >"$1/Contents/document.wflow"
}

# 1. Success on a clean home installs the packaged workflow.
new_home
H="$NEW_HOME"
run_install "$H"
check "fresh install exits 0" status_zero
check "fresh install copies the packaged workflow" \
  diff -r "$PACKAGED" "$H/Library/Services/$NAME" >/dev/null
check "fresh install leaves no staging directory" no_staging_left "$H"

# 2. Success over an existing copy replaces it.
new_home
H="$NEW_HOME"
make_previous "$H"
SRC="$WORK/case$CASE/src.workflow"
make_source "$SRC"
run_install "$H" PHANTOMTRACE_QUICK_ACTION_SOURCE="$SRC"
check "reinstall exits 0" status_zero
check "reinstall replaces the previous copy" \
  diff -r "$SRC" "$H/Library/Services/$NAME" >/dev/null
check "reinstall leaves no staging directory" no_staging_left "$H"

# 3. Missing source bundle: non-zero, message on stderr, previous copy intact.
new_home
H="$NEW_HOME"
make_previous "$H"
run_install "$H" PHANTOMTRACE_QUICK_ACTION_SOURCE="$WORK/case$CASE/does-not-exist.workflow"
check "missing source exits non-zero" status_nonzero
check "missing source prints the cause to stderr" stderr_nonempty
check "missing source leaves the previous copy intact" previous_intact "$H"

# 4. Source without Contents/document.wflow: same guarantees.
new_home
H="$NEW_HOME"
make_previous "$H"
SRC="$WORK/case$CASE/incomplete.workflow"
mkdir -p "$SRC/Contents"
echo "x" >"$SRC/Contents/Info.plist"
run_install "$H" PHANTOMTRACE_QUICK_ACTION_SOURCE="$SRC"
check "incomplete source exits non-zero" status_nonzero
check "incomplete source prints the cause to stderr" stderr_nonempty
check "incomplete source leaves the previous copy intact" previous_intact "$H"

# 5. Copy failure (unreadable file in the source): previous copy intact, no staging left.
new_home
H="$NEW_HOME"
make_previous "$H"
SRC="$WORK/case$CASE/unreadable.workflow"
make_source "$SRC"
chmod 000 "$SRC/Contents/document.wflow"
if [ "$(id -u)" -eq 0 ]; then
  echo "skip - unreadable-source case (running as root, permissions are not enforced)"
else
  run_install "$H" PHANTOMTRACE_QUICK_ACTION_SOURCE="$SRC"
  check "copy failure exits non-zero" status_nonzero
  check "copy failure prints the cause to stderr" stderr_nonempty
  check "copy failure leaves the previous copy intact" previous_intact "$H"
  check "copy failure leaves no staging directory" no_staging_left "$H"
fi
chmod -R u+rwX "$SRC"

# 6. Services directory not writable: previous copy intact.
new_home
H="$NEW_HOME"
make_previous "$H"
chmod 555 "$H/Library/Services"
if [ "$(id -u)" -eq 0 ]; then
  echo "skip - read-only Services case (running as root)"
else
  run_install "$H"
  check "read-only Services exits non-zero" status_nonzero
  check "read-only Services prints the cause to stderr" stderr_nonempty
  check "read-only Services leaves the previous copy intact" previous_intact "$H"
fi
chmod 755 "$H/Library/Services"

# 7. HOME unset: refuses to run and writes nothing.
new_home
H="$NEW_HOME"
STDERR_FILE="$WORK/case$CASE/stderr"
env -u HOME PHANTOMTRACE_SKIP_PBS_FLUSH=1 /bin/bash "$SCRIPT" \
  >"$WORK/case$CASE/stdout" 2>"$STDERR_FILE"
STATUS=$?
check "unset HOME exits non-zero" status_nonzero
check "unset HOME prints the cause to stderr" stderr_nonempty

# 8. The real Services folder was never touched.
check "real ~/Library/Services is unchanged" [ "$(real_fingerprint)" = "$REAL_BEFORE" ]

echo
echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
