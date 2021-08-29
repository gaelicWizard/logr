#!/bin/bash
# Logging utility that simplifies use of bash logger command

# # First source the script
# source ~/scripts/logr.bash

# # Start the logger to set options
# logr start [verbose|quiet|...] [LOG_NAME]

# logr [log|notice|info|debug|warn|error] MESSAGE
# # or default to "user.info" facility
# logr MESSAGE

logr()
{
	: "${__logr_LOG_DIR:=${__logr_DEFAULT_LOG_DIR:="${HOME}/Library/Logs"}}"
	# default log tag and filename to "scripts", changed via logr start command
	: "${__logr_LOG_NAME:=${__logr_DEFAULT_LOG:="scripts"}}"
	: "${__logr_SCRIPT_LOG:="${__logr_LOG_DIR%/}/${__logr_LOG_NAME}.log"}"

	local verb="$1"

	local caller_name="${FUNCNAME[1]}"
	case "${caller_name}" in
	'source')
		caller_name="${BASH_SOURCE[1]##*/}"
		# If the 'function name' is "source", then use the script file name instead.
		;;
	esac

	[[ -d "$__logr_LOG_DIR" ]] || mkdir -p "$__logr_LOG_DIR"

	# start must be called first, initializes logging, sets global log file
	# param 1: (string, optional) [verbose|quiet], verbose echos to STDERR, defaults to quiet
	# param 2: (string, optional) name of log source, defaults to "scripts" (.log will be appended)
	if [[ $verb == "start" ]]
	then
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
		__logr_exec info "$__logr_LOG_NAME" "====> BEGIN LOGGING"
	# logr quiet => disables STDERR output
	elif [[ $verb == "quiet" ]]
	then
		__logr_VERBOSE=false
	# logr verbose => enables STDERR output
	elif [[ $verb == "verbose" ]]
	then
		__logr_VERBOSE=true
	# logr clear => clears the log (unless it's the default log)
	elif [[ $verb == "clear" && $__logr_LOG_NAME != $__logr_DEFAULT_LOG ]]
	then
		[[ -n $__logr_SCRIPT_LOG && -f $__logr_SCRIPT_LOG ]] && : > "$__logr_SCRIPT_LOG"
	# debug type shows full function stack
	elif [[ $verb == "debug" ]]
	then
		caller_name="$(IFS="\\"; echo "${FUNCNAME[*]:1}")"
		__logr_exec debug "${__logr_LOG_NAME}:${caller_name}" "${*:2}"
	# log, notice, info, warn, error set logging level
	# warn and error go to /var/log/system.log as well as logfile
	elif [[ $verb =~ ^(notice|log|info|warn(ing)?|err(or)?|emerg) ]]
	then
		local level
		case $verb in
			notice|log) level="notice" ;;
			info) level="info" ;;
			warn*) level="warning" ;;
			err*) level="err" ;;
			emerg) level="emerg" ;;
			*) level="info" ;;
		esac
		__logr_exec $level "${__logr_LOG_NAME}:${caller_name}" "${*:2}"
	# if no type is given, assumes info level
	else
		__logr_exec info "${__logr_LOG_NAME}:${caller_name}" "${*:1}"
	fi
}

# execute the logger command
# param 1: (string) [log|notice|info|debug|warn|error] log level
# param 2: (string) Tag
# param 3: (string) Message
__logr_exec()
{
	local level="${1:-info}" tag="${2:-}" message="${3:-}"
	if [[ ${__logr_VERBOSE:-false} == true ]]
	then
		logger -p "${__logr_FACILITY:-"user"}.${level}" -t "$tag" -s "$message" 2>&1 | tee -a "${__logr_SCRIPT_LOG}" 1>&2
	else
		logger -p "${__logr_FACILITY:-"user"}.${level}" -t "$tag" -s "$message" 2>> "${__logr_SCRIPT_LOG}"
	fi
}
