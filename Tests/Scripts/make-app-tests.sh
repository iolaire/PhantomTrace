#!/bin/bash
# Shell-level tests for Scripts/make-app.sh (task 17.3; Requirements 16.2, 16.3, 16.9, 16.10, 17.17).
#
#   Tests/Scripts/make-app-tests.sh
#
# Every case writes to a fresh temporary output directory (PHANTOMTRACE_OUTPUT_DIR) and passes a
# stub executable through PHANTOMTRACE_SKIP_BUILD_BIN, so no `swift build` runs, nothing is written
# to /Applications or to the repository's build/ directory, and the tests need only codesign and
# plutil (macOS). Exits 0 when every case passes.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)" || exit 2
SCRIPT="$ROOT/Scripts/make-app.sh"

[ -f "$SCRIPT" ] || { echo "missing $SCRIPT" >&2; exit 2; }
for tool in codesign plutil /usr/libexec/PlistBuddy; do
  command -v "$tool" >/dev/null 2>&1 || [ -x "$tool" ] || { echo "required tool $tool not found" >&2; exit 2; }
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pt-make-app-tests.XXXXXX")" || exit 2
cleanup() {
  chmod -R u+rwX "$WORK" 2>/dev/null
  rm -rf -- "$WORK"
}
trap cleanup EXIT

# A real Mach-O executable so codesign accepts it; copied, never modified in place.
STUB="$WORK/PhantomTraceApp"
cp /usr/bin/true "$STUB" || exit 2
chmod 755 "$STUB"

PASS=0
FAIL=0
CASE=0
STATUS=0
STDERR_FILE=""
OUT=""

pass() { PASS=$((PASS + 1)); echo "ok   - $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL - $1"; }
check() { # description, command...
  local description="$1"
  shift
  if "$@"; then pass "$description"; else fail "$description"; fi
}

new_case() { # sets OUT (fresh output dir) and the per-case scratch directory
  CASE=$((CASE + 1))
  mkdir -p "$WORK/case$CASE"
  OUT="$WORK/case$CASE/out"
}

# run_make [extra env assignments...]; sets STATUS and STDERR_FILE.
run_make() {
  STDERR_FILE="$WORK/case$CASE/stderr"
  env PHANTOMTRACE_OUTPUT_DIR="$OUT" PHANTOMTRACE_SKIP_BUILD_BIN="$STUB" "$@" \
    /bin/bash "$SCRIPT" >"$WORK/case$CASE/stdout" 2>"$STDERR_FILE"
  STATUS=$?
}

status_zero() { [ "$STATUS" -eq 0 ]; }
status_nonzero() { [ "$STATUS" -ne 0 ]; }
stderr_nonempty() { [ -s "$STDERR_FILE" ]; }
stderr_mentions() { grep -q -- "$1" "$STDERR_FILE"; }
no_staging_left() { ! ls -A "$OUT" 2>/dev/null | grep -q '^\.staging\.'; }

APP() { echo "$OUT/PhantomTrace.app"; }
plist_value() { /usr/libexec/PlistBuddy -c "Print :$1" "$(APP)/Contents/Info.plist" 2>/dev/null; }

fingerprint() { # dir -> content hash of every file, names included
  (cd "$1" && find . -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256)
}

# 1. Successful build: layout, plist keys, signature, no Apple fonts.
new_case
run_make PHANTOMTRACE_BUNDLE_ID=com.example.pt PHANTOMTRACE_VERSION=9.8.7 PHANTOMTRACE_BUILD_NUMBER=42
check "successful build exits 0" status_zero
check "successful build leaves no staging directory" no_staging_left
check "bundle has Contents/MacOS/PhantomTrace" [ -x "$(APP)/Contents/MacOS/PhantomTrace" ]
check "bundle has Contents/Info.plist" [ -f "$(APP)/Contents/Info.plist" ]
check "bundle has Contents/Resources" [ -d "$(APP)/Contents/Resources" ]
resources_present() {
  local r="$(APP)/Contents/Resources"
  [ -f "$r/window-frame.png" ] && [ -f "$r/window-frame@2x.png" ] && [ -f "$r/window-frame.insets.json" ]
}
check "resources include window-frame sprites and the insets file" resources_present
check "bundle has AppIcon.icns" [ -f "$(APP)/Contents/Resources/AppIcon.icns" ]
check "CFBundleIconFile is AppIcon" [ "$(plist_value CFBundleIconFile)" = "AppIcon" ]
check "Info.plist passes plutil -lint" plutil -lint "$(APP)/Contents/Info.plist" >/dev/null
check "CFBundleExecutable is PhantomTrace" [ "$(plist_value CFBundleExecutable)" = "PhantomTrace" ]
check "CFBundleIdentifier comes from the override" [ "$(plist_value CFBundleIdentifier)" = "com.example.pt" ]
check "CFBundleShortVersionString comes from the override" [ "$(plist_value CFBundleShortVersionString)" = "9.8.7" ]
check "CFBundleVersion comes from the override" [ "$(plist_value CFBundleVersion)" = "42" ]
check "LSMinimumSystemVersion is 15.0" [ "$(plist_value LSMinimumSystemVersion)" = "15.0" ]
check "URL scheme phantomtrace is registered" \
  [ "$(plist_value CFBundleURLTypes:0:CFBundleURLSchemes:0)" = "phantomtrace" ]
