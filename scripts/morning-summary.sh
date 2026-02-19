#!/bin/bash
# Combined Strava + Garmin morning summary

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get Garmin stats
GARMIN_STATS=$($SCRIPT_DIR/get-stats.sh 2>/dev/null)

if [ -z "$GARMIN_STATS" ] || echo "$GARMIN_STATS" | grep -q "error"; then
  # Garmin data not available, skip
  GARMIN_OK=false
else
  GARMIN_OK=true
fi

# Get Strava training summary
STRAVA_SUMMARY=$(/root/clawd/skills/strava/scripts/training-summary.sh 2>/dev/null)

echo "🏋️🚴 **Morning Training Brief:**"
echo ""

# Garmin metrics (if available)
if [ "$GARMIN_OK" = "true" ]; then
  SLEEP_HOURS=$(echo "$GARMIN_STATS" | jq -r '.sleep.duration_hours // "N/A"')
  SLEEP_SCORE=$(echo "$GARMIN_STATS" | jq -r '.sleep.sleep_score // "N/A"')
  BODY_BATTERY=$(echo "$GARMIN_STATS" | jq -r '.body_battery.current // "N/A"')
  RESTING_HR=$(echo "$GARMIN_STATS" | jq -r '.heart_rate.resting // "N/A"')
  STRESS_AVG=$(echo "$GARMIN_STATS" | jq -r '.stress.average // "N/A"')
  
  # Sleep
  if [ "$SLEEP_HOURS" != "N/A" ] && [ "$SLEEP_HOURS" != "null" ]; then
    if [ "$SLEEP_SCORE" != "N/A" ] && [ "$SLEEP_SCORE" != "null" ]; then
      echo "💤 **Sleep:** ${SLEEP_HOURS}h (score: ${SLEEP_SCORE})"
    else
      echo "💤 **Sleep:** ${SLEEP_HOURS}h"
    fi
  fi
  
  # Body Battery
  if [ "$BODY_BATTERY" != "N/A" ] && [ "$BODY_BATTERY" != "null" ]; then
    if [ $(echo "$BODY_BATTERY > 70" | bc -l) -eq 1 ]; then
      echo "⚡ **Body Battery:** ${BODY_BATTERY}% (good energy!)"
    elif [ $(echo "$BODY_BATTERY > 40" | bc -l) -eq 1 ]; then
      echo "⚡ **Body Battery:** ${BODY_BATTERY}% (moderate)"
    else
      echo "⚡ **Body Battery:** ${BODY_BATTERY}% (low - prioritize recovery)"
    fi
  fi
  
  # Resting HR
  if [ "$RESTING_HR" != "N/A" ] && [ "$RESTING_HR" != "null" ]; then
    echo "❤️ **Resting HR:** ${RESTING_HR} bpm"
  fi
  
  # Stress
  if [ "$STRESS_AVG" != "N/A" ] && [ "$STRESS_AVG" != "null" ]; then
    if [ $(echo "$STRESS_AVG < 30" | bc -l) -eq 1 ]; then
      echo "😌 **Stress:** Low (${STRESS_AVG})"
    elif [ $(echo "$STRESS_AVG < 60" | bc -l) -eq 1 ]; then
      echo "😐 **Stress:** Moderate (${STRESS_AVG})"
    else
      echo "😰 **Stress:** High (${STRESS_AVG}) - consider recovery day"
    fi
  fi
  
  echo ""
fi

# Strava training status
if [ ! -z "$STRAVA_SUMMARY" ]; then
  echo "$STRAVA_SUMMARY"
fi
