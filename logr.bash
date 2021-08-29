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

	local caller_name="${FUNCNAME[2]:-}${FUNCNAME[2]:+:}${FUNCNAME[1]}"
	# `$FUNCNAME` will reflect 'main' if the caller is the script itself, or 'source' if the caller is a sourced script.
	__logr_caller_name "${caller_name}"

	local verb=log level= color=
	local -i severity=7 # Default log level is 'DEBUG'.
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

		break # Once we hit default case, end the loop.
	esac
	done

	if [[ "${#}" -ge 1 ]]
	then
		# log, notice, info, warn, error set logging level
		# warn and error go to /var/log/system.log as well as logfile
		case "${1:-}" in
			[Dd][Ee][Bb][Uu][Gg])
				severity=7
				shift;;
			[Ii][Nn][Ff][Oo])
				severity=6
				shift;;
			[Nn][Oo][Tt][Ii][Cc][Ee]|[Ll][Oo][Gg])
				severity=5
				shift;;
			[Ww][Aa][Rr][Nn]*)
				severity=4
				shift;;
			[Ee][Rr][Rr]*)
				severity=3
				shift;;
			[Cc][Rr][Ii][Tt][Ii][Cc][Aa][Ll])
				severity=2
				shift;;
			[Aa][Ll][Ee][Rr][Tt]|[Ff][Aa][Tt][Aa][Ll])
				severity=1
				shift;;
			[Ee][Mm][Ee][Rr][Gg]*|[Pp][Aa][Nn][Ii][Cc])
				severity=0
				shift;;
		esac

		if (( severity <= 4 ))
		then # Always notify user of 'Warning' and worse
			local __logr_VERBOSE=true
		elif (( severity >= 6 ))
		then
			# debug and info types show full function stack
			: #caller_name="$(IFS=":"; echo "${FUNCNAME[*]:1}")"
		fi

		# TODO: optargs -t=__bash_it_log_prefix[0]

		level="${__logr_LOG_LEVEL_SEVERITY[${severity}]:-info}"
		color="${__logr_LOG_LEVEL_COLOR[${severity}]:-}"
		__logr_logger "${level}" "${__logr_LOG_NAME}:${caller_name}${caller_tag:+:}${caller_tag:-}" "${*}" "${color}"
	else
		return 0 # nothing to log is "successful".
	fi
}

declare -a __logr_LOG_LEVEL_SEVERITY=(
	[0]='Emergency' # The system is unusable; we will now Panic.
	[1]='Alert' # Fatal, we cannot continue and will now exit.
	[2]='Critical' # Urgent, we cannot continue but will try anyway.
	[3]='Error' # Something is not working at all.
	[4]='Warning' # Something is not as expected.
	[5]='Notice' # Notify user of normal activity.
	[6]='Info' # Nerds only.
	[7]='Debug' # Developer trace information.
)

declare -a __logr_LOG_LEVEL_COLOR=(
	[0]=''
	[1]=''
	[2]=''
	[3]='red'
	[4]='yellow'
	[5]=
	[6]='green'
	[7]='blue'
)

# execute the logger command
# param 1: (string) [log|notice|info|debug|warn|error] log level
# param 2: (string) Tag
# param 3: (string) Message
# param 4: (string) color (name of color defined in environment, e.g. 'red' => $echo_red)
function __logr_logger()
{
	local level="${1:-}" tag="${2:-}" message="${3:-}" color="${4:+echo_}${4:-}"
	local "${color:=echo_none}"="${!color:-}"

	if [[ ${__logr_VERBOSE:-false} == true ]]
	then
		echo -e "${!color}($SECONDS) ${tag}: ${message}${color:+$'\033[0m'}"
	fi

	logger -p "${__logr_FACILITY:-"user"}.${level}" -t "${tag}" -s "${message}" 2>> "${__logr_SCRIPT_LOG}"
}

# Determine the correct caller name, function or script
function __logr_caller_name()
{
	local -i frame=0
	local caller_source=( "${BASH_SOURCE[@]:2}" )
	caller_name=( "${FUNCNAME[@]:2}" )

	# We are ${FUNCNAME[0]}, and `logr()` is ${FUNCNAME[1]}, so start with ${FUNCNAME[2]}:
	while [[ ${caller_name[$frame]:-} ]]
	do
		if [[ ${caller_name[$frame]} == source ]]
		then
			caller_name[$frame]="${caller_source[$frame]##*/}"
			caller_name[$frame]="${caller_name[$frame]%.bash}"
		fi
		(( frame++ ))
	done

	return 0
}
