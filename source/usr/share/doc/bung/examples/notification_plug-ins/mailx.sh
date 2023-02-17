#!/bin/bash

# Copyright (C) 2023 Charles Atkinson
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

# Purpose:
#   * Example notification plug-in for the Backup Next Generation (bung) suite
#   * Implements the bung my_mailx function as a plug-in

# Usage (same as all bung notification plug-ins):
#   -b <body> -c <conf_fn> [-l <log_fn>] -s <subject>
#   or
#   -c <conf_fn> -C

# Programmers' notes: function call tree
#    +
#    |
#    +-- initialise
#    |
#    +-- ck_conf
#    |
#    +-- notify
#    |   |
#    |   +-- my_cat
#    |
#    +-- finalise
# 

# Utility functions called from various places:
#     ck_file msg 

# Function definitions in alphabetical order.  Execution begins after the last function definition.

#--------------------------
# Name: ck_conf
# Purpose: check the conffile
# Usage: ck_conf
# Globals
#   Read
#     conf_fn
#   Set
#     email_address_list (by sourcing $conf_fn)
# Returns: 
#   0 when the conffile is OK
#   1 otherwise
#--------------------------
function ck_conf {
    local buf 

    # Email address check regular expression
    # Perfection is not possible, ref https://www.regular-expressions.info/email.html
    local -r email_addr_list_member_re='[A-Za-z0-9._%+-]+([A-Za-z0-9.-]+\.[A-Za-z]{2,4}@)?[^,]+'
    local -r email_addr_list_re="^($email_addr_list_member_re,)*$email_addr_list_member_re$"
   
    # Error messages are indented by '    ' to ease bung log comprehension
    buf=$(grep -Ev '^[[:space:]]*(#|$|(email_address_list|msg_level|log)=)' "$conf_fn" 2>&1)
    continue_on_error_flag=$true
    if [[ $buf = '' ]]; then
        source "$conf_fn"
        [[ ! $email_address_list =~ $email_addr_list_re ]] \
            && msg E "    Invalid email_address_list '$email_address_list'"
    else
        while IFS= read -r line
        do
            msg E "    $line"
        done <<< "$buf"
    fi
    continue_on_error_flag=$false

    [[ $error_flag ]] && return 1 || return 0
}  #  end of function ck_conf

#--------------------------
# Name: ck_file
# Purpose: for each file listed in the argument list: checks that it is 
#   * reachable and exists
#   * is of the type specified (block special, ordinary file or directory)
#   * has the requested permission(s) for the user
#   * optionally, is absolute (begins with /)
# Usage: ck_file [ path <file_type>:<permissions>[:[a]] ] ...
#   where 
#     file  is a file name (path)
#     file_type  is b (block special file), f (file) or d (directory)
#     permissions  is none or more of r, w and x
#     a  requests an absoluteness test (that the path begins with /)
#   Example: ck_file foo d:rwx:
# Outputs:
#   * For the first requested property each file does not have, a message to
#     stderr
#   * For the first detected programminng error, a message to
#     stderr
# Returns: 
#   0 when all files have the requested properties
#   1 when at least one of the files have the requested properties
#   2 when a programming error is detected
#--------------------------
function ck_file {

    local absolute_flag buf file_name file_type perm perms retval

    # For each file ...
    # ~~~~~~~~~~~~~~~~~
    retval=0
    while [[ $# -gt 0 ]]
    do  
        file_name=$1
        file_type=${2%%:*}
        buf=${2#$file_type:}
        perms=${buf%%:*}
        absolute=${buf#$perms:}
        [[ $absolute = $buf ]] && absolute=
        case $absolute in 
            '' | a )
                ;;
            * )
                echo "ck_file: invalid absoluteness flag in '$2' specified for file '$file_name'" >&2
                return 2
        esac
        shift 2

        # Is the file reachable and does it exist?
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        case $file_type in
            b ) 
                if [[ ! -b $file_name ]]; then
                    echo "file '$file_name' is unreachable, does not exist or is not a block special file" >&2
                    retval=1
                    continue
                fi  
                ;;  
            f ) 
                if [[ ! -f $file_name ]]; then
                    echo "file '$file_name' is unreachable, does not exist or is not an ordinary file" >&2
                    retval=1
                    continue
                fi  
                ;;  
            d ) 
                if [[ ! -d $file_name ]]; then
                    echo "directory '$file_name' is unreachable, does not exist or is not a directory" >&2
                    retval=1
                    continue
                fi
                ;;
            * )
                echo "Programming error: ck_file: invalid file type '$file_type' specified for file '$file_name'" >&2
                return 2
        esac

        # Does the file have the requested permissions?
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        buf="$perms"
        while [[ $buf ]]
        do
            perm="${buf:0:1}"
            buf="${buf:1}"
            case $perm in
                r )
                    if [[ ! -r $file_name ]]; then
                        echo "$file_name: no read permission" >&2
                        retval=1
                        continue
                    fi
                    ;;
                w )
                    if [[ ! -w $file_name ]]; then
                        echo "$file_name: no write permission" >&2
                        retval=1
                        continue
                    fi
                    ;;
                x )
                    if [[ ! -x $file_name ]]; then
                        echo "$file_name: no execute permission" >&2
                        retval=1
                        continue
                    fi
                    ;;
                * )
                    echo "Programming error: ck_file: invalid permisssion '$perm' requested for file '$file_name'" >&2
                    return 2
            esac
        done

        # Does the file have the requested absoluteness?
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        if [[ $absolute = a && ${file_name:0:1} != / ]]; then
            echo "$file_name: does not begin with /" >&2
            retval=1
        fi

    done

    return $retval

}  #  end of function ck_file

