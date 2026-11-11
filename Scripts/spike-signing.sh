#!/usr/bin/env bash
# Spike: confirm ad-hoc signing and notarization tooling work with Command Line Tools only.
# Builds a trivial executable, wraps it in a throwaway .app, signs it with the hardened
# runtime, verifies it, checks for notarytool and stapler, and runs the binary directly.
# Submits nothing anywhere. Everything lives in a temp directory removed on exit.
# Spec: Requirements 16.1, 16.6, 16.7, 16.8, 16.12.

set -u

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/phantomtrace-spike.XXXXXX")" || {
  echo "ERROR: could not create temp directory" >&2
  exit 1
}
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

FAILURES=0
report() { printf '%-28s %s\n' "$1" "$2"; }
fail() { FAILURES=$((FAILURES + 1)); report "$1" "FAIL: $2"; }

PKG="$TMP_DIR/SpikePkg"
APP="$TMP_DIR/Spike.app"
ENTITLEMENTS="$TMP_DIR/spike.entitlements"

# 1. Trivial SwiftPM executable
mkdir -p "$PKG/Sources/spike"
cat > "$PKG/Package.swift" <<'EOF'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Spike",
    targets: [.executableTarget(name: "spike")]
)
EOF
printf 'print("phantomtrace-spike-ok")\n' > "$PKG/Sources/spike/main.swift"

if swift build --package-path "$PKG" >"$TMP_DIR/build.log" 2>&1; then
  report "swift build" "ok"
else
  fail "swift build" "see output below"
  tail -n 20 "$TMP_DIR/build.log" >&2
  exit 1
fi
BIN_PATH="$(swift build --package-path "$PKG" --show-bin-path 2>/dev/null)/spike"

# 2. Minimal throwaway .app bundle
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_PATH" "$APP/Contents/MacOS/spike"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.example.phantomtrace.spike</string>
  <key>CFBundleName</key><string>Spike</string>
  <key>CFBundleExecutable</key><string>spike</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>0.0.1</string>
</dict>
</plist>
EOF

# Minimal entitlements: no sandbox (cannot be enabled for this product); empty dict.
cat > "$ENTITLEMENTS" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
EOF

# 3. Ad-hoc sign with hardened runtime, then verify
if codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign - "$APP" >"$TMP_DIR/sign.log" 2>&1; then
  report "codesign (ad-hoc)" "ok"
else
  fail "codesign (ad-hoc)" "$(tr '\n' ' ' < "$TMP_DIR/sign.log")"
fi

if codesign --verify --strict --verbose=2 "$APP" >"$TMP_DIR/verify.log" 2>&1; then
  report "codesign --verify" "ok"
else
  fail "codesign --verify" "$(tr '\n' ' ' < "$TMP_DIR/verify.log")"
fi

if codesign -d --verbose=2 "$APP" 2>&1 | grep -q 'flags=.*runtime'; then
  report "hardened runtime flag" "present"
else
  fail "hardened runtime flag" "not reported by codesign -d"
fi

# 4. Notarization tooling presence (nothing is submitted)
for tool in notarytool stapler; do
  if path="$(xcrun --find "$tool" 2>/dev/null)"; then
    report "xcrun --find $tool" "present: $path"
  else
    report "xcrun --find $tool" "ABSENT"
  fi
done

# 5. Run the bundled binary directly (no `open`, no Launch Services)
OUT="$("$APP/Contents/MacOS/spike" 2>&1)"
if [ "$OUT" = "phantomtrace-spike-ok" ]; then
  report "run bundled binary" "ok"
else
  fail "run bundled binary" "unexpected output: $OUT"
fi

if [ "$FAILURES" -eq 0 ]; then
  echo "Spike finished with no failures. Temp files removed."
  exit 0
fi
echo "Spike finished with $FAILURES failure(s). Temp files removed." >&2
exit 1
