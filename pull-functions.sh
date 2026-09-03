#! /bin/bash

# depending on the context, the config file may be seen as in the current directory or in the test-snippets directory.
if [[ -f inspect.conf ]]; then
	source inspect.conf
else
    echo "case not handled yet" >&2
    exit 1
fi

# output of the status echo to >&2 so that output can be piped to file
# leading # in the echo, in case the command is run with 2>&1 and the output is intermingled.
#
# source <(./pull-functions.sh decorate function1 function2) to get instrumented coverage
# source <(./pull-functions.sh function3 function4) to get functions without the extra potential noise
# and of course: ./pull-functions.sh function5 function6 >> functions.sh to get a file with the functions extracted

case $1 in
    -h|--help)
        echo "Usage: $0 [-h|--help] [function_name]"
        echo "Extracts functions from the $PULL_FUNC_FILE script."
        echo "If function_name is provided, only that function will be extracted."
        exit 0
        ;;

    list)
        # just the list of functions with leading comments
        grep  -Pzo "(?s)\n?\n(#[^\n]*\n)*[_.[:alnum:]]+\s*\(\)[^\n]*"  $PULL_FUNC_FILE | tr '\000' '\n'
        exit "${PIPESTATUS[1]}" # return the exit code of the grep (first in the pipe).
        ;;

    list-plain)
        # just the list of functions without leading comments
        grep  -P "(?s)^[_.[:alnum:]]+\s*\(\)" $PULL_FUNC_FILE  | sed 's/[[:space:]]*{//' # this will  pick up trailing comments, but not an opening brace.
        exit "${PIPESTATUS[1]}" # return the exit code of the grep (first in the pipe).
        ;;

    decorate) # add entry and exit logging
        DECORATE=1
        shift
        ;;

    instrument) # plus environment logging
        DECORATE=2
        shift
        ;;

    inspect) # plus a pause at the end to allow further investigation
        DECORATE=3
        shift
        ;;

    all)
        DECORATE=0
        FUNC='\w+'  # regex for all functions
        ;;

    *)
        DECORATE=0
        FUNC=$(sed -e 's/^[ ]*//' -e 's/[ ]*$//' -e 's/[ ][ ]*/\|/g' <<< $@) # change spaces to | for regex OR. Although $@ should not have spaces...
        ;;
esac

# because of the need to do delayed interpoalation of the $FUNC variable, we need to use eval to get the correct pattern
# because the greps use the -P option, we cannot use the -E option. At least that's what I've found so far.
# but better all of that than repeating this pattern in 3 different locations...
# a pattern to match a function with leading comments, and the function body, including the closing brace. 
# The (?s) allows it to match newlines, so that .*? can match across multiple lines - with minimal matching. 
# various optional bits to handle cases where function could be a the start of the file, or not have a trailing newline, etc.

exit_code=0
PATTERN='(?s)\n(#[^\n]*\n)*(?:$FUNC)\s*\(\)(?:\s*|\n){.*?\n}(?:\n)?' 
if [ $DECORATE -ge 1 ]; then
    # a bit of 
    echocmd='echo'  # can become a function like log which redirects, etc - TODO should be setable
    # echo "#Decorating functions: $@" >&2
    if [[ $1 == 'all' ]]; then
        shift
        list=$(./pull-functions.sh list-plain) # isn't recursive code so much fun :-)
        names=$(sed -E 's/([_.[:alnum:]]+).*/\1/' <<< $list | tr '\n' ' ') # remove the () and trailing stuff, and change newlines to spaces
        # fill in $@ with the list of all function names, so that we can loop through them and decorate each one.
        set -- $names
    fi

    for FUNC in "$@"; do
        [ $PULL_FUNC_VERBOSE -gt 0 ] && echo "#Processing: $FUNC" >&2
        if [[ "$FUNC" != @($PULL_FUNC_NODECORATE) ]]; then
            [ $PULL_FUNC_VERBOSE -gt 0 ] && echo "#Decorating: $FUNC at level $DECORATE" >&2
            inst_trap=''
            inst_trap_pause=''
            inst_enter=''
            if [[ $DECORATE -ge 2 ]]; then
                inst_trap="; instrument_env $FUNC stop"
                inst_enter="instrument_env $FUNC start"
            fi
            if [[ $DECORATE -eq 3 ]]; then
                inst_trap_pause="; $echocmd \"$FUNC has finished. Press [Enter] key to continue...\"; read -p \"\""
            fi
            trap1="trap '$echocmd \"Return from $FUNC\"$inst_trap$inst_trap_pause' RETURN;"
            trap2="trap 'exit_code=\$?; $echocmd \"EXITING $FUNC with code \$exit_code\"$inst_trap$inst_trap_pause exit \$exit_code;' EXIT;"
            enterfunc="$echocmd 'Entering $FUNC'; echo 'Entering $FUNC' >> $INST_LOG"
            [ $PULL_FUNC_VERBOSE -gt 0 ] && echo "#Extracting: $FUNC" >&2

            PATTERN2=$(eval echo \""${PATTERN}"\")
            grep -Pzo "$PATTERN2" $PULL_FUNC_FILE  | tr '\000' '\n' | \
                sed -E -e 's/([_.[:alnum:]]+\s*\(\))\s*\{/\1\n\{/'  | \
                sed -z "s@\n{@\n{\n$trap1\n$trap2\n$enterfunc\n$inst_enter\n@"
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