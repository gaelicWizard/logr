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
	: "${__logr_LOG_DIR:=${__logr_DEFAULT_LOG_DIR:="${HOME}/Library/Logs"}}"
	[[ -d "$__logr_LOG_DIR" ]] || mkdir -p "$__logr_LOG_DIR"

	# default log tag and filename to "scripts", changed via logr start command
	: "${__logr_LOG_NAME:=${__logr_DEFAULT_LOG:="scripts"}}"
	: "${__logr_SCRIPT_LOG:="${__logr_LOG_DIR%/}/${__logr_LOG_NAME}.log"}"

	local caller_name="${FUNCNAME[1]}"
	# `$FUNCNAME` will reflect 'main' if the caller is the script itself, or 'source' if the caller is a sourced script.
	case "${caller_name}" in
	'source')
		caller_name="${BASH_SOURCE[1]##*/}"
		# If the 'function name' is "source", then use the script file name instead.
		;;
	esac

	local verb=log level=info
	while [[ ${#} -ge 1 ]]
	do case "$1" in
		# start must be called first, initializes logging, sets global log file
		# param 1: (string, optional) [verbose|quiet], verbose echos to STDERR, defaults to quiet
		# param 2: (string, optional) name of log source, defaults to "scripts" (.log will be appended)
	'start')
		shift # start
		verb=start
		;;
	'quiet'|'-q')
		# logr quiet => disables STDERR output
		shift # quiet
		__logr_VERBOSE=false
		;;
	'verbose'|'-v')
		# logr verbose => enables STDERR output
		shift # verbose
		__logr_VERBOSE=true
		;;
	'clea'[nr])
		# logr clear => clears the log (unless it's the default log)
		shift # clean
		verb+=clean
		;;
	*)
		if [[ ${verb:-} == 'start'* ]]
		then
			__logr_LOG_NAME="$1"; shift
			__logr_SCRIPT_LOG="${__logr_LOG_DIR}/${__logr_LOG_NAME}.log"
			__logr_logger info "$__logr_LOG_NAME" "====> BEGIN LOGGING"
			verb="${verb#start}"
		fi
		if [[ ${verb:-} == *'clean' ]]
		then
			if [[ $__logr_LOG_NAME != $__logr_DEFAULT_LOG ]]
			then
				: > "$__logr_SCRIPT_LOG"
				__logr_logger info "$__logr_LOG_NAME" "====> CLEARED LOG"
			fi
			verb="${verb%clean}"
		fi

		# log, notice, info, warn, error set logging level
		# warn and error go to /var/log/system.log as well as logfile
		case "${1:-}" in
			[Dd][Ee][Bb][Uu][Gg])
				level="debug"
				# debug type shows full function stack
				caller_name="$(IFS="\\"; echo "${FUNCNAME[*]:1}")"
				shift;;
			[Nn][Oo][Tt][Ii][Cc][Ee]|[Ll][Oo][Gg])
				level="notice"
				shift;;
			[Ii][Nn][Ff][Oo])
				level="info"
				shift;;
			[Ww][Aa][Rr][Nn]*)
				level="warning"
				shift;;
			[Ee][Rr][Rr]*)
				level="err"
				shift;;
			[Ee][Mm][Ee][Rr][Gg]|[Ff][Aa][Tt][Aa][Ll])
				level="emerg"
				shift;;
		esac
		
		break # Once we hit default case, end the loop.
	esac
	done

	if [[ "${#}" -ge 1 ]]
	then
		__logr_logger "${level}" "${__logr_LOG_NAME}:${caller_name}" "${@}"
	else
		return 0 # nothing to log is "successful".
	fi
}

# execute the logger command
# param 1: (string) [log|notice|info|debug|warn|error] log level
# param 2: (string) Tag
# param 3: (string) Message
# param 4: (string) color (terminal escape sequence for `echo -e`)
function __logr_logger()
{
	local level="${1:-}" tag="${2:-}" message="${3:-}" color="${4:-}"
	if [[ ${__logr_VERBOSE:-false} == true ]]
	then
		logger -p "${__logr_FACILITY:-"user"}.${level}" -t "${tag}" -s "${message}" 2>> >(echo -ne "${color}"; tee -a "${__logr_SCRIPT_LOG}"; echo -ne "${color:+$'\033[0m'}")
	else
		logger -p "${__logr_FACILITY:-"user"}.${level}" -t "${tag}" -s "${message}" 2>> "${__logr_SCRIPT_LOG}"
	fi
}
