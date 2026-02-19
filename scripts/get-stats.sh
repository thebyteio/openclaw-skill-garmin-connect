#!/bin/bash
# Wrapper for Garmin stats Python script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
source venv/bin/activate
python3 scripts/get-stats.py "$@"
