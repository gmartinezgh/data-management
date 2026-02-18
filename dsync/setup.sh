#!/bin/bash

# todo:
# - install custom data management command
# - configure daemon
# - simplify yq calls

set -e

# Get the actual user's home directory when run with sudo
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(eval echo ~$SUDO_USER)
else
    USER_HOME="$HOME"
fi

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
CONFIG_DIR="$USER_HOME/.config"
DSYNC_HOME="$USER_HOME/.config/data-management"
SYSTEMD_DIR="$USER_HOME/.config/systemd"
CREDS_DIR="$SYSTEMD_DIR/user"
CRED_FILE="$CREDS_DIR/data-management.cred"
ENV_DIR="$USER_HOME/.config/environment.d/"
ENV_FILE="$ENV_DIR/data-management.conf"

# Helpers
install_package() {
    local package=$1
    
    if command -v pacman &> /dev/null; then
        pacman -Syu "$package"
    elif command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y "$package"
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y "$package"
    elif command -v apk &> /dev/null; then
        apk add "$package"
    else
        echo "Error: Could not find a supported package manager"
        exit 1
    fi
}

# Create directories ensuring user ownership and no side effects on existing items
create_user_dir() {
    local userdir=$1
    if [ ! -d $userdir ]; then
        mkdir "$userdir"
        if [[ ! -z "$SUDO_COMMAND" ]]; then
            chown $SUDO_USER:$SUDO_USER "$userdir"
        fi
    fi
}

# Install dependencies
declare -a DEPENDENCIES=("rsync" "yq")

for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        install_package "$dep"
    fi
done

# Create config directories and files
create_user_dir $CONFIG_DIR
create_user_dir $DSYNC_HOME
cp "$SCRIPT_DIR/config.yml" "$DSYNC_HOME/"
cp "$SCRIPT_DIR/home_exclusions" "$DSYNC_HOME/"
if [[ ! -z "$SUDO_COMMAND" ]]; then
   chown -R $SUDO_USER:$SUDO_USER "$DSYNC_HOME"
fi
# Eventually the target config file may be modified at setup time
CONFIG_FILE="$DSYNC_HOME/config.yml"
echo "Config files copied to $DSYNC_HOME"

# Check for auth key in config.yml and prompt for environment variable
if [ -f "$CONFIG_FILE" ]; then
    AUTH_VAR=$(yq '.remotes[].auth' "$CONFIG_FILE" 2>/dev/null | head -1 | tr -d '"')
    
    if [ -n "$AUTH_VAR" ] && [ "$AUTH_VAR" != "null" ]; then
        echo "Found auth variable: $AUTH_VAR"
        read -sp "Please enter the value for $AUTH_VAR: " AUTH_VALUE
        echo
        
        # Create systemd user directories
        create_user_dir $SYSTEMD_DIR
        create_user_dir $CREDS_DIR
        create_user_dir $ENV_DIR
        
        # Encrypt and store as systemd credential
        echo -n "$AUTH_VALUE" | systemd-creds encrypt - "$CRED_FILE"
        chmod 600 "$CRED_FILE"
        
        # Create environment file that loads the decrypted credential
        cat > "$ENV_FILE" << EOF
$AUTH_VAR=\${CREDENTIALS_DIRECTORY}/$AUTH_VAR.cred
EOF
        
        echo "Credential encrypted and stored in $CRED_FILE"
        echo "Environment variable configuration written to $ENV_FILE"
        echo ""
    fi
fi




