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
	if [[ ${__logr_scope_depth:-0} -gt ${#BASH_SOURCE[@]} ]]
	then # reset if we're out of scope of the last `start` command.
		unset "${!__logr@}"
	fi

	# Defaults, use `logr start` to specify your own.
	local __logr_DEFAULT_LOG_DIR="${HOME}/Library/Logs"
	local __logr_DEFAULT_LOG="scripts"
	local __logr_SCRIPT_LOG

	local caller_name= caller_tag= verb= level= color=
	local -i severity=6 # Default log level is 'INFO'.
	local -i quiet="${__logr_VERBOSE:=4}" # Don't print to STDERR below 'warning'
	while [[ ${#} -ge 1 ]]
	do case "$1" in
	'start')
		# start should be called first, initializes logging, sets global log file
		# param 1: (string, optional) [verbose|-v|quiet|-q], verbose echos to STDERR, defaults to quiet
		# param 2: (string, optional) name of log source, defaults to "scripts" (.log will be appended)
		shift # start
		#TODO: optargs -q -v -p=path -d=2 depth
		__logr_scope_depth=$(( ${#BASH_SOURCE[@]} ))
		verb="start${verb}"
		;;
	'quiet'|'-q')
		# logr quiet => disables STDERR output
		shift # quiet
		__logr_VERBOSE=2
		;;
	'verbose'|'-v')
		# logr verbose => enables STDERR output
		shift # verbose
		__logr_VERBOSE=7
		;;
	'clea'[nr])
		# logr clear => clears the log (unless it's the default log)
		shift # clean
		verb+=clean
		;;
	*)
		break # Once we hit default case, end the loop.
	esac
	done

	if [[ ${verb:-} == 'start'* ]]
	then
		if [[ ${1:-} ]]
		then
			__logr_LOG_NAME="${1}"
			shift
		fi

		verb="${verb#start}"
	fi

	: "${__logr_LOG_DIR:=${__logr_DEFAULT_LOG_DIR}}"
	[[ -d "$__logr_LOG_DIR" ]] || mkdir -p "$__logr_LOG_DIR"

	: "${__logr_LOG_NAME:=${__logr_DEFAULT_LOG}}"
	__logr_SCRIPT_LOG="${__logr_LOG_DIR%/}/${__logr_LOG_NAME}.log"

	if [[ ${verb:-} == *'clean' ]]
	then
		if [[ $__logr_LOG_NAME != $__logr_DEFAULT_LOG ]]
		then
			: > "$__logr_SCRIPT_LOG"
		fi
		verb="${verb%clean}"
	fi

	if [[ "${#}" -ge 1 ]]
	then verb=log
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

		__logr_caller_name "${__logr_scope_depth:-0}"

		if (( severity > 6 ))
		then
			# Tracing types show full function stack
			caller_name="$(IFS=':'; echo "${caller_name[*]:-}")"
		fi

		# TODO: optargs -t=__bash_it_log_prefix[0]
	fi

	level="${__logr_LOG_LEVEL_SEVERITY[${severity}]:-info}"
	color="${__logr_LOG_LEVEL_COLOR[${severity}]:-}"
	__logr_logger "${level}" "${__logr_LOG_NAME}:${caller_name:-main}${caller_tag:+:}${caller_tag:-}" "${*:-BEGIN LOGGING}" "${color}"
}

declare -a __logr_LOG_LEVEL_SEVERITY=(
	[0]='Emergency' # The system is unusable: Eldritch Panic.
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

	if (( ${__logr_VERBOSE:-0} >= ${severity:-0} ))
	then
		echo -e "${!color}($SECONDS) ${level} ${tag}: ${message}${color:+$'\033[0m'}"
	fi

	logger -p "${__logr_FACILITY:-"user"}.${level}" -t "${tag}" -s "${message}" 2>> "${__logr_SCRIPT_LOG}"
}

# Determine the correct caller name: function or script
# parap 1: (integer) Scope depth (truncate $BASH_SOURCE)
function __logr_caller_name()
{
	local -i frame=0 depth=$(( ${#BASH_SOURCE[@]} - ${1:-0} - 1 ))
		# Reduce $depth by one since `__logr_caller_name()` is one function deeper in the stack then the function that passed in $1.
	local caller_source=( "${BASH_SOURCE[@]:2:$depth}" )
	caller_name=( "${FUNCNAME[@]:2:$depth}" )

	# `$FUNCNAME` will reflect 'main' if the caller is the script itself, or 'source' if the caller is a sourced script.
	# We are `${FUNCNAME[0]}`, and `logr()` is `${FUNCNAME[1]}`, so start with `${FUNCNAME[2]}`:
	while [[ ${caller_name[$frame]:-} ]]
	do
		if [[ ${caller_name[$frame]} == source ]]
		then
			if [[ ${caller_source[$frame]} == ${BASH_SOURCE[$depth]} ]]
			then
				caller_name[$frame]='main'
			else
				caller_name[$frame]="${caller_source[$frame]##*/}"
				caller_name[$frame]="${caller_name[$frame]%.bash}"
			fi
		fi
		(( frame++ ))
	done

	return 0
}
