#!/bin/bash
# Source the script file
source "${BASH_SOURCE%/*}/logr.bash"

script_func() {
    logr warn "$*"
    nested_func
}

nested_func() {
    logr debug "debug shows function stack separated by /"
    # Oct 26 08:47:17  logger_test:nested_func\script_func\main[28953] <Debug>: debug shows function stack separated by /
}

logr start verbose logger_test
# This sets the global $__logr_LOG_NAME to "logger_test"
# Which in turn sets the $__logr_SCRIPT_LOG, in this case "~/logs/logger_test.log"
# can include "quiet" or "verbose" to toggle STDERR output, and/or "clean" to clear the log on start

# logr clear
## clear will empty the specified log in ~/logs

logr info "Just some info (does not go to system.log)"
# Oct 26 08:47:17  logger_test:main[28942] <Info>: Just some info (does not go to system.log)
logr "No level assumes info"
logr info It also works without quoting, if special characters are quoted
logr info Special characters include \", \`, \', \$, \?, \&, \!, \$, \[\\\], etc.
# Oct 26 08:47:17  logger_test:main[28943] <Info>: No level assumes info
# Oct 26 08:47:17  logger_test:main[28944] <Info>: It also works without quoting, if special characters are quoted
# Oct 26 08:47:17  logger_test:main[28945] <Info>: Special characters include ", `, ', $, ?, &, !, $, [\], etc.

logr quiet
# Nothing after logr quiet will go to STDERR, but still goes to script log and system.log
logr debug A debug message does not go to system.log
# Oct 26 08:47:17  logger_test:main[28947] <Debug>: A debug message does not go to system.log

logr notice "notice goes to both system log and script log"
# Oct 26 08:47:17  logger_test:main[28948] <Notice>: notice goes to both system log and script log

logr warn "A WARNING: Everything higher than notice goes to syslog"
# Oct 26 08:47:17  logger_test:main[28949] <Warning>: A WARNING: Everything higher than notice goes to syslog

logr error "Uh oh, an error... that definitely goes to syslog"
# Oct 26 08:47:17  logger_test:main[28950] <Error>: Uh oh, an error... that definitely goes to syslog

logr emerg "Emergency logs to all logs, and broadcasts to all users"
# Even scripts running in the background under another user will cause a message to be shown to any user with a terminal open

script_func "This message comes from inside a function, note the :script_func tag instead of :main"
# Oct 26 08:47:17  logger_test:script_func[28951] <Warning>: This message comes from inside a function, note the :script_func tag instead of :main
