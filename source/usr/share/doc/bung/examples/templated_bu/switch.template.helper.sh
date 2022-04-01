#! /bin/bash

# Copyright (C) 2020 Charles Atkinson
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA

# Purpose: extends the functionality of bung templated_bu configuration file
#   mikrotik.template.

# Usage:
#   See usage.fun or use -h option

# Programmers' notes: bash library
#   * May be changed by setting environment variable BUNG_LIB_DIR
export BUNG_LIB_DIR=${BUNG_LIB_DIR:-/usr/lib/bung}
source "$BUNG_LIB_DIR/version.scrippet" || exit 1

# Programmers' notes: function call tree
#    +
#    |
#    +-- initialise
#    |   |
#    |   +-- usage
#    |
#    +-- backup_files
#    |
#    +-- edit_export
#    |
#    +-- finalise
#
# Utility functions called from various places:
#    ck_file ck_uint fct msg

# Function definitions in alphabetical order.  Execution begins after the last function definition.

source "$BUNG_LIB_DIR/ck_file.fun" || exit 1
source "$BUNG_LIB_DIR/ck_uint.fun" || exit 1

#--------------------------
# Name: ensure_dir
# Purpose:
#   * Ensures the directory exists with rwx perms for the script
#   * If the last path component does not exist, creates it
#--------------------------
function ensure_dir {
    fct "${FUNCNAME[0]}" 'started'
    local buf chmod_option cmd parent_dir

    # Nothing to do if already as required
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    buf=$(ck_file "$required_dir" d:rwx: 2>&1)
    if [[ $buf = '' ]]; then
        fct "${FUNCNAME[0]}" 'returning'
        return 0
    fi

    # If it does not exist, create it
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ ! -e "$required_dir" ]]; then
        msg I "$required_dir does not exist.  Creating it"
        parent_dir=${required_dir%/*}
        buf=$(ck_file "$parent_dir" d:rwx: 2>&1)
        [[ $buf != '' ]] && msg E "Cannot create $required_dir: $buf"
        cmd=(mkdir "$required_dir")
        run_cmd_with_timeout
        case $? in
            0 )
                fct "${FUNCNAME[0]}" returning
                return 0
                ;;
            1 | 2 )
                fct "${FUNCNAME[0]}" 'returning 1'
                return 1
        esac
    fi

    # Fix the permissions
    # ~~~~~~~~~~~~~~~~~~~
    msg I "$required_dir does not have rwx permissions"
    if [[ -O "$required_dir" ]]; then
        chmod_option=o=rwx
    elif [[ -G "$required_dir" ]]; then
        chmod_option=g=rwx
    else
        msg E "Cannot fix permissions via owner or group: $(ls -l "$required_dir")"
    fi
    cmd=(chmod $chmod_option "$required_dir")
    run_cmd_with_timeout
    case $? in
        0 )
            msg I "$required_dir permissions fixed"
            ;;
        1 | 2 )
            fct "${FUNCNAME[0]}" 'returning 1'
            return 1
    esac

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function ensure_dir

source "$BUNG_LIB_DIR/fct.fun" || exit 1

#--------------------------
# Name: finalise
# Purpose: cleans up and exits
# Arguments:
#    $1  return value
# Return code (on exit):
#   The sum of zero plus
#      1 if any warnings
#      2 if any errors
#      4,8,16 unused
#      32 if terminated by a signal
# Notes:
#   * This is a based on bung's finalise function
#--------------------------
function finalise {
    fct "${FUNCNAME[0]}" "started with args $*"
    local msg my_retval tmp_dir_regex

    finalising_flag=$true

    # Interrupted?  Message and exit return value
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my_retval=0
    if ck_uint "${1:-}" && (($1>128)); then
        interrupt_flag=$true
        ((my_retval+=32))
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
        msg="Finalising on $buf"
        msg E "$msg"    # Returns because finalising_flag is set
    fi

    # Exit return value adjustment
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ $warning_flag ]]; then
        msg I "There was at least one WARNING"
        ((my_retval+=1))
    fi
    if [[ $error_flag ]]; then
        msg I "There was at least one ERROR"
        ((my_retval+=2))
    fi
    [[ $interrupt_flag ]] && msg I 'There was at least one interrupt'
    if ((my_retval==0)) && ((${1:-0}!=0)); then
        msg E 'There was an error not reported in detail (probably by ... || finalise 1)'
        my_retval=2
    fi
    msg I "Exiting with return value $my_retval"

    # Remove temporary directory
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~
    tmp_dir_regex="^$tmp_dir_root/$my_name\..{6}$"
    [[ $tmp_dir_created_flag \
        && ${tmp_dir:-} =~ $tmp_dir_regex \
    ]] && rm -fr "$tmp_dir"

    # Exit
    # ~~~~
    fct "${FUNCNAME[0]}" 'exiting'
    exit $my_retval
}  # end of function finalise

#--------------------------
# Name: initialise
# Purpose: sets up environment, parses command line
# Notes:
#   * This is a based on bung's initialise.1.scrippet
#--------------------------
function initialise {
    local buf emsg msg_part old_IFS host_line_regex ssh_host
    local args opt

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

    # Initialise some environment variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # If these are already set, they are not changed
    export BUNG_TMP_DIR=${BUNG_TMP_DIR:-/run/bung}

    # Initialise some global logic variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    readonly false=
    readonly true=true

    debugging_flag=$false
    error_flag=$false
    finalising_flag=$false
    interrupt_flag=$false
    tmp_dir_created_flag=$false
    warning_flag=$false

    # Initialise some global string variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    readonly msg_lf=$'\n    '
    readonly my_name=${0##*/}
    readonly ssh_config_fn=~/.ssh/config    # @@@@@ required?

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

    # Parse command line
    # ~~~~~~~~~~~~~~~~~~
    args=("$@")
    emsg=
    opt_D_flag=$false
    opt_r_flag=$false
    opt_t_flag=$false
    tmp_dir_root=$BUNG_TMP_DIR
    while getopts :dD:hr:t: opt "$@"
    do
        case $opt in
            d )
                debugging_flag=$true
                ;;
            D )
                opt_D_flag=$true
                required_dir=$OPTARG
                ;;
            h )
                debugging_flag=$false
                usage verbose
                exit 0
                ;;
            r )
                opt_r_flag=$true
                router_FQDN=$OPTARG
                ;;
            t )
                tmp_dir_root=$OPTARG
                opt_t_flag=$true
                ;;
            : )
                emsg+=$msg_lf"Option $OPTARG must have an argument"
                ;;
            * )
                emsg+=$msg_lf"Invalid option '-$OPTARG'"
        esac
    done

    # Check option arguments
    # ~~~~~~~~~~~~~~~~~~~~~~
    # There are no option arguments that can practcably be checked here

    # Test for mandatory options
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~
    [[ ! $opt_D_flag ]] \
        && emsg+=$msg_lf"Option -D is required"

    # Test for mutually exclusive options
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # There are no mutually exclusive options

    # Test for extra arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    shift $(($OPTIND-1))
    if [[ $* != '' ]]; then
        emsg+=$msg_lf"Invalid extra argument(s) '$*'"
    fi

    # Report any command line errors
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ $emsg != '' ]]; then
        emsg+=$msg_lf'(use -h option for help)'
        msg E "$emsg"
    fi

    # Create temporary directory
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~
    # If the mktemplate is changed, tmp_dir_regex in the finalise function
    # may also need to be changed.
    buf=$(mktemp -d "$tmp_dir_root/$my_name.XXXXXX" 2>&1)
    if (($?==0)); then
        tmp_dir=$buf
        tmp_dir_created_flag=$true
        chmod 700 "$tmp_dir"
        msg D "Created temporary directory $tmp_dir"
        out_fn=$tmp_dir/out; rc_fn=$tmp_dir/rc    # For run_cmd_with_timeout
    else
        msg E "Unable to create temporary directory:$buf"
    fi

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function initialise

