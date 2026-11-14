#!/bin/bash
# Records demo clips with the apps driven through Accessibility instead of by hand.
#
#   Scripts/demo/record-flow.sh problem [--preview]   s01-problem: Finder's own eject failure
#       Finder window on the drive -> right-click it in the sidebar -> Eject -> the "wasn't ejected"
#       alert sits for 3 s -> Cancel. No PhantomTrace in frame.
#   Scripts/demo/record-flow.sh resolve [--preview]   one take, cut into s03-trigger, s06-egress,
#       s07-graceful and s09-handoff
#       Desktop icon -> right-click -> Quick Actions -> Why Can't I Eject? -> Summon -> Egress Shells ->
#       Graceful Request -> Eject; the desktop icon disappears at the end.
#
# --preview lays out the windows and saves one still (~/PhantomTraceDemo/preview.png), records nothing.
#
# Before: Scripts/make-app.sh, Scripts/install-quick-action.sh (enabled in Finder), and
# Scripts/demo/setup-demo.sh (Terminal mode). `resolve` needs a Terminal tab with its working directory on
# the drive (the idle shell) plus the `tail` lock; `problem` needs any lock. The app that runs this
# script needs Accessibility and Screen Recording. Clear the screen area being recorded: the clip is a
# screen region, so anything behind the windows shows.
#
# Layout (resolve): the PhantomTrace start window is moved flush right; the lock window opens on top of
# it (the app keeps it on screen) and plan dialogs center on that. Terminal sits to its left and the
# drive's desktop icon left of Terminal (its old position is restored afterwards).
# The pointer glides to each control and clicks for real; `screencapture -C -k` shows the cursor and a
# ring on each click. Each step waits for its control, then pauses about 1 s.
#
# Safety: acts only when /Volumes/PhantomDemo belongs to the demo image; never presses Force Eject or
# Force Unmount. Afterwards (resolve) the volume is unmounted and the image stays attached; reset with
# Scripts/demo/teardown-demo.sh && Scripts/demo/setup-demo.sh.
#
# Environment: PHANTOMTRACE_FLOW_TOP (top edge in screen points; default a third of the way down).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEMO_DIR="${PHANTOMTRACE_DEMO_DIR:-$HOME/PhantomTraceDemo}"
VOL_NAME="${PHANTOMTRACE_DEMO_VOLUME:-PhantomDemo}"
MOUNT="/Volumes/$VOL_NAME"
IMAGE="$DEMO_DIR/$VOL_NAME.dmg"
APP="$ROOT/build/PhantomTrace.app"
SRC="$ROOT/Scripts/demo/ax-drive.swift"
AX="$DEMO_DIR/bin/ax-drive"
CLIPS="$ROOT/demo/public/clips"

usage() { echo "usage: $0 problem|resolve [--preview]" >&2; exit 2; }
MODE="${1:-}"
[ "$MODE" = "problem" ] || [ "$MODE" = "resolve" ] || usage
PREVIEW=0
case "${2:-}" in
    --preview) PREVIEW=1 ;;
    "") ;;
    *) usage ;;
esac

# Preconditions. Nothing is changed if any of these fail.
# (Capture first: `cmd | grep -q` under pipefail fails when grep exits early and cmd gets SIGPIPE.)
[ -d "$APP" ] || { echo "error: $APP not found; run Scripts/make-app.sh" >&2; exit 1; }
MOUNTS="$(mount)"
grep -q " on $MOUNT " <<<"$MOUNTS" || { echo "error: $MOUNT is not mounted; run Scripts/demo/setup-demo.sh" >&2; exit 1; }
IMAGES="$(/usr/bin/hdiutil info 2>/dev/null || true)"
if ! grep -q "image-path *: *$IMAGE\$" <<<"$IMAGES"; then
    echo "error: $MOUNT is not the demo image $IMAGE; refusing to touch it" >&2
    exit 1
fi
HOLDERS="$(/usr/sbin/lsof -w -F p +f -- "$MOUNT" 2>/dev/null || true)"
[ -n "$HOLDERS" ] || { echo "error: nothing holds $MOUNT, so there is nothing to show; run setup-demo.sh" >&2; exit 1; }
TTY=""
if [ "$MODE" = "resolve" ]; then
    for pid in $(/usr/sbin/lsof -w -a -d cwd -F p +f -- "$MOUNT" 2>/dev/null | sed -n 's/^p//p'); do
        if [[ "$(ps -o comm= -p "$pid" 2>/dev/null)" == *zsh ]]; then
            TTY="$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
            [ -n "$TTY" ] && [ "$TTY" != "??" ] && break
            TTY=""
        fi
    done
    if [ -z "$TTY" ]; then
        echo "error: no Terminal shell has its working directory on $MOUNT." >&2
        echo "Open Terminal, run: cd $MOUNT   then run this again." >&2
        exit 1
    fi
fi

# Build the driver when missing or older than its source.
mkdir -p "$DEMO_DIR/bin" "$DEMO_DIR/takes"
if [ ! -x "$AX" ] || [ "$SRC" -nt "$AX" ]; then
    echo "building ax-drive"
    swiftc -O "$SRC" -o "$AX"
