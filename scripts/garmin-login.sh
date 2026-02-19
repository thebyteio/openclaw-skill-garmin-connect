#!/bin/bash
# Garmin Connect authentication script

# This script expects the OP_SERVICE_ACCOUNT_TOKEN environment variable to be set
# for 1Password CLI authentication.
# For example: export OP_SERVICE_ACCOUNT_TOKEN=$(cat ~/.config/op/service-account-token)

# Source the virtual environment
source "$(dirname "${BASH_SOURCE[0]}")/../venv/bin/activate"

# The name of the 1Password item containing Garmin Connect credentials.
# Default to "Garmin Connect" or set via environment variable.
GARMIN_1P_ITEM_NAME="${GARMIN_1P_ITEM_NAME:-Garmin Connect}"
GARMIN_1P_VAULT="${GARMIN_1P_VAULT:-Personal}" # Default vault can be 'Personal' or user-defined

# Ensure OP_SERVICE_ACCOUNT_TOKEN is explicitly exported
export OP_SERVICE_ACCOUNT_TOKEN=$(cat ~/.config/op/service-account-token)

# Get credentials from 1Password
EMAIL=$(op item get "$GARMIN_1P_ITEM_NAME" --vault "$GARMIN_1P_VAULT" --fields username)
PASSWORD=$(op item get "$GARMIN_1P_ITEM_NAME" --vault "$GARMIN_1P_VAULT" --fields password --reveal)

if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
  echo "❌ Garmin credentials not found in 1Password item: '$GARMIN_1P_ITEM_NAME' in vault '$GARMIN_1P_VAULT'."
  echo "Please ensure you have a 1Password login item set up with this title and vault."
  echo "You can set GARMIN_1P_ITEM_NAME and GARMIN_1P_VAULT environment variables if your item name/vault is different."
  exit 1
fi

# Create session directory for storing temporary auth tokens (if used by garminconnect library)
# The Python script will save the token files directly here
mkdir -p /tmp/garmin-session

# Python script to perform Garmin Connect login
python - <<EOF
import sys
import json
import os

try:
    from garminconnect import Garmin

    # Pass credentials via environment variables for the Python script FIRST
    os.environ['GARMIN_EMAIL'] = "$EMAIL"
    os.environ['GARMIN_PASSWORD'] = "$PASSWORD"

    # THEN read them from the environment
    EMAIL_PY = os.getenv('GARMIN_EMAIL')
    PASSWORD_PY = os.getenv('GARMIN_PASSWORD')

    AUTH_DIR = '/tmp/garmin-session/'

    client = None
    # Try to re-authenticate by attempting a direct login (no resume, as it seems unsupported)
    try:
        # Directly attempt full login on each run for simplicity with this garth version
        client = Garmin(EMAIL_PY, PASSWORD_PY)
        client.login()
        print("✅ Logged in successfully.")

        # Save session token to files in AUTH_DIR
        client.garth.dump(dir_path=AUTH_DIR)

    except Exception as e:
        print(f"❌ Login failed: {e}")
        sys.exit(1)

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
    print(f"❌ An unexpected error occurred: {e}")
    sys.exit(1)
EOF
