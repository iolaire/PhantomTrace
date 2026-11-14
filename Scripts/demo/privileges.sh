#!/bin/bash
# Checks, removes, and helps re-grant the macOS privacy permissions the demo recording needs.
#
#   Scripts/demo/privileges.sh status              does the app running THIS script have them?
#   Scripts/demo/privileges.sh list                the apps this script knows about, and if each is installed
#   Scripts/demo/privileges.sh revoke              dry run: shows what it would remove
#   Scripts/demo/privileges.sh revoke --yes        removes Accessibility, Screen Recording and Terminal
#                                                  automation for the known apps (or the ones you name)
#   Scripts/demo/privileges.sh revoke --yes dev.kiro.desktop      only that app (bundle id)
#   Scripts/demo/privileges.sh grant               opens the two System Settings panes and prints the steps
#
# What can and cannot be automated:
#   - Removing a permission CAN be scripted: `tccutil reset <service> <bundle-id>`. It needs no sudo and no
#     special access, and it only touches your own user's permissions.
#   - Giving a permission CANNOT be scripted. macOS requires you to switch it on in System Settings
#     (it asks for your password or Touch ID). Writing the permission database directly is blocked by
#     System Integrity Protection. `grant` only opens the right panes and tells you what to click.
#
# Safety: `revoke` never runs without --yes, never resets "all apps" (tccutil with no bundle id), and only
# touches bundle ids that are installed. It does not delete anything but the permission entries; the apps
# are not touched. To undo a revoke, switch the permission back on (see `grant`).
set -uo pipefail

# Apps that may run the recording scripts. Add your terminal here if you use another one.
KNOWN_APPS=(
    "dev.kiro.desktop|Kiro"
    "com.amazon.kiro.crew|Kiro Crew"
    "com.apple.Terminal|Terminal"
)
# tccutil service names. Accessibility lets the script click for you, ScreenCapture lets it record the
# screen, AppleEvents is the "control Terminal / Finder" prompt (Automation).
SERVICES=(Accessibility ScreenCapture AppleEvents)

usage() { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; }

is_installed() { # bundle id -> 0 if Launch Services knows an app with it
    local id="$1"
    mdfind "kMDItemCFBundleIdentifier == '$id'" 2>/dev/null | grep -q '\.app$'
}

cmd_list() {
    printf '%-24s %-12s %s\n' "BUNDLE ID" "INSTALLED" "NAME"
    local entry id name state
    for entry in "${KNOWN_APPS[@]}"; do
        id="${entry%%|*}"; name="${entry#*|}"
        if is_installed "$id"; then state="yes"; else state="no"; fi
        printf '%-24s %-12s %s\n' "$id" "$state" "$name"
    done
}

cmd_status() {
    # A tiny compiled check, asked from this very process, so the answer is about the app that launched it.
    local dir src bin
    dir="$(mktemp -d "${TMPDIR:-/tmp}/pt-trust.XXXXXX")"
    trap 'rm -rf "$dir"' RETURN
    src="$dir/trust.swift"; bin="$dir/trust"
    cat > "$src" <<'SWIFT'
import ApplicationServices
import CoreGraphics
print("accessibility:    ", AXIsProcessTrusted() ? "granted" : "NOT granted")
print("screen recording: ", CGPreflightScreenCaptureAccess() ? "granted" : "NOT granted")
SWIFT
    if ! swiftc -O "$src" -o "$bin" 2>/dev/null; then
        echo "error: could not build the check (needs swiftc from the Command Line Tools)" >&2
        return 1
    fi
    echo "Permissions of the app that is running this script:"
    "$bin"
    echo "(Automation of Terminal or Finder cannot be read from a script; it is asked the first time it is used.)"
}

cmd_revoke() {
    local yes=0 ids=() arg
    for arg in "$@"; do
        case "$arg" in
            --yes) yes=1 ;;
            -*) echo "error: unknown option $arg" >&2; return 2 ;;
            *) ids+=("$arg") ;;
        esac
    done
    if [ ${#ids[@]} -eq 0 ]; then
        local entry
        for entry in "${KNOWN_APPS[@]}"; do ids+=("${entry%%|*}"); done
    fi

    local id service failures=0 done_count=0
    for id in "${ids[@]}"; do
        if ! [[ "$id" =~ ^[A-Za-z0-9.-]+$ ]]; then
            echo "skip: '$id' is not a bundle id" >&2; continue
        fi
        if ! is_installed "$id"; then
            echo "skip: $id is not installed"; continue
        fi
        for service in "${SERVICES[@]}"; do
            if [ "$yes" -eq 1 ]; then
                if tccutil reset "$service" "$id" >/dev/null 2>&1; then
                    echo "removed  $service for $id"; done_count=$((done_count + 1))
                else
                    echo "FAILED   $service for $id" >&2; failures=$((failures + 1))
                fi
            else
                echo "would remove $service for $id"
            fi
        done
    done
    if [ "$yes" -eq 0 ]; then
        echo
        echo "Dry run. Nothing was changed. Run again with --yes to remove these."
        return 0
    fi
    echo
    echo "Removed $done_count permission entries. Quit and reopen each affected app so it notices."
    echo "Note: if you run this from an app you just reset, that app loses the permission for its next run."
    echo "Check with: Scripts/demo/privileges.sh status   (run it from the app you care about)"
    return $((failures > 0 ? 1 : 0))
}

cmd_grant() {
    cat <<'EOF'
Giving a permission needs you. macOS will not let a script switch it on. Do this for the app that will run the
recording scripts (Kiro, Kiro Crew, or your terminal):

1. System Settings > Privacy & Security > Accessibility
   - Click +, choose the app (or switch its toggle on if it is listed). Enter your password or use Touch ID.
2. System Settings > Privacy & Security > Screen & System Audio Recording
   - Same: add the app or switch it on.
3. Quit the app completely (Cmd+Q) and open it again. A permission given while an app runs is not seen by it
   until it restarts.
4. Check from that app: Scripts/demo/privileges.sh status
5. The first time a script controls Terminal or Finder, macOS asks "wants to control ...". Click OK. That is
   the Automation permission.

Opening the two panes for you now.
EOF
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
    sleep 1
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture" || true
}

case "${1:-}" in
    status) cmd_status ;;
    list) cmd_list ;;
    revoke) shift; cmd_revoke "$@" ;;
    grant) cmd_grant ;;
    -h|--help|"") usage ;;
    *) echo "error: unknown command '$1'" >&2; usage >&2; exit 2 ;;
esac
