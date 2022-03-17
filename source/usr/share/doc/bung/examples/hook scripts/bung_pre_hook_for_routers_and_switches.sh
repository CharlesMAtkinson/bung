#!/bin/bash

# Purpose
#   * A pre-hook script for use with bung
#   * Test connection with router
#     If OK, message and return $pre_hook_rc_i_continue
#   * Check age of last backup:
#       * If less than max age, message and return $pre_hook_rc_i_finalise
#       * Else message and return $pre_hook_rc_e
#
# Usage: run with -h option or see usage function

# Programmers' notes: bash library
#   * May be changed by setting environment variable BUNG_LIB_DIR
export BUNG_LIB_DIR=${BUNG_LIB_DIR:-/usr/lib/bung}
source "$BUNG_LIB_DIR/version.scrippet" || exit 1

# Function call tree
#    +
#    |
#    +-- initialise
#    |   |
#    |   +-- usage
#    |
#    +-- ck_connection
#    |
#    +-- ck_last_backup_age
#    |
#    +-- finalise
#
# Utility functions called from various places:
#    ck_file ck_uint fct msg

#--------------------------
# Name: ck_connection
# Purpose: checks network connection with the router
#--------------------------
function ck_connection {
    fct "${FUNCNAME[0]}" 'started'
    local cmd i

    cmd=(ping -c 1 -n -q -w 1 "$fqdn")
    for ((i=0;i<10;i++))
    do
        "${cmd[@]}" &> /dev/null
        if (($?==0)); then
            msg I "pinged $fqdn OK"
            finalise $pre_hook_rc_i_continue
        fi
    done
    msg W "Failed connection test (${cmd[*]})"

    fct "${FUNCNAME[0]}" 'returning'
    return 0
}  # end of function ck_connection

source "$BUNG_LIB_DIR/ck_file.fun" || exit 1

#--------------------------
# Name: ck_last_backup_age
# Purpose: checks the age of the last backup file
#--------------------------
function ck_last_backup_age {
    fct "${FUNCNAME[0]}" 'started'
    local buf cmd msg rc

    # Any files in the backup tree younger than max age?
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    cmd=(find "$backup_dir" -type f -mtime -$((max_age+1)))
    buf=$("${cmd[@]}" 2>&1)
    rc=$?
    if ((rc!=0)); then
        msg='Unexpected output from'
        msg+=$'\n'"Command: ${cmd[*]}"
        msg+=$'\n'"Return code: $rc"
        msg+=$'\n'"Output:"
        msg E "$msg"$'\n'"$buf"
    fi
    if [[ $buf = '' ]]; then
        msg E "All files under $backup_dir are older than $max_age days"
    fi
    msg I "Found files under $backup_dir younger than $max_age days"
    finalise $pre_hook_rc_i_finalise
}  # end of function ck_last_backup_age

source "$BUNG_LIB_DIR/ck_uint.fun" || exit 1
source "$BUNG_LIB_DIR/fct.fun" || exit 1

#--------------------------
# Name: finalise
# Purpose: cleans up and exits
# Arguments:
#    $1  return value
# Return code (on exit): 
#    * If terminated by a signal, $pre_hook_rc_e
#    * Otherwise $1
#--------------------------
function finalise {
    fct "${FUNCNAME[0]}" "started with args $*"

    my_retval=$1
    finalising_flag=$true

    # Interrupted?  Message and exit return value
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if ck_uint "${1:-}" && (($1>128)); then
        my_retval=$pre_hook_rc_e
        case $1 in
            129 )
                buf=SIGHUP
                ;;
            130 )
                buf=SIGINT
                ;;
            131 )
                buf=SIGQUIT
                ;;
            132 )
                buf=SIGILL
                ;;
            134 )
                buf=SIGABRT
                ;;
            135 )
                buf=SIGBUS
                ;;
            136 )
                buf=SIGFPE
                ;;
            138 )
                buf=SIGUSR1
                ;;
            139 )
                buf=SIGSEGV
                ;;
            140 )
                buf=SIGUSR2
                ;;
            141 )
                buf=SIGPIPE
                ;;
            142 )
                buf=SIGALRM
                ;;
            143 )
                buf=SIGTERM
                ;;
            146 )
                buf=SIGCONT
                ;;
            147 )
                buf=SIGSTOP
                ;;
            148 )
                buf=SIGTSTP
                ;;
            149 )
                buf=SIGTTIN
                ;;
            150 )
                buf=SIGTTOU
                ;;
            151 )
                buf=SIGURG
                ;;
            152 )
                buf=SIGCPU
                ;;
            153 )
                buf=SIGXFSZ
                ;;
            154 )
                buf=SIGVTALRM
                ;;
            155 )
                buf=SIGPROF
                ;;
            * )
                msg E "${FUNCNAME[0]}: programming error: \$1 ($1) not serviced"
                ;;
        esac
        interrupt_flag=$true
        msg="Finalising on $buf"
        msg E "$msg"    # Returns because finalising_flag is set
    fi

    fct "${FUNCNAME[0]}" 'exiting'
    exit $my_retval
}  # end of function finalise

