#!/bin/bash
# Garmin Connect authentication script

# This script expects the OP_SERVICE_ACCOUNT_TOKEN environment variable to be set
# for 1Password CLI authentication.
# For example: export OP_SERVICE_ACCOUNT_TOKEN=$(cat ~/.config/op/service-account-token)

# The name of the 1Password item containing Garmin Connect credentials.
# Default to "Garmin Connect" or set via environment variable.
GARMIN_1P_ITEM_NAME="${GARMIN_1P_ITEM_NAME:-Garmin Connect}"
GARMIN_1P_VAULT="${GARMIN_1P_VAULT:-Personal}" # Default vault can be 'Personal' or user-defined

# Get credentials from 1Password
EMAIL=$(op item get "$GARMIN_1P_ITEM_NAME" --vault "$GARMIN_1P_VAULT" --fields username 2>/dev/null)
PASSWORD=$(op item get "$GARMIN_1P_ITEM_NAME" --vault "$GARMIN_1P_VAULT" --fields password --reveal 2>/dev/null)

if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
  echo "❌ Garmin credentials not found in 1Password item: '$GARMIN_1P_ITEM_NAME' in vault '$GARMIN_1P_VAULT'."
  echo "Please ensure you have a 1Password login item set up with this title and vault."
  echo "You can set GARMIN_1P_ITEM_NAME and GARMIN_1P_VAULT environment variables if your item name/vault is different."
  exit 1
fi

# Create session directory for storing temporary auth tokens (if used by garminconnect library)
mkdir -p /tmp/garmin-session

# Python script to perform Garmin Connect login
python3 - <<EOF
import sys
import json
from datetime import datetime, timedelta

try:
    from garminconnect import Garmin
    import os

    # Pass credentials via environment variables for the Python script
    os.environ['GARMIN_EMAIL'] = "$EMAIL"
    os.environ['GARMIN_PASSWORD'] = "$PASSWORD"

    EMAIL_PY = os.getenv('GARMIN_EMAIL')
    PASSWORD_PY = os.getenv('GARMIN_PASSWORD')

    AUTH_FILE = '/tmp/garmin-session/garmin_auth.json'

    client = None
    # Check for existing session token
    if os.path.exists(AUTH_FILE):
        try:
            with open(AUTH_FILE, 'r') as f:
                auth_data = json.load(f)
                client = Garmin(auth_data['email'], auth_data['password'], is_cn=auth_data.get('is_cn', False))
                client.garth_login(token=auth_data)
                print("✅ Re-authenticated using existing session token.")
        except Exception as e:
            print(f"Warning: Failed to re-authenticate with token: {e}. Attempting full login.")
            client = None # Reset client to force full login


    if client is None:
        # Perform initial login if no session token or re-auth failed
        print("Attempting initial login...")
        client = Garmin(EMAIL_PY, PASSWORD_PY)
        client.login()

        # Save session token for future use
        garth_token = client.garth.dump()
        with open(AUTH_FILE, 'w') as f:
            json.dump(garth_token, f)

    profile = client.get_full_name()
    print(f"✅ Logged in as: {profile}")


    sys.exit(0)

except ImportError:
    print("❌ garminconnect library not installed")
    print("\nInstall with:")
    print("  pip3 install garminconnect --break-system-packages")
    print("\nOr use Python venv:")
    print("  python3 -m venv ./venv")
    print("  source ./venv/venv/bin/activate")
    print("  pip install garminconnect")
    sys.exit(1)
except Exception as e:
    print(f"❌ Login failed: {e}")
    sys.exit(1)
EOF
