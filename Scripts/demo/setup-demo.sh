#!/bin/bash
# Sets up the throwaway demo drive: a small disk image with two locks on it.
#
#   Scripts/demo/setup-demo.sh              image + held file + Terminal window with cwd on the volume
#   Scripts/demo/setup-demo.sh --headless   image + held file + background idle shell (no Terminal window)
#   Scripts/demo/teardown-demo.sh           stops the helpers, detaches and deletes the image
#
# Safety: it only ever touches the image it creates (PhantomDemo.dmg under $PHANTOMTRACE_DEMO_DIR) and the
# helper processes it started. It never mounts, signals, or detaches anything else. Never point it at a
# real drive.
set -euo pipefail

MODE="terminal"
case "${1:-}" in
    "") ;;
    --headless) MODE="headless" ;;
    *) echo "usage: $0 [--headless]" >&2; exit 2 ;;
esac

DEMO_DIR="${PHANTOMTRACE_DEMO_DIR:-$HOME/PhantomTraceDemo}"
VOL_NAME="${PHANTOMTRACE_DEMO_VOLUME:-PhantomDemo}"
IMAGE="$DEMO_DIR/$VOL_NAME.dmg"
MOUNT="/Volumes/$VOL_NAME"
STATE="$DEMO_DIR/state.env"
FIFO="$DEMO_DIR/shell.fifo"

if [ -e "$STATE" ] || [ -e "$MOUNT" ]; then
    echo "error: $MOUNT or a previous demo state already exists." >&2
    echo "Run Scripts/demo/teardown-demo.sh first. Nothing was changed." >&2
    exit 1
fi

mkdir -p "$DEMO_DIR"
rm -f "$IMAGE"
hdiutil create -size 20m -fs APFS -volname "$VOL_NAME" "$IMAGE" >/dev/null
hdiutil attach "$IMAGE" >/dev/null

echo "ghost in the machine" > "$MOUNT/notes.txt"

# Lock 1: a held open file.
nohup tail -f "$MOUNT/notes.txt" >/dev/null 2>&1 &
TAIL_PID=$!

# Lock 2: an idle shell whose working directory is the volume.
SHELL_PID=""
if [ "$MODE" = "headless" ]; then
    rm -f "$FIFO"
    mkfifo "$FIFO"
    # A process holds the fifo open read-write so the shell never sees end of input.
    nohup sleep 100000 <>"$FIFO" >/dev/null 2>&1 &
    echo $! > "$DEMO_DIR/fifo-holder.pid"
    cd "$MOUNT"
    nohup zsh -f <"$FIFO" >/dev/null 2>&1 &
    SHELL_PID=$!
    cd "$DEMO_DIR"
else
    if ! osascript -e "tell application \"Terminal\" to do script \"cd '$MOUNT'\"" >/dev/null 2>&1; then
        MODE="terminal-manual"
        echo "warning: Terminal automation was denied. Open Terminal yourself and run: cd '$MOUNT'" >&2
    fi
fi

cat > "$STATE" <<EOF
IMAGE='$IMAGE'
MOUNT='$MOUNT'
TAIL_PID='$TAIL_PID'
SHELL_PID='$SHELL_PID'
MODE='$MODE'
EOF

echo "Demo drive ready at $MOUNT (image $IMAGE)"
echo "  tail -f pid $TAIL_PID holds $MOUNT/notes.txt"
if [ "$MODE" = "terminal" ]; then
    echo "  Terminal window opened with its working directory on the volume (leave it idle)"
elif [ "$MODE" = "terminal-manual" ]; then
    echo "  NOT YET: open Terminal and run: cd '$MOUNT'   (then leave it idle)"
else
    echo "  idle zsh pid ${SHELL_PID:-unknown} has its working directory on the volume"
fi
echo "Check with: .build/debug/phantomtrace $MOUNT"
echo "Reset after a take with: Scripts/demo/teardown-demo.sh && Scripts/demo/setup-demo.sh"