#--------------------------
# Name: finalise
# Purpose: cleans up and exits
# Arguments:
#   $1  exit code
#--------------------------
function finalise {
    continue_on_error_flag=$true
    exit $1
}  # end of function finalise

#--------------------------
# Name: initialise
# Purpose: sets up environment and parses command line
#--------------------------
function initialise {
    local buf cmd rc
    local optarg opt 
    local emsg=
    local opt_b_flag=$false
    local opt_c_flag=$false
    local opt_C_flag=$false
    local opt_s_flag=$false
    local -r args=("$@")

    # Configure shell environment
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~
    set -o nounset

    # Globals
    # ~~~~~~~
    readonly false=
    readonly true=true

    ck_conf_flag=$false
    continue_on_error_flag=$false
    email_address_list=root
    error_flag=$false
    readonly msg_lf=$'\n    '              # Message linefeed and indent
    readonly script_name=${0##*/}

    # Parse command line
    # ~~~~~~~~~~~~~~~~~~
    # Syntax
    # -b <body> -c <conf_fn> [-l <log_fn>] -s <subject>
    # or
    # -c <conf_fn> -C
    opt_l_flag=$false
    while getopts :b:Cc:l:s: opt "$@"
    do
        case $opt in
            b )
                body=$OPTARG
                opt_b_flag=$true
                ;;
            C )
                conf_check_flag=$true
                opt_C_flag=$true
                ck_conf_flag=$true
                ;;
            c )
                conf_fn=$OPTARG
                opt_c_flag=$true
                ;;
            l )
                log_fn=$OPTARG
                opt_l_flag=$true
                ;;
            s )
                subject=$OPTARG
                opt_s_flag=$true
                ;;
            : )
                emsg+=$msg_lf"Option $OPTARG must have an argument"
                ;;
            * )
                emsg+=$msg_lf"Invalid option '-$OPTARG'"
        esac
    done

    # Test for mutually exclusive options
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ $opt_C_flag ]]; then
        [[ $opt_b_flag ]] && emsg+=$msg_lf"Option -b cannot be used with option -C"
        [[ $opt_l_flag ]] && emsg+=$msg_lf"Option -l cannot be used with option -C"
        [[ $opt_s_flag ]] && emsg+=$msg_lf"Option -s cannot be used with option -C"
    fi  

    # Test for mandatory options missing
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    [[ ! $opt_c_flag ]] && emsg+=$msg_lf'-c option is required'
    if [[ ! $opt_C_flag ]]; then
        [[ ! $opt_b_flag ]] && emsg+=$msg_lf'-b option is required when option -C is not used'
        [[ ! $opt_s_flag ]] && emsg+=$msg_lf'-s option is required when option -C is not used'
    fi 

    # Test option arguments
    # ~~~~~~~~~~~~~~~~~~~~~
    if [[ $opt_l_flag ]]; then
        buf=$(ck_file "$log_fn" f:r 2>&1)
        [[ $buf != '' ]] && emsg+=$msg_lf"Invalid -l option value: $buf"
    fi
    if [[ $opt_c_flag ]]; then
        buf=$(ck_file "$conf_fn" f:r 2>&1)
        [[ $buf != '' ]] && emsg+=$msg_lf"Invalid -c option value: $buf"
    fi

    # Test for extra arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    shift $(($OPTIND-1))
    if [[ $* != '' ]]; then
        emsg+=$msg_lf"Invalid extra argument(s) '$*'"
    fi

    [[ $emsg != '' ]] && msg E "$emsg"

    # Check the conffile
    # ~~~~~~~~~~~~~~~~~~
    ck_conf || finalise 1

    # Nothing more to do?
    # ~~~~~~~~~~~~~~~~~~~   
    [[ $ck_conf_flag ]] && finalise 0

    # Get the conf
    # ~~~~~~~~~~~~
    source "$conf_fn"

}  # end of function initialise

