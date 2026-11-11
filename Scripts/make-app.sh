#!/usr/bin/env bash
# Build and sign build/PhantomTrace.app using SwiftPM and the Command Line Tools only.
# No xcodebuild, actool, or Interface Builder. No notarization (manual, optional; see README).
#
# Steps: build PhantomTraceApp, assemble the bundle in a staging directory, sign it with the
# hardened runtime, verify the signature, then replace build/PhantomTrace.app. Any failure prints
# the failed step and cause to standard error, exits non-zero, and leaves an existing bundle as is.
#
# Environment overrides:
#   SIGN_IDENTITY                codesign identity (default "-", ad-hoc)
#   CONFIGURATION                swift build configuration (default "release")
#   PHANTOMTRACE_BUNDLE_ID       bundle identifier (default com.phantomtrace.app)
#   PHANTOMTRACE_VERSION         CFBundleShortVersionString (default 0.1.0)
#   PHANTOMTRACE_BUILD_NUMBER    CFBundleVersion (default 1)
#   PHANTOMTRACE_OUTPUT_DIR      output directory (default <repo>/build); must not be /Applications
#   PHANTOMTRACE_SKIP_BUILD_BIN  path to a prebuilt executable; skips swift build (used by tests)
# Spec: Requirements 16.1 to 16.11, 17.1.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || {
  echo "make-app.sh: step 'locate repository' failed: cannot resolve script directory" >&2
  exit 1
}
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
CONFIGURATION="${CONFIGURATION:-release}"
BUNDLE_ID="${PHANTOMTRACE_BUNDLE_ID:-com.phantomtrace.app}"
VERSION="${PHANTOMTRACE_VERSION:-0.1.0}"
BUILD_NUMBER="${PHANTOMTRACE_BUILD_NUMBER:-1}"
OUTPUT_DIR="${PHANTOMTRACE_OUTPUT_DIR:-$REPO_ROOT/build}"
PREBUILT_BIN="${PHANTOMTRACE_SKIP_BUILD_BIN:-}"

TEMPLATE="$REPO_ROOT/Packaging/Info.plist.template"
ENTITLEMENTS="$REPO_ROOT/Packaging/PhantomTrace.entitlements"
SPRITES_DIR="$REPO_ROOT/Sources/PhantomTraceUI/Resources/Sprites"
FONTS_DIR="$REPO_ROOT/Sources/PhantomTraceUI/Resources/Fonts"
ICON="$REPO_ROOT/Packaging/AppIcon.icns"
FINAL_APP="$OUTPUT_DIR/PhantomTrace.app"
STAGING=""

die() {
  # $1 = step, $2 = cause
  printf 'make-app.sh: step "%s" failed: %s\n' "$1" "$2" >&2
  exit 1
}

cleanup() {
  if [ -n "$STAGING" ] && [ -d "$STAGING" ]; then rm -rf "$STAGING"; fi
}
trap cleanup EXIT

