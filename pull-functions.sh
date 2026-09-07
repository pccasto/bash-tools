#! /bin/bash
# Copyright (c) Paul C. Casto
# Released under MIT license

# if running outside of Linux, requires gnu grep & sed.

# Set these in the environment if you want different behavior
# YMMV -- these are bits of the environment I'm normally not concerned with
# cspell:disable
: "${UNRELATED:=^(?:unrelated|pull_func|__vsc|vscode|git_|diff|inst_|\
gnome|xdg|xmod|ssh|session|ret|qt|wd|ps4|path|suer|uid|termopt|oldpwd|mem|ls_co|\
logname|im_hostname|hist|gtk|gpg|gdm|euid|dbus|colu|color|bash|user|ps1|lang|display|\
host|group|home|mailc|ppid|ps2|opt|vte|line|dir|im_c|systemd|pwd|wayland|xauth|term|shello|\
desktop|ls_opt).*}"
# cspell:enable

# functions to never decorate. these cover abcde, but likely make sense elsewhere
: "${PULL_FUNC_NO_DECORATE:=\w*echo|log}"
# set verbosity of this script - set to 1 to troubleshoot any extraction issues.
: "${PULL_FUNC_VERBOSE:=0}"
# define this as a function if the output needs to be redirected or logged or tee'd
# inspect-functions has inst_log_echo and inst_echo as two possible options
: "${PULL_FUNC_ECHO:=echo}"

# output of the status echo to >&2 so that output can be piped to file
# leading # in the echo, in case the command is run with 2>&1 and the output is intermingled.
#
# ./pull-functions.sh functionA functionB >> functions.sh to get a file with the functions extracted
# or
# ./pull-functions.sh decorate functionA functionB >> functions.st to get a file with decorated functions
# where decorate can be one of: decorate, instrument, or inspect
# or
# source <(./pull-functions.sh functionC functionD) to bring the functions into the current environment
# or 
# source <(./pull-functions.sh decorate function1 function2) to get decorated coverage

case $1 in
    -h|--help)
        cat << EOF
Usage: $0 [-h|--help] [function_name]
    Extracts functions from the the bash file specified by the PULL_FUNC_FILE variable.
    Can invoke with -f filename, or env variable PULL_FUNC_FILE=filename
    If one or more function_names are provided, only those function will be extracted.

    Can decorate the extracted file with start/stop logging, env variable capture and pause at end
        verbs to do so are decorate, instrument, and inspect.

    Can also be used to list (which also extracts leading comments) or list-plain (pulling just the names)
EOF
        exit 0
        ;;
    -f|--file)
        shift
        PULL_FUNC_FILE=$1
        shift
        ;;
esac

if [[ -z "$PULL_FUNC_FILE" ]]; then
    echo "Must provide a filename as --file filename or in env as PULL_FUNC_FILE=filename" >&2
    exit 1
fi
if [[ ! -f $PULL_FUNC_FILE ]]; then
    echo "File $PULL_FUNC_FILE is not readable" >&2
    exit 1
fi

case $1 in
    list)
        # just the list of functions with leading comments
        grep  -Pzo "(?s)\n?\n(#[^\n]*\n)*[_.[:alnum:]]+\s*\(\)[^\n]*" $PULL_FUNC_FILE | tr '\000' '\n'
        exit "${PIPESTATUS[1]}" # return the exit code of the grep (first in the pipe).
        ;;

    list-plain)
        # just the list of functions without leading comments
        grep  -P "(?s)^([_.[:alnum:]]+)(?=\s*\(\))" $PULL_FUNC_FILE  | sed 's/[\([:space:]].*//' # this will  pick up just the names
        exit "${PIPESTATUS[1]}" # return the exit code of the grep (first in the pipe).
        ;;

    decorate) # add function entry/exit logging
        DECORATE=1
        shift
        ;;

    instrument) # plus environment logging
        DECORATE=2
        shift
        ;;

    inspect) # plus a pause at function end to allow further investigation
        DECORATE=3
        shift
        ;;

    all) # extract all functions without decoration - single regex, no need to loop
        DECORATE=0
        FUNC='\w+'  # regex for all functions
        ;;

    *) # extract the listed functions without decoration
        DECORATE=0
        FUNC=$(tr ' ' '|' <<< $@) # change spaces to | for regex OR.
        ;;
esac

