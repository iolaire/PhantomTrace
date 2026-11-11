#!/bin/bash
# Read-only checks for the exported sprite set (task 14.2; Requirements 17.3, 17.6, 17.9, 17.15, 17.17).
# Checks: all 14 PNGs plus window-frame.insets.json exist, each @2x is exactly double its 1x,
# docs/LookAndFeel/original/ is unchanged in git, and no Kiro artwork or Apple font file is present.
# Uses sips (macOS) for pixel sizes and git for the original/ check. Makes no changes.
set -u
cd "$(dirname "$0")/.." || exit 1

SPRITES=Sources/PhantomTraceUI/Resources/Sprites
ORIGINAL=docs/LookAndFeel/original
NAMES="window-frame shackled-volume-and-padlocks crt-diagnostic-portal shattered-chains-and-portullis
ghost-looking-left-yellow ghost-looking-left-red ghost-looking-left-green"

FAILURES=0
fail() {
    echo "FAIL $1: $2"
    FAILURES=$((FAILURES + 1))
}

# dim <file> <pixelWidth|pixelHeight>
dim() {
    sips -g "$2" "$1" 2>/dev/null | awk -v k="$2" '$1 == k ":" { print $2 }'
}

for n in $NAMES; do
    for suffix in "" "@2x"; do
        f="$SPRITES/$n$suffix.png"
        [ -s "$f" ] || fail "$f" "missing or empty"
    done
    f1="$SPRITES/$n.png"
    f2="$SPRITES/$n@2x.png"
    if [ -s "$f1" ] && [ -s "$f2" ]; then
        w1=$(dim "$f1" pixelWidth); h1=$(dim "$f1" pixelHeight)
        w2=$(dim "$f2" pixelWidth); h2=$(dim "$f2" pixelHeight)
        if [ -z "$w1" ] || [ -z "$h1" ] || [ -z "$w2" ] || [ -z "$h2" ]; then
            fail "$f1" "could not read pixel size"
        elif [ "$w2" -ne $((w1 * 2)) ] || [ "$h2" -ne $((h1 * 2)) ]; then
            fail "$f2" "size ${w2}x${h2} is not double 1x ${w1}x${h1}"
        fi
    fi
done

INSETS="$SPRITES/window-frame.insets.json"
if [ ! -s "$INSETS" ]; then
    fail "$INSETS" "missing or empty"
elif ! python3 - "$INSETS" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
ok = all(isinstance(d.get(k), int) and d[k] > 0 for k in ("top", "left", "bottom", "right"))
sys.exit(0 if ok else 1)
PY
then
    fail "$INSETS" "invalid JSON or non-positive top/left/bottom/right"
fi

# Exactly 14 PNGs, nothing unexpected.
count=$(find "$SPRITES" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')
[ "$count" -eq 14 ] || fail "$SPRITES" "expected 14 PNG files, found $count"

# docs/LookAndFeel/original/ must be unchanged (no modified, deleted, or untracked files).
if [ -n "$(git status --porcelain -- "$ORIGINAL" 2>/dev/null)" ]; then
    fail "$ORIGINAL" "has uncommitted changes"
fi

# No Kiro logo/ghost artwork or Apple font files in the sprite set or the app resources.
RES=Sources/PhantomTraceUI/Resources
if [ -d "$RES" ]; then
    bad=$(find "$RES" \( -iname '*kiro*' -o -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' \
        -o -iname '*.dfont' -o -iname 'SF*' -o -iname '*SFPro*' -o -iname '*SFMono*' \
        -o -iname '*NewYork*' -o -iname '*Chicago*' \) 2>/dev/null)
    for f in $bad; do
        fail "$f" "forbidden Kiro artwork or Apple font file"
    done
fi

if [ "$FAILURES" -gt 0 ]; then
    echo "verify-sprites: $FAILURES check(s) failed"
    exit 1
fi
echo "verify-sprites: all checks passed"
