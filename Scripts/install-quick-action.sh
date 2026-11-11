#!/bin/bash
# Install the "Why Can't I Eject?" Finder Quick Action into ~/Library/Services.
#
#   Scripts/install-quick-action.sh
#
# Copies Packaging/QuickAction/Why Can't I Eject?.workflow to "$HOME/Library/Services",
# then refreshes Services with /System/Library/CoreServices/pbs -flush.
# The copy is staged in a hidden directory inside ~/Library/Services (same volume, so the
# final move is a rename) and replaces any installed copy only after staging succeeds.
# If any step fails, the cause is printed to standard error, the exit status is non-zero,
# and a previously installed Quick Action is left as it was.
#
# Environment (mainly for tests):
#   HOME                                    install under this home directory
#   PHANTOMTRACE_SKIP_PBS_FLUSH=1           do not run pbs -flush
#   PHANTOMTRACE_QUICK_ACTION_SOURCE=<dir>  install this .workflow instead of the packaged one
#
# Spec: Requirements 12.8, 12.9, 12.11.
set -u

WORKFLOW_NAME="Why Can't I Eject?.workflow"
PBS="/System/Library/CoreServices/pbs"
HERE="$(cd "$(dirname "$0")" && pwd)" || {
  echo "install-quick-action: cannot locate the script directory" >&2
  exit 1
}
SOURCE="${PHANTOMTRACE_QUICK_ACTION_SOURCE:-$HERE/../Packaging/QuickAction/$WORKFLOW_NAME}"

die() {
  echo "install-quick-action: $1" >&2
  exit 1
}

[ -n "${HOME:-}" ] || die "HOME is not set"
[ -d "$SOURCE" ] || die "Quick Action bundle not found: $SOURCE"
[ -f "$SOURCE/Contents/Info.plist" ] || die "bundle is missing Contents/Info.plist: $SOURCE"
[ -f "$SOURCE/Contents/document.wflow" ] || die "bundle is missing Contents/document.wflow: $SOURCE"

SERVICES_DIR="$HOME/Library/Services"
DEST="$SERVICES_DIR/$WORKFLOW_NAME"

mkdir -p -- "$SERVICES_DIR" || die "cannot create $SERVICES_DIR"

STAGE="$(mktemp -d "$SERVICES_DIR/.phantomtrace-install.XXXXXX")" ||
  die "cannot create a staging directory in $SERVICES_DIR"
cleanup() { rm -rf -- "$STAGE"; }
trap cleanup EXIT

# 1. Stage a full copy. Nothing installed is touched yet.
cp -R -- "$SOURCE" "$STAGE/new.workflow" || die "cannot copy the Quick Action to $STAGE"

# 2. Swap it in. The old copy moves aside (inside STAGE) so it can be restored.
HAD_PREVIOUS=0
if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  mv -- "$DEST" "$STAGE/previous.workflow" ||
    die "cannot move the existing Quick Action aside; it was left in place"
  HAD_PREVIOUS=1
fi

restore_previous() {
  if [ "$HAD_PREVIOUS" -eq 1 ]; then
    rm -rf -- "$DEST"
    if ! mv -- "$STAGE/previous.workflow" "$DEST"; then
      trap - EXIT # keep the staging directory: it holds the only copy of the old Quick Action
      echo "install-quick-action: could not restore the previous Quick Action; it is at $STAGE/previous.workflow" >&2
    fi
  else
    rm -rf -- "$DEST"
  fi
}

if ! mv -- "$STAGE/new.workflow" "$DEST"; then
  restore_previous
  die "cannot install the Quick Action to $DEST"
fi

# 3. Refresh Services. A failure here rolls the install back.
if [ "${PHANTOMTRACE_SKIP_PBS_FLUSH:-}" != "1" ]; then
  if [ ! -x "$PBS" ]; then
    restore_previous
    die "$PBS not found or not executable; the previous Quick Action (if any) was kept"
  fi
  if ! flush_output="$("$PBS" -flush 2>&1)"; then
    restore_previous
    die "pbs -flush failed: $flush_output; the previous Quick Action (if any) was kept"
  fi
fi

echo "Installed: $DEST"
exit 0
