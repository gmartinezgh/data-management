#!/bin/bash

set -e

if [[ -z "$SUDO_COMMAND" ]]; then
    echo "Exit: Installation needs to be executed as sudo"
    exit 0
fi

# Directories and files
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
CONFIG_HOME="$SUDO_HOME/.config"
DSYNC_HOME="$CONFIG_HOME/dsync"
CONFIG_FILE="$DSYNC_HOME/config.yml"
CRED_FILE="$DSYNC_HOME/dsync.cred"
AUTOSTART_DIR="$CONFIG_HOME/autostart"

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

create_user_dir() {
    local userdir=$1
    if [ ! -d $userdir ]; then
        # to ensure user ownership of all directories created and no side effects on existing items
        # neither mkdir -p nor chown -R
        mkdir "$userdir"
        chown $SUDO_USER:$SUDO_USER "$userdir"
    fi
}

# Check for auth key in config.yml and prompt for environment variable
if [[ -f $CONFIG_FILE ]]; then
    
    
    if [[ -n $AUTH_VAR ]] && [[ $AUTH_VAR != 'null' ]]; then
        if [[ -n $(env | grep \^$AUTH_VAR=) ]]; then
            echo "The environment variable $AUTH_VAR already exists, the installation will overwrite it."
            read -p "Do you want to continue? (y/n): " -n 1 -r
            echo    # (optional) move to a new line
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 0
            fi
        fi
        read -sp "Please enter the value for $AUTH_VAR: " AUTH_VALUE
        echo
        create_user_dir $ENV_DIR        
        cat > "$ENV_FILE" <<< "$AUTH_VAR=$AUTH_VALUE"
        chown $SUDO_USER:$SUDO_USER "$ENV_FILE"
        echo "Environment variable configuration written to $ENV_FILE"
    fi
fi

# Install dependencies
declare -a dependencies=("rsync" "yq")

for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        install_package "$dep"
    fi
done

# Copy executable
cp "$SCRIPT_DIR/dsync.sh" /usr/local/bin/dsync

# Create config directories and files
create_user_dir $DSYNC_HOME
cp "$SCRIPT_DIR/config.yml" "$DSYNC_HOME/config.yml"
chown $SUDO_USER:$SUDO_USER "$DSYNC_HOME/config.yml"
cp "$SCRIPT_DIR/dsync.desktop" $AUTOSTART_DIR/dsync.desktop
chown $SUDO_USER:$SUDO_USER "$AUTOSTART_DIR//dsync.desktop"

AUTH_VAR=$(yq '.remotes[].auth' "$CONFIG_FILE" 2>/dev/null | head -1 | tr -d '"')
read -sp "Please enter the value for $AUTH_VAR: " AUTH_VALUE
echo        
cat > $CRED_FILE <<< $AUTH_VALUE
chown $SUDO_USER:$SUDO_USER $CRED_FILE
chmod 400 $CRED_FILE

echo "Config files copied to $DSYNC_HOME"
