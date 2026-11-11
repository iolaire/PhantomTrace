#!/bin/bash
# Detect which Kiro surface is running this process, for the "Kiro surface"
# column in docs/ProjectLog.md.
#
#   Scripts/kiro-surface.sh             prints the surface name
#   Scripts/kiro-surface.sh --details   prints: name | version | evidence
#
# Prints one of: Kiro IDE, Kiro CLI, Kiro Web, Kiro Crew, Kiro Mobile, Unknown.
# Set PHANTOMTRACE_KIRO_SURFACE to override (use it for Web, Crew, and Mobile,
# which have no verified environment markers). Always exits 0.
#
# Verified: Kiro IDE (agent shell has TERM_PROGRAM=kiro, KIRO_SESSION_ID, and
# TERM_PROGRAM_VERSION; IDE hook processes carry VSCODE_IPC_HOOK or VSCODE_PID).
# Verified: Kiro Web (agent shell has AWS_SDK_UA_APP_ID=kiro-web and
# KIRO_CUSTOM_USER_AGENT=KiroWeb/<version>). Crew and Mobile still have no known markers.
# Not verified: the Kiro CLI check (parent process named kiro-cli).

surface="Unknown"
version=""
evidence="no Kiro markers found"

valid='Kiro IDE|Kiro CLI|Kiro Web|Kiro Crew|Kiro Mobile'

in_process_chain() {
    # True if an ancestor process command name contains $1.
    local pid=$$ name i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        [ -z "$pid" ] || [ "$pid" = "0" ] || [ "$pid" = "1" ] && return 1
        name=$(ps -o comm= -p "$pid" 2>/dev/null)
        case "$name" in *"$1"*) return 0 ;; esac
    done
    return 1
}

if [ -n "${PHANTOMTRACE_KIRO_SURFACE:-}" ]; then
    if printf '%s' "$PHANTOMTRACE_KIRO_SURFACE" | grep -qxE "$valid|Unknown"; then
        surface="$PHANTOMTRACE_KIRO_SURFACE"
        evidence="PHANTOMTRACE_KIRO_SURFACE override"
    else
        evidence="ignored invalid PHANTOMTRACE_KIRO_SURFACE (use: $valid|Unknown)"
    fi
elif [ "${AWS_SDK_UA_APP_ID:-}" = "kiro-web" ] || case "${KIRO_CUSTOM_USER_AGENT:-}" in KiroWeb/*) true ;; *) false ;; esac; then
    surface="Kiro Web"
    version="${KIRO_CUSTOM_USER_AGENT:-}"
    version="${version#KiroWeb/}"
    version="${version%% *}"
    evidence="AWS_SDK_UA_APP_ID=kiro-web / KIRO_CUSTOM_USER_AGENT=KiroWeb/*"
elif [ "${TERM_PROGRAM:-}" = "kiro" ]; then
    surface="Kiro IDE"
    version="${TERM_PROGRAM_VERSION:-}"
    evidence="TERM_PROGRAM=kiro"
elif [ -z "${TERM_PROGRAM:-}" ] && { [ -n "${VSCODE_IPC_HOOK:-}" ] || [ -n "${VSCODE_PID:-}" ]; }; then
    surface="Kiro IDE"
    evidence="IDE hook process (VSCODE_IPC_HOOK or VSCODE_PID, no TERM_PROGRAM)"
elif in_process_chain "kiro-cli"; then
    surface="Kiro CLI"
    evidence="kiro-cli in parent process chain"
elif [ "$(uname -s)" = "Linux" ]; then
    evidence="Linux host: possibly Kiro Web, Crew, or Mobile; set PHANTOMTRACE_KIRO_SURFACE"
fi

if [ "${1:-}" = "--details" ]; then
    printf '%s | %s | %s\n' "$surface" "${version:-n/a}" "$evidence"
else
    printf '%s\n' "$surface"
fi
exit 0
