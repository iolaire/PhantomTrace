#!/bin/bash
# Records one short screen clip for a demo scene.
#
#   Scripts/demo/record-clip.sh <scene-id> [seconds]
#   Scripts/demo/record-clip.sh s03-trigger 12
#
# Saves demo/public/clips/<scene-id>.mp4 (H.264, no audio; the narration is separate). Re-running
# replaces that scene's clip only. Scene ids come from demo/scenes.json.
# macOS asks once for Screen Recording permission for your terminal app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ID="${1:-}"
SECONDS_TO_RECORD="${2:-15}"

if [ -z "$ID" ] || ! [[ "$ID" =~ ^[a-z0-9-]+$ ]]; then
    echo "usage: $0 <scene-id> [seconds]   (ids are in demo/scenes.json)" >&2
    exit 2
fi
if ! grep -q "\"id\": *\"$ID\"" "$ROOT/demo/scenes.json"; then
    echo "error: '$ID' is not a scene in demo/scenes.json" >&2
    exit 2
fi
if ! [[ "$SECONDS_TO_RECORD" =~ ^[0-9]+$ ]] || [ "$SECONDS_TO_RECORD" -lt 1 ] || [ "$SECONDS_TO_RECORD" -gt 60 ]; then
    echo "error: seconds must be a whole number from 1 to 60" >&2
    exit 2
fi

OUT_DIR="$ROOT/demo/public/clips"
RAW="$(mktemp -t phantomtrace-clip).mov"
trap 'rm -f "$RAW"' EXIT
mkdir -p "$OUT_DIR"

echo "Recording scene '$ID' for $SECONDS_TO_RECORD s. Get the screen ready."
for n in 3 2 1; do echo "  $n..."; sleep 1; done
echo "  recording"
# -v video, -V seconds, -x no sound (the mic is not used)
screencapture -v -x -V "$SECONDS_TO_RECORD" "$RAW"

ffmpeg -y -loglevel error -i "$RAW" -an -c:v libx264 -pix_fmt yuv420p -crf 18 -r 30 \
    -vf "scale='min(1920,iw)':-2" -movflags +faststart "$OUT_DIR/$ID.mp4"

echo "Saved $OUT_DIR/$ID.mp4"
echo "Next: (cd demo && npm run sync) then npm run studio"
