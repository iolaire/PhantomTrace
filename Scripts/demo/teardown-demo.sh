#!/bin/bash
# Undoes Scripts/demo/setup-demo.sh: stops only the helpers it recorded, detaches the demo image without
# force, and deletes it. Leaves the Terminal window alone (close it yourself).
#
# Safety: a recorded pid is signalled only if it still runs the expected program (tail or zsh/sleep).
# If a process or the volume refuses to go, it says so and exits non-zero; it never forces.
set -uo pipefail

DEMO_DIR="${PHANTOMTRACE_DEMO_DIR:-$HOME/PhantomTraceDemo}"
STATE="$DEMO_DIR/state.env"

if [ ! -f "$STATE" ]; then
    echo "Nothing to tear down: $STATE does not exist."
    exit 0
fi
# shellcheck disable=SC1090
. "$STATE"

status=0

stop_if() { # pid, expected command names (regex)
    local pid="$1" expect="$2" comm
    [ -n "$pid" ] || return 0
    if ! kill -0 "$pid" 2>/dev/null; then return 0; fi  # already gone
    if ! comm="$(ps -o comm= -p "$pid" 2>/dev/null)" || [ -z "$comm" ]; then
        echo "could not inspect pid $pid, so it was left running; stop it yourself if it is the demo helper" >&2
        status=1
        return 0
    fi
    comm="$(basename "$comm")"
    if [[ "$comm" =~ $expect ]]; then
        kill "$pid" 2>/dev/null || true
    else
        echo "skipped pid $pid: it is now '$comm', not what the demo started" >&2
    fi
}

stop_if "${TAIL_PID:-}" '^tail$'
stop_if "${SHELL_PID:-}" '^zsh$'
if [ -f "$DEMO_DIR/fifo-holder.pid" ]; then
    stop_if "$(cat "$DEMO_DIR/fifo-holder.pid")" '^sleep$'
    rm -f "$DEMO_DIR/fifo-holder.pid"
fi
sleep 1

# Detach only the volume that this image backs.
# (Capture first: grep -q on a pipe can end it early and trip pipefail.)
INFO="$(hdiutil info 2>/dev/null || true)"
if grep -qF "$IMAGE" <<<"$INFO"; then
    # After PhantomTrace's Eject the volume is unmounted but the image stays attached; detach the
    # whole disk that backs this image (first /dev/diskN line after its image-path).
    TARGET="$MOUNT"
    if [ ! -d "$MOUNT" ]; then
        TARGET="$(awk -v img="$IMAGE" '
            /^image-path/ { found = (index($0, img) > 0) }
            found && $1 ~ /^\/dev\/disk[0-9]+$/ { print $1; exit }' <<<"$INFO")"
    fi
    if [ -z "$TARGET" ] || ! hdiutil detach "$TARGET" >/dev/null 2>&1; then
        echo "The demo volume is still busy at $MOUNT." >&2
        echo "Close the demo Terminal window (cd out of the volume), then run this again." >&2
        exit 1
    fi
fi

rm -f "$IMAGE" "$DEMO_DIR/shell.fifo" "$STATE"
rmdir "$DEMO_DIR" 2>/dev/null || true
if [ "$status" -ne 0 ]; then
    echo "Demo drive removed, but a helper process may still be running (see above)." >&2
    exit "$status"
fi
echo "Demo drive removed."
exit "$status"