#--------------------------
# Name: msg
# Purpose: generalised messaging interface
# Arguments:
#    $1 class: D, E, I or W indicating Debug, Error, Information or Warning
#    $2 message text
# Global variables read:
#     script_name
# Output: information messages to stdout; the rest to stderr
# Returns: 
#   Does not return (calls finalise) when class is E for error
#   Otherwise returns 0
#--------------------------
function msg {
    local buf class i prefix

    # Process arguments
    # ~~~~~~~~~~~~~~~~~
    class="${1:-}"
    message_text="${2:-}"
    [[ ! ${3:-} =~ '' ]] && msg E "Programming error: ${FUNCNAME[0]}: invalid third argument '${3:-}'"

    # Class-dependent set-up
    # ~~~~~~~~~~~~~~~~~~~~~~
    case "$class" in  
        E ) 
            error_flag=$true
            prefix='For bung E '
            ;;  
        I ) 
            prefix='For bung I '
            ;;  
        W ) 
            warning_flag=$true
            prefix='For bung W '
            ;;  
        * ) 
            msg E "Programming error: ${FUNCNAME[0]}: invalid class '$class': '$*'"
    esac

    # Write to stdout or stderr
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    message_text="$prefix$message_text"
    if [[ $class = I ]]; then
        echo "$message_text"
    else
        echo "$message_text" >&2
        if [[ $class = E ]]; then
            [[ ! $continue_on_error_flag ]] && finalise 1 
        fi
    fi  

    return 0
}  #  end of function msg

#--------------------------
# Name: my_cat
# Purpose: 
#   Same as "cat FILE" (where FILE is not -) except when FILE is > 500,000 bytes.
#   When FILE ($1) is > 500,000 bytes, excerpt the most relevant lines.
# Arguments:
#   $1 - pathname of input file
# Global variable usage: none
# Output: normally as described under "Purpose" above; error messages on stderr
# Return value: 1 when an error is detected, 0 otherwise
# Usage notes:
#--------------------------
function my_cat {
    local buf fn=${1:-} rc size
    local -r max_size=500000

    # Argument error trap
    # ~~~~~~~~~~~~~~~~~~~
    if [[ $fn = '' ]]; then
        echo "Programming error: $script_name, called ${FUNCNAME[0]} with $1 not set" >&2
        return 1
    fi

    # Get size of the input file
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~
    size=$(stat --printf=%s "$fn" 2>&1)
    if (($?>0)); then
        echo "$script_name: unable to stat '$fn': $size" >&2
        return 1
    fi

    # Output
    # ~~~~~~
    if ((size<max_size)); then
        cat --show-nonprinting "$fn"
    else
        buf="$fn is > $max_size bytes.  Here are some excerpts."
        buf+=$'\n\n'
        buf+=$(sed -En \
                -e '/is unreachable, does not exist or is not a directory$/p' \
                -e '/^IO error encountered/p' \
                -e '/^No return code found /p' \
                -e '/^cannot delete non-empty directory:/p' \
                -e '/^rsync error:/p' \
                -e '/^rsync: /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} .* started on /{N;p}' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ Exiting with /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ LVM snapshot volume /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ Removed snapshot volume /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ Return code [^ ]+ from subsidiary script/p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ Running /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ There was at least one /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ rsync return code /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ (ERROR|WARN): /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ (Mounted|Unmounted) /p' \
                "$fn"
        )
        echo "$buf"
    fi

    return
}  # end of function my_cat

#--------------------------
# Name: notify
# Purpose: sends a notification
# Usage: notify
# Globals
#   Read
#     body
#     subject
#   Set
# Returns: 
#   0 when the notification is sent
#   1 otherwise
#--------------------------
function notify {

    # Send email
    # ~~~~~~~~~~
    if [[ $opt_l_flag ]]; then
        body+=$'\n\n'$(my_cat "$log_fn")
    fi
    msg I "Sending '$subject' mail to $email_address_list"
    buf=$(echo "$body" \
        | iconv --from-code utf-8 --to-code ascii//translit \
        | fold -w 999 \
        | MAILRC=/dev/null mailx -n -s "$subject" "$email_address_list")
    if [[ $buf != '' ]]; then
        msg E "Sending mail: $buf"
        return 1
    fi

    return 0
}  #  end of function notify

#--------------------------
# Name: main
# Purpose: where it all happens
#--------------------------
initialise "${@:-}"
notify
finalise 0
