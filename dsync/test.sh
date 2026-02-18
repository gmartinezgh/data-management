#!/bin/bash

set -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
DSYNC_HOME="$HOME/.data-management/dsync"

echo "=== Testing datasync setup ==="
echo ""

# Step 1: Decrypt and set the environment variable
echo "1. Decrypting credential..."
CRED_FILE="$HOME/.config/systemd/user/data-management.cred"
if [ ! -f "$CRED_FILE" ]; then
    echo "ERROR: Credential file not found at $CRED_FILE"
    echo "Make sure to run: sudo $SCRIPT_DIR/setup.sh"
    exit 1
fi

if ! export RSYNC_PASSWORD=$(sudo systemd-creds decrypt "$CRED_FILE" 2>/dev/null); then
    echo "ERROR: Failed to decrypt credential"
    exit 1
fi

echo "✓ Credential decrypted"
echo ""

# Step 2: Verify the variable is set
echo "2. Verifying RSYNC_PASSWORD is set..."
if [ -z "$RSYNC_PASSWORD" ]; then
    echo "ERROR: RSYNC_PASSWORD is not set"
    exit 1
fi

echo "✓ RSYNC_PASSWORD is set (length: ${#RSYNC_PASSWORD})"
echo ""

# Step 3: Run datasync in dry-run mode
echo "3. Running datasync in dry-run mode..."
echo ""
$SCRIPT_DIR/dsync.sh --dry-run
