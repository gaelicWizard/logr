#!/bin/bash
# Logging utility that simplifies use of bash logger command

# # First source the script
# source ~/scripts/logr.bash

# # Start the logger to set options
# logr start [verbose|quiet|...] [LOG_NAME]

# logr [log|notice|info|debug|warn|error] MESSAGE
# # or default to "user.info" facility
# logr MESSAGE

function logr()
{
	local verb="$1"
	local caller_name="${FUNCNAME[1]}"
	# `$FUNCNAME` will reflect 'main' if the caller is the script itself, or 'source' if the caller is a sourced script.

	: "${__logr_LOG_DIR:=${__logr_DEFAULT_LOG_DIR:="${HOME}/Library/Logs"}}"
	[[ -d "$__logr_LOG_DIR" ]] || mkdir -p "$__logr_LOG_DIR"

	# default log tag and filename to "scripts", changed via logr start command
	: "${__logr_LOG_NAME:=${__logr_DEFAULT_LOG:="scripts"}}"
	: "${__logr_SCRIPT_LOG:="${__logr_LOG_DIR%/}/${__logr_LOG_NAME}.log"}"

	case "${caller_name}" in
	'source')
		caller_name="${BASH_SOURCE[1]##*/}"
		# If the 'function name' is "source", then use the script file name instead.
		;;
	esac

	# start must be called first, initializes logging, sets global log file
	# param 1: (string, optional) [verbose|quiet], verbose echos to STDERR, defaults to quiet
	# param 2: (string, optional) name of log source, defaults to "scripts" (.log will be appended)
	case "$verb" in
	'start')
		local should_clean=false
		if [[ $2 =~ (^-v$|^verbose$) ]]
		then
			__logr_VERBOSE=true
			shift
		elif [[ $2 =~ (^-q$|^quiet$) ]]
		then
			__logr_VERBOSE=false
			shift
		fi

		if [[ $2 =~ clea[nr] ]]
		then
			should_clean=true
			shift
		fi

		if [[ -n "$2" ]]
		then
			__logr_LOG_NAME="$2"
		fi

		__logr_SCRIPT_LOG="${__logr_LOG_DIR}/${__logr_LOG_NAME}.log"
		$should_clean && logr clear
		__logr_logger info "$__logr_LOG_NAME" "====> BEGIN LOGGING"
		;;
	'quiet')
	# logr quiet => disables STDERR output
		__logr_VERBOSE=false
		;;
	'verbose')
	# logr verbose => enables STDERR output
		__logr_VERBOSE=true
		;;
	'clear')
	# logr clear => clears the log (unless it's the default log)
		if [[ $__logr_LOG_NAME != $__logr_DEFAULT_LOG && -f $__logr_SCRIPT_LOG ]]
		then
			: > "$__logr_SCRIPT_LOG"
		fi
		;;
	'debug')
	# debug type shows full function stack
		caller_name="$(IFS="\\"; echo "${FUNCNAME[*]:1}")"
		__logr_logger debug "${__logr_LOG_NAME}:${caller_name}" "${*:2}"
		;;
	*)
	# log, notice, info, warn, error set logging level
	# warn and error go to /var/log/system.log as well as logfile
		local level
		case $verb in
			[Dd][Ee][Bb][Uu][Gg])
				level="debug"
				caller_name="$(IFS="\\"; echo "${FUNCNAME[*]:1}")"
				;;
			[Nn][Oo][Tt][Ii][Cc][Ee]|[Ll][Oo][Gg])
				level="notice"
				;;
			[Ii][Nn][Ff][Oo])
				level="info"
				;;
			[Ww][Aa][Rr][Nn]*)
				level="warning"
				;;
			[Ee][Rr][Rr]*)
				level="err"
				;;
			[Ee][Mm][Ee][Rr][Gg]|[Ff][Aa][Tt][Aa][Ll])
				level="emerg"
				;;
			*)
				level="info"
				;;
		esac
		__logr_logger "${level:-info}" "${__logr_LOG_NAME}:${caller_name}" "${*:2}"
		;;
	esac
}

# execute the logger command
# param 1: (string) [log|notice|info|debug|warn|error] log level
# param 2: (string) Tag
# param 3: (string) Message
function __logr_logger()
{
	local level="${1:-info}" tag="${2:-}" message="${3:-}"
	if [[ ${__logr_VERBOSE:-false} == true ]]
	then
		logger -p "${__logr_FACILITY:-"user"}.${level}" -t "$tag" -s "$message" 2>&1 | tee -a "${__logr_SCRIPT_LOG}" 1>&2
	else
		logger -p "${__logr_FACILITY:-"user"}.${level}" -t "$tag" -s "$message" 2>> "${__logr_SCRIPT_LOG}"
	fi
}