#--------------------------
# Name: initialise
# Purpose: sets up environment, parses command line, reads config file
#--------------------------
function initialise {
    local array args buf conf_line emsg old_IFS opt opt_f_flag
    local -r fqdn_OK_regex='^[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$'

    # Configure shell environment
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~
    export LANG=en_GB.UTF-8
    export LANGUAGE=en_GB.UTF-8
    for var_name in LC_ADDRESS LC_ALL LC_COLLATE LC_CTYPE LC_IDENTIFICATION \
        LC_MEASUREMENT LC_MESSAGES LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER \
        LC_TELEPHONE LC_TIME 
    do
        unset $var_name
    done

    export PATH=/usr/sbin:/sbin:/usr/bin:/bin
    IFS=$' \n\t'
    set -o nounset
    shopt -s extglob            # Enable extended pattern matching operators
    unset CDPATH                # Ensure cd behaves as expected
    umask 022

    # Initialise some global logic variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    readonly false=
    readonly true=true
    
    debugging_flag=$false
    error_flag=$false
    finalising_flag=$false
    interrupt_flag=$false
    warning_flag=$false

    # Initialise some global string variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    final_msg=
    readonly msg_lf=$'\n    '              # Message linefeed and indent
    readonly my_name=${0##*/}
    readonly pre_hook_rc_e=4
    readonly pre_hook_rc_i_continue=0
    readonly pre_hook_rc_i_finalise=1
    readonly pre_hook_rc_w_continue=2
    readonly pre_hook_rc_w_finalise=3

    # Parse command line
    # ~~~~~~~~~~~~~~~~~~
    args=("$@")
    args_org="$*"
    conf_fn=/home/nc/etc/bung/${my_name%.sh}.conf
    emsg=
    opt_f_flag=$false
    while getopts :c:df:h opt "$@"
    do
        case $opt in
            c )
                conf_fn=$OPTARG
                ;;
            d )
                debugging_flag=$true
                ;;
            f )
                opt_f_flag=$true
                fqdn=$OPTARG
                ;;
            h )
                debugging_flag=$false
                usage verbose
                exit 0
                ;;
            : )
                emsg+=$msg_lf"Option $OPTARG must have an argument"
                [[ $OPTARG = c ]] && { opt_c_flag=$true; conf_fn=/bin/bash; }
                ;;
            * )
                emsg+=$msg_lf"Invalid option '-$OPTARG'"
        esac
    done

    # Check for mandatory options missing
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    [[ ! $opt_f_flag ]] && emsg+=$msg_lf'-r option is required'

    # Test for mutually exclusive options
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # There are no mutually exclusive options

    # Validate option values
    # ~~~~~~~~~~~~~~~~~~~~~~
    if [[ $opt_f_flag && ! ${fqdn:-} =~ $fqdn_OK_regex ]]; then
        emsg+=$msg_lf"Invalid FQDN '$fqdn'"
        emsg+=" (does not match $fqdn_OK_regex)"
    fi
    [[ ! -r "$conf_fn" ]] \
        && emsg+=$msg_lf"$conf_fn does not exist or is not readable"

    # Test for extra arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    shift $(($OPTIND-1))
    if [[ $* != '' ]]; then
        emsg+=$msg_lf"Invalid extra argument(s) '$*'"
    fi

    # Report any errors
    # ~~~~~~~~~~~~~~~~~
    if [[ $emsg != '' ]]; then
        msg E "$emsg"
    fi

    # Set traps
    # ~~~~~~~~~
    trap 'finalise 129' 'HUP'
    trap 'finalise 130' 'INT'
    trap 'finalise 131' 'QUIT'
    trap 'finalise 132' 'ILL'
    trap 'finalise 134' 'ABRT'
    trap 'finalise 135' 'BUS'
    trap 'finalise 136' 'FPE'
    trap 'finalise 138' 'USR1'
    trap 'finalise 139' 'SEGV'
    trap 'finalise 140' 'USR2'
    trap 'finalise 141' 'PIPE'
    trap 'finalise 142' 'ALRM'
    trap 'finalise 143' 'TERM'
    trap 'finalise 146' 'CONT'
    trap 'finalise 147' 'STOP'
    trap 'finalise 148' 'TSTP'
    trap 'finalise 149' 'TTIN'
    trap 'finalise 150' 'TTOU'
    trap 'finalise 151' 'URG'
    trap 'finalise 152' 'XCPU'
    trap 'finalise 153' 'XFSZ'
    trap 'finalise 154' 'VTALRM'
    trap 'finalise 155' 'PROF'

    # Read conffile
    # ~~~~~~~~~~~~~
    conf_line=$(grep "^[[:space:]]*${fqdn//./\\.}:" "$conf_fn" | tail -1)
    [[ $conf_line = '' ]] && msg E "$fqdn not found in $conf_fn"
    old_IFS=$IFS
    IFS=:
    array=($conf_line)
    IFS=$old_IFS
    if ((${#array[*]}!=3)); then
       msg="$conf_fn line does not have three :-separated values"
       msg E "$msg ($conf_line)"
    fi
    backup_dir=${array[1]}
    buf=$(ck_file "$backup_dir" d:rx 2>&1)
    [[ $buf != '' ]] && emsg+=$'\n'$buf
    max_age=${array[2]}
    ck_uint "$max_age" \
        || emsg+=$'\n'"max_age is not an unsigned integer ($max_age)"
    [[ $emsg != '' ]] && msg E "$conf_fn$emsg"
    msg I "Configuration file: $conf_fn"

}  # end of function initialise

#--------------------------
# Name: msg
# Purpose: generalised messaging interface
# Arguments:
#    $1 class: D, E, I or W indicating Debug, Error, Information or Warning
#    $2 message text
# Global variables read:
#     debugging_flag
# Global variables written:
#     error_flag
#     warning_flag
# Output: information messages to stdout; the rest to stderr
# Returns: 
#   Does not return (calls finalise) when class is E for error
#   Otherwise returns 0
#--------------------------
function msg {
    local buf class message_text prefix

    # Process arguments
    # ~~~~~~~~~~~~~~~~~
    class="${1:-}"
    message_text="${2:-}"

    # Class-dependent set-up
    # ~~~~~~~~~~~~~~~~~~~~~~
    case "$class" in  
        D ) 
            [[ ! $debugging_flag ]] && return
            prefix='DEBUG: '
            ;;  
        E ) 
            error_flag=$true
            prefix='ERROR: '
            ;;  
        I ) 
            prefix=
            ;;  
        W ) 
            warning_flag=$true
            prefix='WARN: '
            ;;  
        * ) 
            msg E "msg: invalid class '$class': '$*'"
    esac
    message_text="$prefix$message_text"

    # Write to stdout or stderr
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    message_text="$(date '+%H:%M:%S') $message_text"
    if [[ $class = I ]]; then
        echo "$message_text"
    else
        echo "$message_text" >&2
        if [[ $class = E ]]; then
            # Tell bung script to generate error too
            [[ ! $finalising_flag ]] && finalise $pre_hook_rc_e
        fi
    fi  

    return 0
}  #  end of function msg

