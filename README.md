# OpenClaw Garmin Connect Skill

## Deep Dive into Your Fitness with Garmin Connect

This OpenClaw skill integrates with Garmin Connect to fetch comprehensive fitness metrics, sleep data, and body battery information. It's designed to provide enhanced training insights and recovery-aware nudges, making your automated assistant even smarter about your personal health and training.

## Features

-   **Training Status:** Get insights into your recovery time, training load, and VO2 max.
-   **Sleep Analysis:** Detailed breakdown of your sleep duration, quality, and stages.
-   **Body Battery:** Track your energy levels throughout the day to optimize activity and rest.
-   **Daily Readiness:** Understand if you're recovered enough for hard training sessions.
-   **Heart Rate Metrics:** Monitor resting heart rate trends and stress levels.
-   **Activity Details:** Access more granular physiological metrics than often available through other platforms like Strava.

## Why Garmin + Strava?

Combining Garmin's physiological data with Strava's social and activity tracking capabilities creates a powerful synergy for smart, personalized nudges.

-   **Strava:** Excels in social features, activity sharing, segments, and ride tracking.
-   **Garmin:** Provides critical physiological metrics, recovery status, sleep quality, and training load.

**The result?** Your OpenClaw agent can provide intelligent, recovery-aware recommendations. For instance, if Strava suggests a hard tempo ride, but Garmin data indicates high fatigue or poor sleep, OpenClaw can adapt its nudge to recommend an easier workout or a rest day.

## Setup Guide

Follow these steps to set up the Garmin Connect skill with your OpenClaw agent.

### 1. Clone the Repository

First, clone this repository to your OpenClaw workspace or desired location:

```bash
git clone https://github.com/thebyteio/openclaw-skill-garmin-connect.git skills/garmin
cd skills/garmin
```

*(Note: Adjust the `skills/garmin` path if you clone it elsewhere.)*

### 2. Install Dependencies

This skill requires Python 3.7+ and the `garminconnect` library. It's highly recommended to use a Python virtual environment to manage dependencies.

```bash
# Option A: Install globally (less recommended)
pip3 install garminconnect --break-system-packages

# Option B: Use a Python Virtual Environment (recommended)
python3 -m venv ./venv
source ./venv/bin/activate
pip install garminconnect
```

### 3. Configure 1Password Credentials

This skill uses the 1Password CLI (`op`) to securely retrieve your Garmin Connect login credentials.

#### 3.1. Install 1Password CLI & Authenticate

Ensure you have the 1Password CLI installed and authenticated with your account. You'll also need to set the `OP_SERVICE_ACCOUNT_TOKEN` environment variable.