check "NSServices entry is present" [ -n "$(plist_value NSServices:0:NSMessage)" ]
no_placeholder() { ! grep -q '@[A-Z_]*@' "$(APP)/Contents/Info.plist"; }
check "no unreplaced placeholder in Info.plist" no_placeholder
check "codesign --verify --strict passes" codesign --verify --strict "$(APP)"
check "signature uses the hardened runtime" \
  bash -c 'codesign -dv "$1" 2>&1 | grep -q "flags=.*runtime"' _ "$(APP)"
APPLE_FONTS="$(find "$(APP)" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' -o -iname '*.dfont' \) \
  \( -iname 'SF*' -o -iname '*SanFrancisco*' -o -iname '*NewYork*' -o -iname '*Monaco*' -o -iname '*Menlo*' -o -iname '*Apple*' \) 2>/dev/null)"
check "no Apple font file is bundled" [ -z "$APPLE_FONTS" ]
check "no font file is bundled without its license" \
  bash -c 'f=$(find "$1" -type f \( -iname "*.ttf" -o -iname "*.otf" -o -iname "*.ttc" \)); [ -z "$f" ] || ls "$1" | grep -qiE "license|ofl"' \
  _ "$(APP)/Contents/Resources"

# 2. Forced failure (codesign cannot find the identity) leaves the previous bundle byte-identical.
new_case
run_make
check "setup build for the failure case exits 0" status_zero
BEFORE="$(fingerprint "$(APP)")"
run_make SIGN_IDENTITY="phantomtrace-no-such-identity-$$"
check "bad signing identity exits non-zero" status_nonzero
check "bad signing identity names the failed step on stderr" stderr_mentions "codesign"
check "bad signing identity leaves the previous bundle byte-identical" \
  [ "$(fingerprint "$(APP)")" = "$BEFORE" ]
check "bad signing identity leaves no staging directory" no_staging_left
check "previous bundle still verifies" codesign --verify --strict "$(APP)"

# 3. Missing prebuilt executable: non-zero, step on stderr, previous bundle untouched.
new_case
run_make
BEFORE="$(fingerprint "$(APP)")"
run_make PHANTOMTRACE_SKIP_BUILD_BIN="$WORK/does-not-exist"
check "missing executable exits non-zero" status_nonzero
check "missing executable prints the cause to stderr" stderr_nonempty
check "missing executable leaves the previous bundle byte-identical" \
  [ "$(fingerprint "$(APP)")" = "$BEFORE" ]

# 4. Invalid bundle identifier is rejected before anything is written.
new_case
run_make PHANTOMTRACE_BUNDLE_ID='bad id/$(x)'
check "invalid bundle id exits non-zero" status_nonzero
check "invalid bundle id prints the cause to stderr" stderr_nonempty
check "invalid bundle id creates no bundle" [ ! -e "$(APP)" ]

# 5. /Applications is refused and nothing is created there.
new_case
APPS_BEFORE="$(ls -A /Applications 2>/dev/null | cksum)"
run_make PHANTOMTRACE_OUTPUT_DIR=/Applications
check "output dir /Applications exits non-zero" status_nonzero
check "output dir /Applications prints the cause to stderr" stderr_mentions "/Applications"
check "/Applications is unchanged" [ "$(ls -A /Applications 2>/dev/null | cksum)" = "$APPS_BEFORE" ]

# 6. A rebuild over an existing bundle succeeds and replaces it.
new_case
run_make PHANTOMTRACE_VERSION=1.0.0
run_make PHANTOMTRACE_VERSION=2.0.0
check "rebuild exits 0" status_zero
check "rebuild replaces the previous bundle" [ "$(plist_value CFBundleShortVersionString)" = "2.0.0" ]
check "rebuild leaves no staging directory" no_staging_left

echo
echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
