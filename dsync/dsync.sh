#!/bin/bash

# todo
# - control synch errors
# - maintenance of log file
# - store manual page separately

function display_help {
    more << EOF

NAME
        dsync - data synchronization tool

SYNAPSIS
        dsync [OPTION]...

DESCRIPTION
        Wrapper around rsync with customization defined in configuration file.
        By default, rsync is called with options -avz --log-file=\$HOME/dsync.log

OPTIONS
        --help, -h                      print this message and exit
        --config-file FILE, -c FILE     use FILE as configuration file instead of the user default one
        --dry-run, d                    do not copy any data, pass the dry run option to rsync
        --path-alias NAME, -p NAME      synchronize only the path alias NAME. See configuration

CONFIGURATION
        Upon installation, a user configuration file is created in \$XDG_CONFIG_HOME/dsync/config.yml.
        The program expects the following structure in the configuration file:

            remotes:
                <remote_name>:
                    url: <remote url>
                    auth: <auth method>
            paths:
                <path alias>:
                    from: <local_path> | <remote_name>:<remote_path>
                    to: <local_path> | <remote_name>:<remote_path>
                    reciprocal: true|false
                    [exclude:
                        - <relative_path>
                        - ...
                        ]

AUTHENTICATION
        The authentication on remotes is based on username and password.
        rsync uses \$USER as the remote username and fetches the password from \$XDG_CONFIG_HOME/dsync/dsync.cred

EXCLUSIONS
        For each path alias, an optional list of regular expressions defining exclusions is passed to rsync. See rsync exclude-from option.


EOF
}

function parse_path {
    local rawpath
    read rawpath
    local parsed_path
    if [[ $rawpath == *:* ]]; then
        local remote="${rawpath%:*}"
        local filter=$(printf '.remotes["%s"].url' "$remote")
        local url=$(yq -r "$filter" $CONFIG_FILE)
        parsed_path=$(echo "$rawpath" | sed "s|$remote:|$url|")
    else
        parsed_path="$rawpath"
    fi
    echo "$(eval echo "$parsed_path")"
}

function get_path_config {
    local key=$1
    local filter=$(printf '.paths["%s"]["%s"]' "$path_alias" "$key")
    config=$(yq -r "$filter" $CONFIG_FILE)
    if [[ $key == "from" || $key == "to" ]]; then
        echo $config | parse_path
    elif [[ $config == "null" ]]; then
        echo ''
    elif [[ $key == "exclude" ]]; then
        yq -r ".[]" <<< $config
    else
        echo "$config"
    fi
}

###
DSYNC_HOME="$XDG_CONFIG_HOME/dsync"
CONFIG_FILE="$DSYNC_HOME/config.yml"
CRED_FILE="$DSYNC_HOME/dsync.cred"
LOG_FILE="$HOME/dsync.log"
EXCLUDE_FILE="/tmp/rsync_exclude"
YQ_ERROR_FILE="/tmp/yq.error"
default_options="-avzc --password-file=$CRED_FILE --log-file=$LOG_FILE --exclude-from=$EXCLUDE_FILE"

# Parse parameters
TEMP=$(getopt -o 'c:dhp:' --longoptions 'config-file:,dry-run,help,path-alias:' -n 'dsync' -- "$@")

if [ $? -ne 0 ]; then
	echo 'Terminating...' >&2
	exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
	case "$1" in
		'-h'|'--help')
			display_help
            exit 0
		;;
		'-c'|'--config-file')
			case "$2" in
				'')
					echo 'ERROR: Missing config-file argument'
                    exit 1
				;;
				*)
                    CONFIG_FILE=$2
				;;
			esac
			shift 2
			continue
		;;
		'-d'|'--dry-run')
            options="$default_options --dry-run"
			shift 1
			continue
		;;
		'-p'|'--path-alias')
			case "$2" in
				'')
					echo 'ERROR: Missing path-alias argument'
                    exit 1
				;;
				*)
					single_path=$2
				;;
			esac
			shift 2
			continue
		;;
		'--')
			shift
			break
		;;
		*)
			echo 'ERROR: Internal error while parsing arguments!' >&2
			exit 1
		;;
	esac
done

# Validations
if [[ ! -f $CONFIG_FILE ]]; then
    echo "ERROR: Config file '$2' does not exist."
    exit 1
fi
{
    paths=$(yq -r '.paths | keys | .[]' $CONFIG_FILE 2> $YQ_ERROR_FILE)
} || {
    echo "ERROR: Malformed config file"
    echo $(<$YQ_ERROR_FILE)
    exit 1
}
if [[ ! -z $single_path ]]; then
    paths=$(grep \^$single_path\$ <<< $paths)
    if [[ -z $paths ]]; then
        echo "ERROR: Path alias '$single_path' not found in config file"
        exit 1
    fi
fi

# Process sequentially all paths configured
while IFS= read -r path_alias; do
    (
        echo "Processing $path_alias"

        from=$(get_path_config "from")
        to=$(get_path_config "to")
        options="$default_options $(get_path_config "options") $cli_options"
        reciprocal=$(get_path_config "reciprocal")
        cat <<< $(get_path_config "exclude") > $EXCLUDE_FILE

        rsync $options $from $to

        if [[ $reciprocal == "true" ]]; then
            rsync $options $to $from
        fi
        
        echo
    )
done <<< $paths
