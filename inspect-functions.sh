#! /bin/bash
# Copyright (c) Paul C. Casto
# Released under MIT license

# Source this file in any code where pull-functions has been used to 'instrument' or 'inspect' functions.
# Functions decorated with environment inspection require the variables and functions defined here

# Set these in the environment if you want different behavior
: "${INST_OUTPUT:='./inspect'}"
: "${INST_ENV="$INST_OUTPUT/environment"}"
: "${INST_LOG="$INST_OUTPUT/inspect.log"}"

: "${INST_DIFF='diff'}"
: "${INST_DIFF_OPTIONS='-N -C 1'}"

mkdir -p $INST_OUTPUT
touch $INST_ENV
touch $INST_LOG
export INST_ENV
export INST_LOG

# can set PULL_FUNC_ECHO=inst_echo_log
# that will send to console and to log
inst_echo_log ()
{
	echo $@ | tee $INST_LOG
}

# can set PULL_FUNC_ECHO=inst_log
# that will send just to log
inst_log ()
{
	echo $@ >> $INST_LOG
}

# Define a "method missing" hook
# this does not accomplish the export -f or retry...
# but it does provide an indicator of the functions than need to be added to one of the pull-function calls
command_not_found_handle() {
    local missing_method="$1"
    shift
    local args=("$@")

    echo -e "\nCalled missing method: '$missing_method'"
    #echo "Passed arguments: ${args[*]}"

	# this causes issues if the function is not one that can be pulled in, so commenting out for now.
	# source <(./pull-functions.sh $missing_method)
	# if [[ $? -eq 0 ]]; then
	# 	#export -f $missing_method
	# 	echo "retrying $missing_method"
	# 	$missing_method $args
	# 	local exit_code=$?
	# 	echo "call to $missing_method had exit code of $exit_code"
	# 	return $exit_code
	# fi

    # Return 127 to mimic standard "command not found" exit status
    return 127
}

# Examine the environment but filter out unrelated variables.
# this can be redirected to the log, or output to the console.
# is there a cleaner way? - code duplication here.
show_env () {
	if [[ -v $1 && $1 == 'log' ]]; then
		(set -o posix; set | grep -Pvi $UNRELATED) >> $INST_LOG
	else
		(set -o posix; set | grep -Pvi $UNRELATED)
	fi
}

# keep before and after environment snapshots, and show the differences.
instrument_env () {
	if [[ -e $INST_ENV ]]; then
		mv $INST_ENV $INST_ENV.old
	fi

	show_env > $INST_ENV
	[[ -v $2 && $2 == 'start' ]] && echo -e "vvvvvvvv\n" >> $INST_LOG
	[[ -v $1 ]] && echo -e "\n*** Function or location: $@ ***********\n" >> $INST_LOG
	$INST_DIFF $INST_DIFF_OPTIONS $INST_ENV.old $INST_ENV  >> $INST_LOG
	[[ -v $2 && $2 == 'stop' ]] && echo -e "\n^^^^^^^^^" >> $INST_LOG
}

# maybe not needed, but just in case...
export -f instrument_env
export -f show_env
export -f command_not_found_handle