# Step: validate inputs
case "$OUTPUT_DIR" in
  /Applications|/Applications/*) die "validate inputs" "refusing to write to /Applications" ;;
esac
case "$BUNDLE_ID$VERSION$BUILD_NUMBER" in
  *[!A-Za-z0-9.-]*) die "validate inputs" "bundle id, version and build number may only contain letters, digits, '.' and '-'" ;;
esac
[ -f "$TEMPLATE" ] || die "validate inputs" "missing $TEMPLATE"
[ -f "$ENTITLEMENTS" ] || die "validate inputs" "missing $ENTITLEMENTS"
[ -f "$ICON" ] || die "validate inputs" "missing $ICON (run Scripts/export-app-icon.py)"
[ -d "$SPRITES_DIR" ] || die "validate inputs" "missing sprite directory $SPRITES_DIR"
for tool in swift codesign plutil; do
  command -v "$tool" >/dev/null 2>&1 || die "validate inputs" "required tool '$tool' not found on PATH"
done

# Step: swift build (PhantomTraceApp only)
if [ -n "$PREBUILT_BIN" ]; then
  BIN="$PREBUILT_BIN"
else
  BUILD_LOG="$(mktemp "${TMPDIR:-/tmp}/phantomtrace-build.XXXXXX")" || die "swift build" "cannot create log file"
  if ! swift build --package-path "$REPO_ROOT" -c "$CONFIGURATION" --product PhantomTraceApp >"$BUILD_LOG" 2>&1; then
    tail -n 30 "$BUILD_LOG" >&2
    rm -f "$BUILD_LOG"
    die "swift build" "swift build --product PhantomTraceApp failed (output above)"
  fi
  rm -f "$BUILD_LOG"
  BIN_DIR="$(swift build --package-path "$REPO_ROOT" -c "$CONFIGURATION" --show-bin-path 2>/dev/null)" ||
    die "swift build" "could not determine the build products path"
  BIN="$BIN_DIR/PhantomTraceApp"
fi
[ -f "$BIN" ] && [ -x "$BIN" ] || die "swift build" "executable not found at $BIN"

# Step: assemble bundle in a staging directory next to the final location (same file system)
mkdir -p "$OUTPUT_DIR" || die "assemble bundle" "cannot create $OUTPUT_DIR"
STAGING="$(mktemp -d "$OUTPUT_DIR/.staging.XXXXXX")" || die "assemble bundle" "cannot create staging directory in $OUTPUT_DIR"
APP="$STAGING/PhantomTrace.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" || die "assemble bundle" "cannot create bundle directories"
cp "$BIN" "$APP/Contents/MacOS/PhantomTrace" || die "assemble bundle" "cannot copy executable"
chmod 755 "$APP/Contents/MacOS/PhantomTrace" || die "assemble bundle" "cannot mark executable"

# Step: write Info.plist from the template
sed -e "s/@BUNDLE_IDENTIFIER@/$BUNDLE_ID/g" \
    -e "s/@VERSION@/$VERSION/g" \
    -e "s/@BUILD_NUMBER@/$BUILD_NUMBER/g" \
    "$TEMPLATE" >"$APP/Contents/Info.plist" || die "write Info.plist" "substitution failed"
if grep -q '@[A-Z_]*@' "$APP/Contents/Info.plist"; then
  die "write Info.plist" "unreplaced placeholder left in Info.plist"
fi
PLUTIL_OUT="$(plutil -lint "$APP/Contents/Info.plist" 2>&1)" || die "write Info.plist" "plutil -lint: $PLUTIL_OUT"

# Step: copy resources (sprites and insets file; optional Title_Font plus its license file)
RES="$APP/Contents/Resources"
SPRITE_COUNT=0
for f in "$SPRITES_DIR"/*.png "$SPRITES_DIR"/*.json; do
  [ -f "$f" ] || continue
  cp "$f" "$RES/" || die "copy resources" "cannot copy $f"
  SPRITE_COUNT=$((SPRITE_COUNT + 1))
done
[ "$SPRITE_COUNT" -gt 0 ] || die "copy resources" "no sprite files found in $SPRITES_DIR"
cp "$ICON" "$RES/AppIcon.icns" || die "copy resources" "cannot copy app icon"
if [ -d "$FONTS_DIR" ]; then
  FONT_FOUND=0
  for f in "$FONTS_DIR"/*.ttf "$FONTS_DIR"/*.otf "$FONTS_DIR"/*.ttc; do
    [ -f "$f" ] || continue
    FONT_FOUND=1
    cp "$f" "$RES/" || die "copy resources" "cannot copy font $f"
  done
  if [ "$FONT_FOUND" -eq 1 ]; then
    LICENSE_FOUND=0
    for f in "$FONTS_DIR"/LICENSE* "$FONTS_DIR"/OFL* "$FONTS_DIR"/*license*; do
      [ -f "$f" ] || continue
      LICENSE_FOUND=1
      cp "$f" "$RES/" || die "copy resources" "cannot copy font license $f"
    done
    [ "$LICENSE_FOUND" -eq 1 ] || die "copy resources" "a Title_Font is present in $FONTS_DIR without a license file"
  fi
fi

# Step: sign with the hardened runtime
CODESIGN_OUT="$(codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP" 2>&1)" ||
  die "codesign" "$CODESIGN_OUT"

# Step: verify the signature
VERIFY_OUT="$(codesign --verify --strict "$APP" 2>&1)" || die "codesign --verify --strict" "$VERIFY_OUT"

# Step: replace the previous bundle only now that signing and verification passed
BACKUP=""
if [ -e "$FINAL_APP" ]; then
  BACKUP="$STAGING/previous.app"
  mv "$FINAL_APP" "$BACKUP" || die "replace bundle" "cannot move the previous bundle aside"
fi
if ! mv "$APP" "$FINAL_APP"; then
  if [ -n "$BACKUP" ]; then mv "$BACKUP" "$FINAL_APP" 2>/dev/null; fi
  die "replace bundle" "cannot move the new bundle into place; previous bundle restored"
fi

echo "Built and verified $FINAL_APP (identity: $SIGN_IDENTITY, hardened runtime, not notarized)"
exit 0