For details, refer to the [1Password CLI documentation](https://developer.1password.com/docs/cli/).

```bash
# Example: Export your service account token (replace with your actual token path)
export OP_SERVICE_ACCOUNT_TOKEN=$(cat ~/.config/op/service-account-token)
```

#### 3.2. Create 1Password Login Item

Create a new "Login" item in your 1Password vault (e.g., "Personal" or "Erdma") with the following details:

*   **Title:** `Garmin Connect` (This is the default title the skill looks for. You can choose a custom name if you prefer.)
*   **Username:** Your Garmin Connect email address
*   **Password:** Your Garmin Connect password

#### 3.3. Custom 1Password Item Name or Vault (Optional)

If you chose a custom title for your 1Password item or store it in a different vault, you must set the `GARMIN_1P_ITEM_NAME` and `GARMIN_1P_VAULT` environment variables *before* running any of the skill's scripts.

Example:
```bash
export GARMIN_1P_ITEM_NAME="My Personal Garmin Login"
export GARMIN_1P_VAULT="MyFamilyVault"
```

### 4. Test the Connection

Verify that the skill can successfully log in to your Garmin Connect account:

```bash
./scripts/garmin-login.sh
```

You should see output similar to: `✅ Logged in as: [Your Name]`

### 5. Configure Cache Directory (Optional but Recommended)

The `cache-daily.sh` script saves daily Garmin metrics locally. You can configure where these files are stored. By default, it uses `/root/clawd/data/fitness/garmin`. If you want to change this, you'll need to modify the `CACHE_DIR` variable within `scripts/cache-daily.sh`.

Example `scripts/cache-daily.sh` modification:
```bash
# CACHE_DIR="/root/clawd/data/fitness/garmin" # Default
CACHE_DIR="/path/to/your/custom/cache/"
```

## Usage

Once set up, you can use the following scripts to interact with your Garmin Connect data. Remember to activate your virtual environment (`source ./venv/bin/activate`) if you're not using global dependencies.

### Get Today's Stats

Fetches a summary of your key Garmin metrics for the current day.

```bash
./scripts/get-stats.sh
```

**Returns:**
-   Body battery (current value)
-   Sleep data from last night (duration, score, stages)
-   Resting heart rate
-   Average stress level

### Get Sleep Data

Retrieves detailed sleep data for the last `N` days.

```bash
./scripts/get-sleep.sh [days_back]
# Example: Get sleep data for the last 7 days
./scripts/get-sleep.sh 7
```

**Returns:** Sleep duration, quality, and stages for the specified period.

### Check Recovery Status

Provides an assessment of your current recovery status.

```bash
./scripts/check-recovery.sh
```

**Returns:** An indication of whether you are recovered enough for intense training.

### Cache Daily Metrics

Runs `get-stats.sh` and saves the output to a JSON file in your configured cache directory (`/root/clawd/data/fitness/garmin/` by default). This is useful for trend analysis and reducing API calls.

```bash
./scripts/cache-daily.sh
```

## Configuration

You can customize recovery thresholds and nudge modifications by creating a `config.json` file in the skill's root directory (`skills/garmin/`).

Example `config.json`:

```json
{
  "recovery_thresholds": {
    "body_battery_low": 40,
    "body_battery_good": 70,
    "min_sleep_hours": 6.5,
    "max_recovery_time_hours": 12
  },
  "nudge_modifications": {
    "respect_recovery": true,
    "downgrade_intensity_if_tired": true,
    "skip_gym_if_high_stress": true
  }
}
```

## Integration Examples

### Enhanced Morning Briefing

This skill allows for a richer morning briefing by incorporating physiological data.

**Without Garmin:**
```
🚴 Fitness Update:
Last ride: 2 days ago
This week: 3 rides, 87km
```

**With Garmin:**
```
🚴 Fitness Update:
**Sleep:** 7.5h (good quality, 2h deep)
**Recovery:** ✅ Fully recovered
**Body Battery:** 82% (charged overnight)
**Resting HR:** 48 bpm (normal)

Last ride: 2 days ago
This week: 3 rides, 87km
**Training Status:** Productive (VO2 max: 52)
```

### Smart Nudge Examples

**Scenario 1: Poor Sleep + Hard Workout Day**
-   **Without Garmin:** "Thursday tempo ride time!"
-   **With Garmin:** "You only got 5 hours sleep last night. Maybe take today easy? Light Zone 2 or rest."

**Scenario 2: Recovered + Good Conditions**
-   **Without Garmin:** "Tuesday ride day"
-   **With Garmin:** "Fully recovered (body battery 85%, 8h sleep) + perfect weather. Great day for that tempo ride! 🚴"

**Scenario 3: High Stress Day**
-   **Without Garmin:** "Evening gym time!"
-   **With Garmin:** "Stress level high today (68). Maybe skip gym and prioritize recovery?"

## API Reference

This skill leverages the `garminconnect` Python library to interact with the Garmin Connect API.
Key functions include:
-   `get_stats()`: Daily stats summary
-   `get_sleep_data()`: Sleep metrics
-   `get_body_battery()`: Energy levels
-   `get_training_status()`: Training load, recovery
-   `get_heart_rates()`: Heart rate data

**Rate Limits:** While Garmin does not publish official API rate limits, it's advisable to be reasonable with your queries. Implement caching mechanisms (like `cache-daily.sh`) to avoid spamming the API.

## Privacy and Security

-   ✅ **Credentials stored securely:** Your Garmin Connect username and password are saved in 1Password and never hardcoded in the skill's files.
-   ✅ **Temporary session tokens:** Authentication tokens are cached temporarily in `/tmp/garmin-session/` for efficiency and are not persistent across system restarts unless explicitly configured.
-   ✅ **Data queried on-demand:** Data is fetched from Garmin Connect only when explicitly requested by the skill, not stored long-term within the skill itself. (Note: Your OpenClaw setup might implement long-term caching in a separate data directory, as indicated in `TOOLS.md`, e.g., `/root/clawd/data/fitness/garmin/`).
-   ✅ **No external sharing:** This skill does not share your Garmin Connect data with any third parties.
-   ✅ **Read-only access:** The skill performs read-only operations on your Garmin Connect account. It does not modify any of your activities, settings, or personal information.

## Future Enhancements

-   Correlate sleep quality with work productivity.
-   Predict optimal recovery windows.
-   Implement long-term trend analysis for fitness progress.
-   Integration with other health metrics.
