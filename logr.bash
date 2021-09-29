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
	: "${__logr_VERBOSE:=4}" # Don't print to STDERR below 'warning'
	while [[ ${#} -ge 1 ]]
	do case "$1" in
	'start')
		# start should be called first, initializes logging, sets global log file
		# param 1: (string, optional) [verbose|-v|quiet|-q], verbose echos to STDERR, defaults to quiet
		# param 2: (string, optional) name of log source, defaults to "scripts" (.log will be appended)
		shift # start
		local OPT OPTARG
		local -i OPTIND=1 OPTERR=1
		__logr_scope_depth=$(( ${#BASH_SOURCE[@]} ))
		while getopts "vqd" OPT
		do
			case "${OPT}" in
			d)
				((__logr_scope_depth--))
				;;
			q)
				((__logr_VERBOSE--))
				;;
			v)
				((__logr_VERBOSE++))
				;;
			esac
			shift $((OPTIND-1))
		done
		verb="start${verb}"
		;;
	'quiet')
		# logr quiet => disables STDERR output
		shift # quiet
		__logr_VERBOSE=2
		;;
	'verbose')
		# logr verbose => enables STDERR output
		shift # verbose
		__logr_VERBOSE=7
		;;
	'clea'[nr])
		# logr clear => clears the log (unless it's the default log)
		shift # clean
		verb+=clean
		;;
	'clone')
		# logr clone _new_name => duplicates this function with a new name
		shift # clone
		level="${1?}"
		shift # $level
		local clone="$(declare -f "${FUNCNAME[0]}")"
		eval "${clone/${FUNCNAME[0]} ()/${level}()}"
		verb+=clone
		#TODO: allow `clone` to be used with other verbs
		return # full stop
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

	local -i __logr_VERBOSE="${__logr_VERBOSE:=4}"

	if [[ "${#}" -ge 1 ]]
	then verb=log
		level="${1:-}"
		if [[ "${FUNCNAME[0]}" =~ ^.*[_-]([[:alpha:]]*)$ ]]
		then
			level="${BASH_REMATCH[1]}"
		else
			shift # $level=$1
		fi
		# log, notice, info, warn, error set logging level
		# warn and error go to /var/log/system.log as well as logfile
		case "${level}" in
			[Dd][Ee][Bb][Uu][Gg]|[Tt][Rr][Aa][Cc][Ee])
				severity=7
				;;
			[Ii][Nn][Ff][Oo])
				severity=6
				;;
			[Nn][Oo][Tt][Ii][Cc][Ee]|[Ll][Oo][Gg])
				severity=5
				;;
			[Ww][Aa][Rr][Nn]|[Ww][Aa][Rr][Nn][Ii][Nn][Gg])
				severity=4
				;;
			[Ee][Rr][Rr]|[Ee][Rr][Rr][Oo][Rr])
				severity=3
				;;
			[Cc][Rr][Ii][Tt][Ii][Cc][Aa][Ll])
				severity=2
				;;
			[Aa][Ll][Ee][Rr][Tt]|[Ff][Aa][Tt][Aa][Ll])
				severity=1
				;;
			[Ee][Mm][Ee][Rr][Gg]|[Ee][Mm][Ee][Rr][Gg][Ee][Nn][Cc][Yy]|[Pp][Aa][Nn][Ii][Cc])
				severity=0
				;;
		esac

		local OPT OPTARG
		local -i OPTIND=1 OPTERR=1
		while getopts "vqt:" OPT
		do
			case "${OPT}" in
			q)
				((__logr_VERBOSE--))
				;;
			v)
				((__logr_VERBOSE++))
				;;
			t)
				caller_tag="${OPTARG}"
				;;
			esac
			shift $((OPTIND-1))
		done

		__logr_caller_name "${__logr_scope_depth:-0}"

		if (( severity > 6 ))
		then
			# Tracing types shows three stack frames
			caller_name="${caller_name[2]:-}${caller_name[2]:+:}${caller_name[1]:-}${caller_name[1]:+:}${caller_name[0]}"
		fi

		# TODO: optargs -t=__bash_it_log_prefix[0]
	fi

	#caller_name="${BASH_SOURCE[1]##*/}/${FUNCNAME[1]}"
	level="${_logr_LOG_LEVEL_SEVERITY[severity]:-info}"
	color="${_logr_LOG_LEVEL_COLOR[severity]:-}"
	__logr_logger "${level}" "${__logr_LOG_NAME}: ${caller_name:-default}${caller_tag:+:}${caller_tag:-}" "${*:-BEGIN LOGGING}" "${color}" || true
}

declare -ar _logr_LOG_LEVEL_SEVERITY=(
	[0]='Emergency' # The system is unusable: Eldritch Panic.
	[1]='Alert' # Fatal, we cannot continue and will now exit.
	[2]='Critical' # Urgent, we cannot continue but will try anyway.
	[3]='Error' # Something is not working at all.
	[4]='Warning' # Something is not as expected.
	[5]='Notice' # Notify user of normal activity.
	[6]='Info' # Nerds only.
	[7]='Debug' # Developer trace information.
)

declare -a _logr_LOG_LEVEL_COLOR=(
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

	logger -p "${__logr_FACILITY:-"user"}.${level}" -t "${tag}" -s "${message//[^[:print:]]/}" 2>> "${__logr_SCRIPT_LOG}"
}

# Determine the correct caller name: function or script
# parap 1: (integer) Scope depth (truncate $BASH_SOURCE)
function __logr_caller_name()
{
	local -i frame=0 depth=$(( ${#BASH_SOURCE[@]} - ${1:-0} ))
	local caller_source=( "${BASH_SOURCE[@]:2:$depth}" )
	# `$FUNCNAME` will reflect 'main' if the caller is the script itself, or 'source' if the caller is a sourced script.
	# We are `${FUNCNAME[0]}`, and `logr()` is `${FUNCNAME[1]}`, so start with `${FUNCNAME[2]}`:
	caller_name=( "${FUNCNAME[@]:2:$depth}" )

	while [[ ${caller_name[frame]:-} ]]
	do
		if [[ ${caller_name[frame]} == source ]]
		then
			if [[ ${caller_source[frame]} == ${BASH_SOURCE[depth +1]} ]]
				# Increase $depth by one since `__logr_caller_name()` is one function deeper in the stack then the function that passed in $1.
			then
				caller_name[frame]='main'
			else
				caller_name[frame]="${caller_source[frame]##*/}"
				caller_name[frame]="${caller_name[frame]%.bash}"
			fi
		fi
		(( frame++ ))
	done

	return 0
}