fi
unset AXWIN AXAT

# Layout from the main screen's visible frame.
read -r SX SY SW SH < <("$AX" PhantomTrace screen)
RIGHT=$((SX + SW))
TOP="${PHANTOMTRACE_FLOW_TOP:-$((SY + (SH - 520) / 3))}"
[[ "$TOP" =~ ^[0-9]+$ ]] || { echo "error: PHANTOMTRACE_FLOW_TOP must be a whole number" >&2; exit 2; }
LOCK_W=1011; PICKER_W=771; TERM_W=480; GAP=10; ICON_W=140
TERM_L=$((RIGHT - LOCK_W - GAP - TERM_W))

T0=0
MARKS=""
now() { python3 -c 'import time; print(f"{time.time():.3f}")'; }
mark() { MARKS="$MARKS$1 $(python3 -c "print(round($(now) - $T0, 2))")"$'\n'; }
mark_at() { grep "^$1 " <<<"$MARKS" | head -1 | cut -d' ' -f2; }
retry() {  # retry <command...>: up to 10 s, for menus and alerts that are still opening
    for _ in $(seq 1 50); do
        "$@" >/dev/null 2>&1 && return 0
        sleep 0.2
    done
    echo "error: timed out: $*" >&2
    return 1
}
terminal_minimized() {  # terminal_minimized true|false
    osascript -e "tell application \"Terminal\" to set miniaturized of every window to $1" >/dev/null 2>&1 || true
}

finder_window() {  # finder_window open|close l t r b
    osascript - "$@" "$MOUNT" "$VOL_NAME" >/dev/null <<'EOF'
on run argv
    set action to item 1 of argv
    tell application "Finder"
        if action is "close" then
            -- Finder rejects `close` on a filtered list (-10010); close one named window at a time.
            repeat 20 times
                if not (exists (first Finder window whose name is (item 7 of argv))) then exit repeat
                close (first Finder window whose name is (item 7 of argv))
            end repeat
            return
        end if
        set w to make new Finder window to (POSIX file (item 6 of argv) as alias)
        set toolbar visible of w to true
        set current view of w to icon view
        set b to {(item 2 of argv) as integer, (item 3 of argv) as integer, (item 4 of argv) as integer, ¬
            (item 5 of argv) as integer}
        set bounds of w to b
        delay 0.5
        set bounds of w to b
        activate
    end tell
end run
EOF
}

# --- Record a region for a fixed headroom, run the steps, trim to the measured length. ---
start_recording() {  # start_recording region
    RAW="$(mktemp -t phantomtrace-flow).mov"
    T0=$(now)
    screencapture -v -x -C -k -V 45 -R "$1" "$RAW" &
    REC=$!
}
finish_recording() {  # finish_recording out.mp4 -> full take, trimmed
    local len
    len=$(python3 -c "print(round($(now) - $T0, 2))")
    wait "$REC"
    ffmpeg -y -loglevel error -i "$RAW" -t "$len" -an -c:v libx264 -pix_fmt yuv420p -crf 18 -r 30 \
        -vf "scale='min(1920,iw)':-2" -movflags +faststart "$1"
    rm -f "$RAW"
    echo "take: $1 (${len} s)"
}
cut_clip() {  # cut_clip take.mp4 scene-id start end
    local out="$CLIPS/$2.mp4"
    ffmpeg -y -loglevel error -ss "$3" -i "$1" -t "$(python3 -c "print(round($4 - $3, 2))")" -an -c:v libx264 \
        -pix_fmt yuv420p -crf 18 -r 30 -movflags +faststart "$out"
    echo "saved $out ($3 s to $4 s of the take)"
}

# --- s01-problem ---
if [ "$MODE" = "problem" ]; then
    # Finder window left of center; macOS centers the eject alert near the top of the screen.
    FL=$((SX + SW / 2 - 760)); FR=$((FL + 700)); FB=$((TOP + 680))
    REGION="$FL,$TOP,1020,680"
    terminal_minimized true  # keep Terminal out of this frame
    finder_window close 0 0 0 0
    finder_window open "$FL" "$TOP" "$FR" "$FB"
    "$AX" PhantomTrace pointer "$((FL + 500))" "$((TOP + 400))" 2>/dev/null || true
    sleep 0.5
    if [ "$PREVIEW" -eq 1 ]; then
        screencapture -x -R "$REGION" "$DEMO_DIR/preview.png"
        echo "preview: $DEMO_DIR/preview.png (region $REGION). Look at it, then delete it."
        exit 0
    fi
    start_recording "$REGION"
    sleep 1
    AXWIN="$VOL_NAME" "$AX" Finder rclick "$VOL_NAME" AXStaticText
    sleep 0.9
    "$AX" Finder click "Eject “${VOL_NAME}”" AXMenuItem
    # The alert's agent may take a moment to start; ax-drive fails fast while it is not running.
    retry "$AX" UnmountAssistantAgent wait "Cancel" AXButton
    sleep 3
    "$AX" UnmountAssistantAgent click "Cancel" AXButton  # never Force Eject
    sleep 1.2
    TAKE="$DEMO_DIR/takes/s01-problem-full.mp4"
    finish_recording "$TAKE"
    cp "$TAKE" "$CLIPS/s01-problem.mp4"
    echo "saved $CLIPS/s01-problem.mp4"
    finder_window close 0 0 0 0
    grep -q " on $MOUNT " <<<"$(mount)" || echo "warning: $MOUNT is no longer mounted" >&2
    exit 0