#--------------------------
# Name: usage
# Purpose: prints usage message
#--------------------------
function usage {
    fct "${FUNCNAME[0]}" 'started'
    local msg usage

    # Build the messages
    # ~~~~~~~~~~~~~~~~~~
    usage="usage: $my_name "
    msg='  where:'
    usage+='[-c conffile] [-d] -f <FQDN> [-h]'
    msg+=$'\n    -c names the configuration file. Default '"$conf_fn"
    msg+=$'\n       Data lines in configuration file have format:'
    msg+=$'\n       <FQDN>:<backup directory>:<max age in days>'
    msg+=$'\n       <backup directory> may not include a :'
    msg+=$'\n    -d debugging on'
    msg+=$'\n    -f names a switch or router'
    msg+=$'\n    -h prints this help and exits'

    # Display the message(s)
    # ~~~~~~~~~~~~~~~~~~~~~~
    echo "$usage" >&2
    if [[ ${1:-} != 'verbose' ]]; then
        echo "(use -h for help)" >&2
    else
        echo "$msg" >&2
    fi

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function usage

#--------------------------
# Name: main
# Purpose: where it all happens
#--------------------------
initialise "${@:-}"
ck_connection
ck_last_backup_age
msg E 'Programming error: function check_last_backup_age returned'
finalise $pre_hook_rc_e
