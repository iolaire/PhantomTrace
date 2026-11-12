#!/bin/bash
# Restores a volume (default: Flash1GB) to the Finder sidebar Locations list
# after it has been hidden (visibility = 1) in FavoriteVolumes.sfl4.
#
# Usage:
#   Scripts/restore-finder-volume-sidebar.sh [VOLUME_NAME]
set -euo pipefail

VOLUME_NAME="${1:-Flash1GB}"
SFL_PATH="$HOME/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.FavoriteVolumes.sfl4"

if [ ! -f "$SFL_PATH" ]; then
    echo "Error: $SFL_PATH not found." >&2
    exit 1
fi

# Stop Finder and sharedfilelistd with SIGKILL first so sharedfilelistd
# does not flush its cached in-memory visibility=1 state back to disk on exit.
killall -9 Finder sharedfilelistd 2>/dev/null || true
sleep 0.3

python3 - "$SFL_PATH" "$VOLUME_NAME" <<'PY'
import plistlib
import sys

sfl_path = sys.argv[1]
vol_name = sys.argv[2]

with open(sfl_path, "rb") as f:
    data = plistlib.load(f)

objs = data["$objects"]

uid_zero = None
for idx, val in enumerate(objs):
    if val == 0 and type(val) is int:
        uid_zero = plistlib.UID(idx)
        break

if uid_zero is None:
    objs.append(0)
    uid_zero = plistlib.UID(len(objs) - 1)

updated = 0
for item_uid in objs[4]["NS.objects"]:
    item = objs[item_uid.data]
    keys = [objs[k.data] for k in item["NS.keys"]]
    vals = [objs[v.data] for v in item["NS.objects"]]
    kv = dict(zip(keys, vals))
    if kv.get("Name") == vol_name and kv.get("visibility") != 0:
        vis_idx = keys.index("visibility")
        item["NS.objects"][vis_idx] = uid_zero
        updated += 1

with open(sfl_path, "wb") as f:
    plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)

print(f"Restored sidebar visibility for '{vol_name}' (entries updated: {updated}).")
PY

killall -9 sharedfilelistd Finder 2>/dev/null || true
sleep 1

# If the volume is currently mounted under /Volumes, remount it (if not busy)
# so Finder refreshes the sidebar entry immediately.
if [ -d "/Volumes/$VOLUME_NAME" ]; then
    DEV_NODE=$(diskutil info "/Volumes/$VOLUME_NAME" | awk '/Device Node:/ {print $3}')
    if [ -n "$DEV_NODE" ]; then
        if diskutil unmount "$DEV_NODE" >/dev/null 2>&1; then
            diskutil mount "$DEV_NODE" >/dev/null
            echo "Remounted /Volumes/$VOLUME_NAME ($DEV_NODE)."
        else
            echo "Note: /Volumes/$VOLUME_NAME is currently in use; sidebar updated without remount."
        fi
    fi
fi
