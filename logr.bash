#!/bin/bash
#
# Logging utility that simplifies user of posix logger command

# # First source the script
# source ~/scripts/logr.bash

# # Start the logger, generates log name from scripts filename
# logr start
# # or define your own
# logr start LOG_NAME
#
# logr [log|notice|info|debug|warn|error] MESSAGE
# # or default to "user.info" facility
# logr MESSAGE
if [[ "$OSTYPE" == 'darwin'* ]]
then
	__logr_DEFAULT_LOG_DIR="${HOME}/Library/Logs"
else
	__logr_DEFAULT_LOG_DIR="${HOME}/.local/logs"
fi

logr() {
	: ${__logr_LOG_DIR:=${__logr_DEFAULT_LOG_DIR:="${HOME}/Library/Logs"}}
	# default to "user" facility, can be set to local[0-9], etc.
	: ${__logr_FACILITY:=user}
	# default to quiet, no output to STDERR
	: ${__logr_VERBOSE:=false}
	# default log tag and filename to "scripts", changed via logr start command
	: ${__logr_LOG_NAME:=scripts}
	: ${__logr_SCRIPT_LOG:="${__logr_LOG_DIR%/}/${__logr_LOG_NAME}.log"}

	local function_name="${FUNCNAME[1]:-${BASH_SOURCE[1]:-interactive}}"
	local log_type=info OPT= OPTARG= 
	local -a cmd=()
	local -i OPTIND=1 OPTERR=1

	if [[ "${1:-}" == 'start'|clea[nr]|'help' ]]
	do # store initial command and shift
		cmd="${1}"
		#TODO: handle "logr start clear"
		shift
	done

	while getopts "hfpqtv" OPT
	do
		case "${OPT}" in
		h)
			: usage
			;;
		f)
			: set file name
			;;
		p)
			: set priority and optioally facility
			;;
		q)
			: set not-verbose
			;;
		t)
			: set tag
			;;
		v)
			: set verbose
			;;
		*)
			break
			;;
		esac
		shift $((OPTIND-1))
	done

	if [[ "${1:-}" =~ ^(notice|log|info|warn(ing)?|err(or)?|emerg) ]]
	then
		log_type="${1}"
		shift
	else
		log_type='info'
	fi

	# start must be called first, initializes logging, sets global log file
	# param 1: (string, optional) [verbose|quiet], verbose echos to STDERR, defaults to quiet
	# param 2: (string, optional) name of log source, defaults to "scripts" (.log will be appended)
	if [[ "${1:-start}" == "start" ]]
	then
		shift
		local should_clean=false
		mkdir -p "${__logr_LOG_DIR}"
		if [[ "$1" =~ (^-v$|^verbose$) ]]
		then
			__logr_VERBOSE=true
			shift
		elif [[ "$1" =~ (^-q$|^quiet$) ]]
		then
			__logr_VERBOSE=false
			shift
		else
			__logr_VERBOSE=false
		fi

		if [[ "${1:-}" =~ clea[nr] ]]
		then
			should_clean=true
			shift
		fi

		if [[ -n "${1:-}" ]]; then
			__logr_LOG_NAME=$1
		fi

		: ${__logr_SCRIPT_LOG:="${__logr_LOG_DIR}/${__logr_LOG_NAME}.log"}
		touch "$__logr_SCRIPT_LOG"
		$should_clean && logr clear && return # short-circuit
	# logr quiet => disables STDERR output
	elif [[ "$1" == "quiet" ]]
	then
		__logr_VERBOSE=false
		shift
	# logr verbose => enables STDERR output
	elif [[ "$1" == "verbose" ]]
	then
		__logr_VERBOSE=true
		shift
	# logr clear => clears the log (unless it's the default log)
	elif [[ "$1" == "clear" && "$__logr_LOG_NAME" != "$__logr_DEFAULT_LOG" ]]
	then
		[[ -f "$__logr_SCRIPT_LOG" ]] && : > $__logr_SCRIPT_LOG
		shift
	# debug type shows full function stack
	elif [[ "$1" == "debug" ]]
	then
		shift
		function_name=$(IFS="\\"; echo "${FUNCNAME[*]:1}")
	fi

	[[ "${__logr_VERBOSE:-false}" == 'true' ]] && cmd='tee -a'

	if [[ $__logr_VERBOSE == true ]]; then
		logger -p ${__logr_FACILITY}.$1 -t $1 -s $2 2>> >($cmd ${__logr_SCRIPT_LOG})
	else
		logger -p ${__logr_FACILITY}.$1 -t $1 -s $2 2>> ${__logr_SCRIPT_LOG}
	fi
}

# execute the logger command
# param 1: (string) [log|notice|info|debug|warn|error] log level
# param 2: (string) Tag
# param 3: (string) Message
__logr_exec() {
	local cmd
	if [[ $__logr_VERBOSE == true ]]; then
		logger -p ${__logr_FACILITY}.$1 -t $1 -s $2 2>&1 | tee -a ${__logr_SCRIPT_LOG} 1>&2
	else
		logger -p ${__logr_FACILITY}.$1 -t $1 -s $2 2>> ${__logr_SCRIPT_LOG}
	fi
}