#--------------------------
# Name: msg
# Purpose: generalised messaging interface
# Arguments:
#    $1 class: E, I or W indicating Error, Information or Warning
#    $2 message text
# Global variables read:
#     my_name
# Global variables written:
#     error_flag
#     warning_flag
# Output: information messages to stdout; the rest to stderr
# Returns:
#   Does not return (calls finalise) when class is E for error
#   Otherwise returns 0
# Notes:
#   * Cannot use bung's msg function because $log_date_format and
#     $subsidiary_mode_flag are not available
#   * This is a based on bung's msg function
#   * Output from this msg function is captured by templated_bu and written
#     to the log
#--------------------------
function msg {
    local class level message_text prefix

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
            level=err
            prefix='ERROR: '
            ;;
        I )
            prefix=
            level=info
            ;;
        W )
            warning_flag=$true
            level=warning
            prefix='WARN: '
            ;;
        * )
            msg E "msg: invalid class '$class': '$*'"
    esac

    # Output
    # ~~~~~~
    message_text="$prefix$message_text"
    if [[ $class = I ]]; then
        printf '%s\n' "$message_text"
    else
        printf '%s\n' " $message_text" >&2
    fi

    # Return or not
    # ~~~~~~~~~~~~~
    if [[ $class = E ]]; then
        [[ ! $finalising_flag ]] && finalise 1
    fi

    return 0
}  #  end of function msg

source "$BUNG_LIB_DIR/run_cmd_with_timeout.fun" || exit

#--------------------------
# Name: usage
# Purpose: prints usage message
#--------------------------
function usage {
    fct "${FUNCNAME[0]}" 'started'
    local msg usage

    # Build the messages
    # ~~~~~~~~~~~~~~~~~~
    usage="usage:
    $my_name -D <dir> [-d] [-h] [-t <tmp_dir>]"
    msg='  where:'
    msg+=$'\n    -D ensures <dir> exists'
    msg+=$'\n       If the last path component does not exist, creates it'
    msg+=$'\n    -d debugging on'
    msg+=$'\n    -h prints this help and exits'
    msg+=$'\n    -t names the temporary directory'
    msg+=$'\n       Default: '"$BUNG_TMP_DIR"

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
ensure_dir
finalise 0
