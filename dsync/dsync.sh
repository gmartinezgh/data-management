#!/bin/bash

# todo
#  - control and log synch errors
# - Simplify yq calls

DSYNC_HOME="$HOME/.config/data-management"
default_options="-avz --log-file=$DSYNC_HOME/rsync.log"

# Parse command-line options
cli_options=""
for arg in "$@"; do
    case $arg in
        --dry-run)
            cli_options="$cli_options --dry-run"
            ;;
        *)
            cli_options="$cli_options $arg"
            ;;
    esac
done

function get_path_config {
    local key=$1
    local filter=$(printf '.paths["%s"]["%s"]' "$path" "$key")
    config=$(yq -r "$filter" $DSYNC_HOME/config.yml)
    if [[ $key == "from" || $key == "to" ]]; then
        echo $config | parse_path
    elif [[ $config == "null" ]]; then
        echo ''
    else
        echo $config
    fi
}


function parse_path {
    local rawpath
    read rawpath
    local path
    if [[ $rawpath == *:* ]]; then
        local remote="${rawpath%:*}"
        local filter=$(printf '.remotes["%s"].url' "$remote")
        local url=$(yq -r "$filter" $DSYNC_HOME/config.yml)
        path=$(echo "$rawpath" | sed "s|$remote:|$url|")
    else
        path="$rawpath"
    fi
    echo "$(eval echo "$path")"
}


# Process sequentially all paths configured
while IFS= read -r path; do
    (
        echo "Processing path: $path"

        from=$(get_path_config "from")
        to=$(get_path_config "to")
        options="$default_options $(get_path_config "options") $cli_options"
        reciprocal=$(get_path_config "reciprocal")

        rsync $options $from $to

        if [[ $reciprocal == "true" ]]; then
            rsync $options $to $from
        fi
    )
done < <(yq -r '.paths | keys | .[]' $DSYNC_HOME/config.yml)
