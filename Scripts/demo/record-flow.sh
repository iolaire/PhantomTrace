#!/bin/bash
# Records the resolution flow as one clip, with the app driven through Accessibility instead of by hand:
# Egress Shells -> Graceful Request -> Eject, on the throwaway PhantomDemo drive.
#
#   Scripts/demo/record-flow.sh --preview          lay out the windows, save one still, record nothing
#   Scripts/demo/record-flow.sh [scene-id]          record (default scene id: s06-egress)
#
# Before: Scripts/make-app.sh, Scripts/demo/setup-demo.sh (Terminal mode, so a Terminal tab has its
# working directory on the drive and a `tail -f` holds a file). The app that runs this script needs
# Accessibility and Screen Recording permission. Clear the desktop behind the right-hand part of the
# main screen: the clip is a screen region, so anything behind the windows shows.
#
# Layout: the PhantomTrace start window is moved flush right; the lock window then opens on top of it
# (the app keeps it on screen) and the plan dialogs center on that. Terminal sits to the left.
# The pointer glides to each control and clicks for real; `screencapture -C -k` shows the cursor and a
# ring on each click. Each step waits for its control to appear, so there are no fixed long pauses.
#
# Safety: acts only when /Volumes/PhantomDemo belongs to the demo image, and only on that volume.
# Afterwards the volume is unmounted but the image stays attached; see demo/CLIPS.md to reset.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEMO_DIR="${PHANTOMTRACE_DEMO_DIR:-$HOME/PhantomTraceDemo}"
VOL_NAME="${PHANTOMTRACE_DEMO_VOLUME:-PhantomDemo}"
MOUNT="/Volumes/$VOL_NAME"
IMAGE="$DEMO_DIR/$VOL_NAME.dmg"
APP="$ROOT/build/PhantomTrace.app"
SRC="$ROOT/Scripts/demo/ax-drive.swift"
AX="$DEMO_DIR/bin/ax-drive"

PREVIEW=0
ID="s06-egress"
case "${1:-}" in
    --preview) PREVIEW=1 ;;
    "") ;;
    *) ID="$1" ;;
esac
if ! [[ "$ID" =~ ^[a-z0-9-]+$ ]] || ! grep -q "\"id\": *\"$ID\"" "$ROOT/demo/scenes.json"; then
    echo "error: '$ID' is not a scene in demo/scenes.json" >&2
    exit 2
fi

# Preconditions. Nothing is changed if any of these fail.
[ -d "$APP" ] || { echo "error: $APP not found; run Scripts/make-app.sh" >&2; exit 1; }
MOUNTS="$(mount)"
grep -q " on $MOUNT " <<<"$MOUNTS" || { echo "error: $MOUNT is not mounted; run Scripts/demo/setup-demo.sh" >&2; exit 1; }
# Capture first: `cmd | grep -q` under pipefail fails when grep exits early and cmd gets SIGPIPE.
IMAGES="$(/usr/bin/hdiutil info 2>/dev/null || true)"
if ! grep -q "image-path *: *$IMAGE\$" <<<"$IMAGES"; then
    echo "error: $MOUNT is not the demo image $IMAGE; refusing to touch it" >&2
    exit 1
fi
SHELL_PID=""
for pid in $(/usr/sbin/lsof -w -a -d cwd -F p +f -- "$MOUNT" 2>/dev/null | sed -n 's/^p//p'); do
    if [[ "$(ps -o comm= -p "$pid" 2>/dev/null)" == *zsh ]]; then
        SHELL_PID="$pid"
        break
    fi
done
TTY="$(ps -o tty= -p "${SHELL_PID:-0}" 2>/dev/null | tr -d ' ' || true)"
if [ -z "$SHELL_PID" ] || [ -z "$TTY" ] || [ "$TTY" = "??" ]; then
    echo "error: no Terminal shell has its working directory on $MOUNT." >&2
    echo "Open Terminal, run: cd $MOUNT   then run this again." >&2
    exit 1
fi

# Build the driver when missing or older than its source.
mkdir -p "$DEMO_DIR/bin"
if [ ! -x "$AX" ] || [ "$SRC" -nt "$AX" ]; then
    echo "building ax-drive"
    swiftc -O "$SRC" -o "$AX"
fi
unset AXWIN
now() { python3 -c 'import time; print(f"{time.time():.2f}")'; }