# because of the need to do delayed interpolation of the $FUNC variable, we need to use eval to get the correct pattern
# because the greps use the -P option, we cannot use the -E option. At least that's what I've found so far.
# but better all of that than repeating this pattern in 3 different locations...
#
# a pattern to match a function with leading comments, and the function body, including the closing brace. 
# The (?s) allows it to match newlines, so that .*? can match across multiple lines - with minimal matching. 
# various optional bits to handle cases where function could be a the start of the file, or not have a trailing newline, etc.

exit_code=0
PATTERN='(?s)\n(#[^\n]*\n)*(?:$FUNC)\s*\(\)(?:\s*|\n){.*?\n}(?:\n)?' 
if [ $DECORATE -ge 1 ]; then
    # a bit of 
    # echo "#Decorating functions: $@" >&2
    if [[ $1 == 'all' ]]; then
        shift
        # isn't recursive code so much fun :-).  and change newlines to spaces
        names=$(./pull-functions.sh list-plain)  | tr '\n' ' ' 
        # fill in $@ with the list of all function names, so that we can loop through them and decorate each one.
        set -- $names
    fi

    for FUNC in "$@"; do
        [ $PULL_FUNC_VERBOSE -gt 0 ] && echo "#Processing: $FUNC" >&2
        if [[ !  "$FUNC" =~ $PULL_FUNC_NO_DECORATE ]]; then
            [ $PULL_FUNC_VERBOSE -gt 0 ] && echo "#Decorating: $FUNC at level $DECORATE" >&2
            inst_trap=''
            inst_trap_pause=''
            inst_enter=''
            if [[ $DECORATE -ge 2 ]]; then
                inst_trap="; instrument_env $FUNC stop"
                inst_enter="instrument_env $FUNC start"
            fi
            if [[ $DECORATE -eq 3 ]]; then
                # yes, echo below, rather than PULL_FUNC_ECHO, since this always should always go to console
                inst_trap_pause="; echo \"$FUNC has finished. Press [Enter] key to continue...\"; read -p \"\""
            fi
            trap1="trap '\$PULL_FUNC_ECHO \"Return from $FUNC\"$inst_trap$inst_trap_pause' RETURN;"
            trap2="trap 'exit_code=\$?; \$PULL_FUNC_ECHO \"EXITING $FUNC with code \$exit_code\"$inst_trap$inst_trap_pause ;exit \$exit_code;' EXIT;"
            enter_func="\$PULL_FUNC_ECHO 'Entering $FUNC'"
            [ $PULL_FUNC_VERBOSE -gt 0 ] && echo "#Extracting: $FUNC" >&2

            PATTERN2=$(eval echo \""${PATTERN}"\")
            grep -Pzo "$PATTERN2" $PULL_FUNC_FILE  | tr '\000' '\n' | \
                sed -E -e 's/([_.[:alnum:]]+\s*\(\))\s*\{/\1\n\{/'  | \
                sed -z "s@\n{@\n{\n$trap1\n$trap2\n$enter_func\n$inst_enter\n@"
            if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
                echo "Error occurred while extracting function: $FUNC" >&2
                exit_code=1 # set exit_code to 1 if the grep failed, but continue processing.
            fi
        else
            [ $PULL_FUNC_VERBOSE -gt 0 ] && echo "#Extracting: $FUNC" >&2
            PATTERN2=$(eval echo \""${PATTERN}"\")
            grep  -Pzo "$PATTERN2" $PULL_FUNC_FILE  | tr '\000' '\n'
            if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
                echo "Error occurred while extracting function: $FUNC" >&2
                exit_code=1 # set exit_code to 1 if the grep failed, but continue processing.
            fi
        fi          
    done
else
    [ $PULL_FUNC_VERBOSE -gt 0 ] && echo "#Extracting function(s): $FUNC" >&2
    # functions with leading comments
    #echo      "(?s)\n(#[^\n]*\n)*(?:$FUNC)\s*\(\)(?:\s*|\n){.*?\n}\n" $PULL_FUNC_FILE # | tr '\000' '\n'
    PATTERN2=$(eval echo \""${PATTERN}"\")
    grep  -Pzo "$PATTERN2" $PULL_FUNC_FILE  | tr '\000' '\n'
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "Error occurred while extracting function(s): $FUNC" >&2
        exit_code=1 # set exit_code to 1 if the grep failed.
    fi
fi

exit $exit_code