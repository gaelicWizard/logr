#!/bin/bash
# Logging utility that simplifies user of bash logger command

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
declare __logr_DEFAULT_LOG="scripts"

declare __logr_LOG_NAME=
declare __logr_SCRIPT_LOG=
declare __logr_VERBOSE=
logr() {
	: ${__logr_LOG_DIR:="${HOME}/logs"}
	# default to "user" facility, can be set to local[0-9], etc.
	: ${__logr_FACILITY:=user}
	# default to quiet, no output to STDERR
	: ${__logr_VERBOSE:=false}
	# default log tag and filename to "scripts", changed via logr start command
	: ${__logr_LOG_NAME:=$__logr_DEFAULT_LOG}
	: ${__logr_SCRIPT_LOG:="${__logr_LOG_DIR%/}/${__logr_LOG_NAME}.log"}

	local function_name="${FUNCNAME[1]:-${BASH_SOURCE[1]:-}}"
	local log_type
	
	if [[ ${1:-info} =~ ^(notice|log|info|warn(ing)?|err(or)?|emerg) ]]
	then
		log_type=${1:-info}
		[[ "${1:-}" ]] && shift
	fi

	# start must be called first, initializes logging, sets global log file
	# param 1: (string, optional) [verbose|quiet], verbose echos to STDERR, defaults to quiet
	# param 2: (string, optional) name of log source, defaults to "scripts" (.log will be appended)
	if [[ $log_type == "start" ]]; then
		local should_clean=false
		mkdir -p "${__logr_LOG_DIR:=$__logr_DEFAULT_LOG_DIR}"
		if [[ $1 =~ (^-v$|^verbose$) ]]; then
			__logr_VERBOSE=true
			shift
		elif [[ $1 =~ (^-q$|^quiet$) ]]; then
			__logr_VERBOSE=false
			shift
		else
			__logr_VERBOSE=false
		fi

		if [[ $1 =~ clea[nr] ]]; then
			should_clean=true
			shift
		fi

		if [[ -n "$1" ]]; then
			__logr_LOG_NAME=$1
		fi

		__logr_SCRIPT_LOG="${HOME}/logs/${__logr_LOG_NAME}.log"
		touch $__logr_SCRIPT_LOG
		$should_clean && logr clear
		__logr_exec info $__logr_LOG_NAME "====> BEGIN LOGGING"
	# logr quiet => disables STDERR output
	elif [[ $log_type == "quiet" ]]; then
		__logr_VERBOSE=false
	# logr verbose => enables STDERR output
	elif [[ $log_type == "verbose" ]]; then
		__logr_VERBOSE=true
	# logr clear => clears the log (unless it's the default log)
	elif [[ $log_type == "clear" && $__logr_LOG_NAME != $__logr_DEFAULT_LOG ]]; then
		[[ -n $__logr_SCRIPT_LOG && -f $__logr_SCRIPT_LOG ]] && echo -n > $__logr_SCRIPT_LOG
	# debug type shows full function stack
	elif [[ $log_type == "debug" ]]; then
		function_name=$(IFS="\\"; echo "${FUNCNAME[*]:1}")
		__logr_exec debug "${__logr_LOG_NAME}:${function_name}" "${*:2}"
	# log, notice, info, warn, error set logging level
	# warn and error go to /var/log/system.log as well as logfile
	elif [[ ${log_type:=info} =~ ^(notice|log|info|warn(ing)?|err(or)?|emerg) ]]; then
		local level
		case $log_type in
			notice|log) level="notice" ;;
			info) level="info" ;;
			warn*) level="warning" ;;
			err*) level="err" ;;
			emerg) level="emerg" ;;
			*) level="info" ;;
		esac
		__logr_exec $level "${__logr_LOG_NAME}:${function_name}" "${*:2}"
	# if no type is given, assumes info level
	else
		__logr_exec info "${__logr_LOG_NAME}:${function_name}" "${*:1}"
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