# Layout from the main screen's visible frame.
read -r SX SY SW SH < <("$AX" PhantomTrace screen)
RIGHT=$((SX + SW))
TOP="${PHANTOMTRACE_FLOW_TOP:-$((SY + (SH - 520) / 3))}"  # top edge in screen points; override to match a cleared area
[[ "$TOP" =~ ^[0-9]+$ ]] || { echo "error: PHANTOMTRACE_FLOW_TOP must be a whole number" >&2; exit 2; }
LOCK_W=1011; PICKER_W=771; TERM_W=480; GAP=10
TERM_L=$((RIGHT - LOCK_W - GAP - TERM_W))
REGION="$TERM_L,$TOP,$((TERM_W + GAP + LOCK_W)),520"

# Terminal tab with the shell on the drive: visible prompt, big font, left of the app windows.
osascript - "/dev/$TTY" "$TERM_L" "$TOP" "$((TERM_L + TERM_W))" "$((TOP + 520))" >/dev/null <<'EOF'
on run argv
    set target to item 1 of argv
    tell application "Terminal"
        repeat with w in windows
            repeat with t in tabs of w
                if tty of t is target then
                    do script "PROMPT='%~ %# '; clear" in t
                    set font size of t to 18
                    set selected tab of w to t
                    set index of w to 1
                    set bounds of w to {(item 2 of argv) as integer, (item 3 of argv) as integer, ¬
                        (item 4 of argv) as integer, (item 5 of argv) as integer}
                    activate
                    return
                end if
            end repeat
        end repeat
    end tell
end run
EOF

open -a "$APP"
sleep 1
AXWIN="" "$AX" PhantomTrace press "Close window" >/dev/null 2>&1 || true  # a lock window from a past take
"$AX" PhantomTrace wait "Inspect" >/dev/null
"$AX" PhantomTrace move "PhantomTrace" "$((RIGHT - PICKER_W))" "$TOP" >/dev/null
"$AX" PhantomTrace pointer "$((RIGHT - 400))" "$((TOP + 470))"
sleep 0.5

if [ "$PREVIEW" -eq 1 ]; then
    screencapture -x -R "$REGION" "$DEMO_DIR/preview.png"
    echo "preview: $DEMO_DIR/preview.png (region $REGION). Look at it, then delete it."
    exit 0
fi

OUT="$ROOT/demo/public/clips/$ID.mp4"
RAW="$(mktemp -t phantomtrace-flow).mov"
trap 'rm -f "$RAW"' EXIT
mkdir -p "$(dirname "$OUT")"
URL="phantomtrace://inspect?path=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$MOUNT")"

T0=$(now)
# -V gives headroom; the clip is trimmed to the measured length below (stopping early can break the file).
screencapture -v -x -C -k -V 40 -R "$REGION" "$RAW" &
REC=$!
sleep 1
open "$URL"
"$AX" PhantomTrace wait "Summon the Phantom Trace" >/dev/null; sleep 0.8
"$AX" PhantomTrace click "Summon the Phantom Trace"
"$AX" PhantomTrace wait "Egress Shells" AXRadioButton >/dev/null; sleep 0.8
"$AX" PhantomTrace click "Egress Shells" AXRadioButton; sleep 0.3
"$AX" PhantomTrace click "Proceed, if you dare"
"$AX" PhantomTrace wait "Send Shells Home" >/dev/null; sleep 1
"$AX" PhantomTrace click "Send Shells Home"
"$AX" PhantomTrace wait "Graceful Request" AXRadioButton >/dev/null; sleep 1
"$AX" PhantomTrace click "Graceful Request" AXRadioButton; sleep 0.3
"$AX" PhantomTrace click "Proceed, if you dare"
"$AX" PhantomTrace wait "Ask to Quit" >/dev/null; sleep 1
"$AX" PhantomTrace click "Ask to Quit"
"$AX" PhantomTrace wait "Eject" AXButton >/dev/null; sleep 1.2
"$AX" PhantomTrace click "Eject" AXButton
sleep 2.5
LEN=$(python3 -c "print(round($(now) - $T0, 2))")
wait "$REC"

ffmpeg -y -loglevel error -i "$RAW" -t "$LEN" -an -c:v libx264 -pix_fmt yuv420p -crf 18 -r 30 \
    -vf "scale='min(1920,iw)':-2" -movflags +faststart "$OUT"
echo "saved $OUT (${LEN} s)"
if grep -q " on $MOUNT " <<<"$(mount)"; then
    echo "warning: $MOUNT is still mounted; a lock was left. Check the clip before keeping it." >&2
fi
