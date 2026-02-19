#!/usr/bin/env python3
"""Get current Garmin Connect stats"""

import sys
import json
import os
from datetime import datetime, timedelta
import subprocess

# Add venv to path (adjust this if venv location changes)
# For a publishable skill, this should ideally be handled by the wrapper script activating the venv
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'venv', 'lib', 'python3.12', 'site-packages')) # Dynamic path

try:
    from garminconnect import Garmin, GarminConnectAuthenticationError
except ImportError:
    print(json.dumps({"error": "garminconnect library not installed or venv not activated."}), file=sys.stderr)
    sys.exit(1)

# Centralized authentication logic
def get_garmin_client():
    # Default to generic names for a publishable skill, allow override via env vars
    GARMIN_1P_ITEM_NAME = os.getenv("GARMIN_1P_ITEM_NAME", "Garmin Connect")
    GARMIN_1P_VAULT = os.getenv("GARMIN_1P_VAULT", "Personal")
    OP_SERVICE_ACCOUNT_TOKEN = os.getenv("OP_SERVICE_ACCOUNT_TOKEN")

    if not OP_SERVICE_ACCOUNT_TOKEN:
        print(json.dumps({"error": "OP_SERVICE_ACCOUNT_TOKEN environment variable not set."}), file=sys.stderr)
        sys.exit(1)

    # Fetch credentials from 1Password
    result = subprocess.run(
        ['op', 'item', 'get', GARMIN_1P_ITEM_NAME, '--vault', GARMIN_1P_VAULT, '--format', 'json'],
        capture_output=True, text=True, env={**os.environ, 'OP_SERVICE_ACCOUNT_TOKEN': OP_SERVICE_ACCOUNT_TOKEN}
    )

    if result.returncode != 0:
        print(json.dumps({"error": f"Could not get 1Password item '{GARMIN_1P_ITEM_NAME}': {result.stderr}"}), file=sys.stderr)
        sys.exit(1)

    creds = json.loads(result.stdout)
    email = None
    password = None

    for field in creds['fields']:
        if field.get('id') == 'username':
            email = field.get('value')
        elif field.get('id') == 'password':
            password = field.get('value')

    if not email or not password:
        print(json.dumps({"error": "Garmin Connect credentials (username/password) incomplete in 1Password item."}), file=sys.stderr)
        sys.exit(1)
    
    AUTH_DIR = '/tmp/garmin-session/'
    os.makedirs(AUTH_DIR, exist_ok=True) # Ensure directory exists

    client = None

    # Always perform a full login with this garth version
    try:
        client = Garmin(email, password)
        client.login()
        
        # Save session token to files in AUTH_DIR for potential future use (if garth changes or is implicitly loaded)
        client.garth.dump(dir_path=AUTH_DIR) # Pass the directory path
        # print("DEBUG: Full login successful and token saved.", file=sys.stderr)
    except GarminConnectAuthenticationError as e:
        print(json.dumps({"error": f"Authentication failed: {e}"}), file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": f"Initial login failed: {e}"}), file=sys.stderr)
        sys.exit(1)
            
    return client

def main():
    client = get_garmin_client()
    
    stats = {}
    today = datetime.now().strftime('%Y-%m-%d')
    
    # User profile
    try:
        profile = client.get_full_name()
        stats['name'] = profile
    except Exception as e:
        print(f"DEBUG: Error getting full name: {e}", file=sys.stderr)
    
    # Sleep data (last night)
    try:
        sleep = client.get_sleep_data(today)
        if sleep and 'dailySleepDTO' in sleep:
            sleep_data = sleep['dailySleepDTO']
            stats['sleep'] = {
                'duration_hours': round(sleep_data.get('sleepTimeSeconds', 0) / 3600, 1),
                'deep_sleep_seconds': sleep_data.get('deepSleepSeconds', 0),
                'light_sleep_seconds': sleep_data.get('lightSleepSeconds', 0),
                'rem_sleep_seconds': sleep_data.get('remSleepSeconds', 0),
                'awake_seconds': sleep_data.get('awakeSleepSeconds', 0),
                'sleep_score': sleep_data.get('sleepScores', {}).get('overall', {}).get('value')
            }
    except Exception as e:
        print(f"DEBUG: Error getting sleep data: {e}", file=sys.stderr)
    
    # Body Battery
    try:
        bb = client.get_body_battery(today)
        if bb:
            current_bb = bb[-1] if bb else None
            if current_bb:
                stats['body_battery'] = {
                    'current': current_bb.get('charged', 0),
                    'timestamp': current_bb.get('timestamp')
                }
    except Exception as e:
        print(f"DEBUG: Error getting body battery: {e}", file=sys.stderr)
    
    # Heart rate stats
    try:
        hr_data = client.get_rhr_day(today)
        if hr_data:
            resting_hr_value = hr_data.get('allMetrics', {}).get('metricsMap', {}).get('WELLNESS_RESTING_HEART_RATE', [{}])[0].get('value')
            stats['heart_rate'] = {
                'resting': resting_hr_value
            }
    except Exception as e:
        print(f"DEBUG: Error getting heart rate data: {e}", file=sys.stderr)
    
    # Training status
    try:
        training_status = client.get_training_status(cdate=today)
        if training_status:
            # Dynamically get the device_id
            device_id = None
            if 'mostRecentTrainingStatus' in training_status and \
               'recordedDevices' in training_status['mostRecentTrainingStatus'] and \
               len(training_status['mostRecentTrainingStatus']['recordedDevices']) > 0:
                device_id = str(training_status['mostRecentTrainingStatus']['recordedDevices'][0]['deviceId'])
            
            if device_id:
                status_feedback_phrase = training_status.get('mostRecentTrainingStatus', {}).get('latestTrainingStatusData', {}).get(device_id, {}).get('trainingStatusFeedbackPhrase')
                
                # VO2 Max and Lactate Threshold are complex and often device/sport specific,
                # and not directly available in this simplified get_training_status() response.
                # Leaving them as None for now.
                stats['training_status'] = {
                    'status': status_feedback_phrase,
                    'vo2_max': None,
                    'lactate_threshold': None
                }
            else:
                print(f"DEBUG: Could not determine device_id for training status.", file=sys.stderr)
                stats['training_status'] = {
                    'status': None,
                    'vo2_max': None,
                    'lactate_threshold': None
                }
        else:
            print(f"DEBUG: No training_status data returned by client.get_training_status().", file=sys.stderr)
            stats['training_status'] = {
                'status': None,
                'vo2_max': None,
                'lactate_threshold': None
            }
    except Exception as e:
        print(f"DEBUG: Error getting training status: {e}", file=sys.stderr)

    # Stress data
    try:
        stress = client.get_stress_data(today)
        if stress:
            avg_stress = stress.get('avgStressLevel')
            if avg_stress:
                stats['stress'] = {
                    'average': avg_stress,
                    'max': stress.get('maxStressLevel')
                }
    except Exception as e:
        print(f"DEBUG: Error getting stress data: {e}", file=sys.stderr)
    
    print(json.dumps(stats, indent=2))
    sys.exit(0)

if __name__ == "__main__":
    main()