fi

# --- resolve: s03-trigger, s06-egress, s07-graceful, s09-handoff ---
REGION="$((TERM_L - ICON_W)),$TOP,$((ICON_W + TERM_W + GAP + LOCK_W)),520"
ICON_X=$((TERM_L - ICON_W / 2)); ICON_Y=$((TOP + 95))
OLD_ICON="$(osascript -e "tell application \"Finder\" to get desktop position of disk \"$VOL_NAME\"" 2>/dev/null \
    | tr -d ' ' || true)"
restore_icon() {
    # The disk is gone after a successful take; Finder then forgets the position anyway.
    [ -n "$OLD_ICON" ] && osascript -e "tell application \"Finder\" to set desktop position of disk \"$VOL_NAME\" to {$OLD_ICON}" \
        >/dev/null 2>&1 || true
}
trap restore_icon EXIT

finder_window close 0 0 0 0
terminal_minimized false
osascript -e "tell application \"Finder\" to set desktop position of disk \"$VOL_NAME\" to {$ICON_X, $ICON_Y}" >/dev/null
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
osascript -e 'tell application "Finder" to activate' >/dev/null  # the desktop takes the right-click
"$AX" PhantomTrace pointer "$((TERM_L + 240))" "$((TOP + 400))"
sleep 0.5

if [ "$PREVIEW" -eq 1 ]; then
    screencapture -x -R "$REGION" "$DEMO_DIR/preview.png"
    echo "preview: $DEMO_DIR/preview.png (region $REGION). Look at it, then delete it."
    exit 0
fi

start_recording "$REGION"
sleep 1
"$AX" Finder rclick "$VOL_NAME" AXImage
# The context menu opens with its top-left at the pointer; search from inside it.
MENU_AT="$((ICON_X + 40)),$((ICON_Y + 20))"
retry env AXAT="$MENU_AT" "$AX" Finder wait "Quick Actions" AXMenuItem; sleep 0.7
AXAT="$MENU_AT" "$AX" Finder click "Quick Actions" AXMenuItem
retry env AXAT="$MENU_AT" "$AX" Finder wait "Why Can't I Eject?" AXMenuItem; sleep 0.5
AXAT="$MENU_AT" "$AX" Finder click "Why Can't I Eject?" AXMenuItem
"$AX" PhantomTrace wait "Summon the Phantom Trace" >/dev/null; sleep 1.2
mark summon;   "$AX" PhantomTrace click "Summon the Phantom Trace"
"$AX" PhantomTrace wait "Egress Shells" AXRadioButton >/dev/null; sleep 0.8
"$AX" PhantomTrace click "Egress Shells" AXRadioButton; sleep 0.3
"$AX" PhantomTrace click "Proceed, if you dare"
"$AX" PhantomTrace wait "Send Shells Home" >/dev/null; sleep 1
"$AX" PhantomTrace click "Send Shells Home"
"$AX" PhantomTrace wait "Graceful Request" AXRadioButton >/dev/null; sleep 1
mark graceful; "$AX" PhantomTrace click "Graceful Request" AXRadioButton; sleep 0.3
"$AX" PhantomTrace click "Proceed, if you dare"
"$AX" PhantomTrace wait "Ask to Quit" >/dev/null; sleep 1
"$AX" PhantomTrace click "Ask to Quit"
"$AX" PhantomTrace wait "Eject" AXButton >/dev/null
mark released; sleep 1.2
"$AX" PhantomTrace click "Eject" AXButton
sleep 2.8
mark end

TAKE="$DEMO_DIR/takes/resolve-full.mp4"
finish_recording "$TAKE"
printf '%s' "$MARKS" > "$DEMO_DIR/takes/resolve-marks.txt"
cut_clip "$TAKE" s03-trigger 0 "$(python3 -c "print(round($(mark_at summon) + 0.3, 2))")"
cut_clip "$TAKE" s06-egress "$(mark_at summon)" "$(mark_at graceful)"
cut_clip "$TAKE" s07-graceful "$(python3 -c "print(round($(mark_at graceful) - 0.3, 2))")" "$(mark_at released)"
cut_clip "$TAKE" s09-handoff "$(python3 -c "print(round(max(0, $(mark_at released) - 0.8), 2))")" "$(mark_at end)"
if grep -q " on $MOUNT " <<<"$(mount)"; then
    echo "warning: $MOUNT is still mounted; a lock was left. Check the clips before keeping them." >&2
    exit 1
fi
exit 0
