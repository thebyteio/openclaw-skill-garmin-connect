#!/bin/bash
# Cache today's Garmin metrics to local storage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TODAY=$(date +%Y-%m-%d)
CACHE_DIR="/root/clawd/data/fitness/garmin"
CACHE_FILE="$CACHE_DIR/$TODAY.json"

mkdir -p "$CACHE_DIR"

# Get current stats
STATS=$($SCRIPT_DIR/get-stats.sh 2>/dev/null)

if [ -z "$STATS" ] || echo "$STATS" | grep -q '"error"'; then
  echo "⚠️ Could not fetch Garmin data"
  exit 1
fi

# Add metadata
CACHED=$(echo "$STATS" | jq ". + {cached_at: \"$(date -Iseconds)\", date: \"$TODAY\"}")

# Save to cache
echo "$CACHED" > "$CACHE_FILE"

echo "✅ Cached Garmin data for $TODAY"
echo "$CACHED" | jq -r '[
  "Sleep: " + (.sleep.duration_hours // "N/A" | tostring) + "h",
  "Body Battery: " + (.body_battery.current // "N/A" | tostring) + "%",
  "Stress: " + (.stress.average // "N/A" | tostring),
  "Resting HR: " + (.heart_rate.resting // "N/A" | tostring) + " bpm"
] | join(" | ")'
