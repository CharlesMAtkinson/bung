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

#--------------------------
# Name: msg
# Purpose: generalised messaging interface
# Arguments:
#    $1 class: D, E, I or W indicating Debug, Error, Information or Warning
#    $2 message text
#    $3 logger control. Optional
#       If "logger" then also send class I messages with logger (to syslog)
#       If "no_logger" then do not also send class  W and E messages with
#       logger (to syslog).
#    $4 timestamp control. Optional
#       If "no_timestamp" then do not prefix message with a timestamp
# Global variables read:
#     conf_name
#     script_name
# Output: information messages to stdout; the rest to stderr
# Returns: 
#   Does not return (calls finalise) when class is E for error
#   Otherwise returns 0
#--------------------------
function msg {
    local buf class i logger_flag logger_msg message_text prefix timestamp_flag
    local -r regex='^(|(logger)|(no_logger))$'
    local -r max_logger_chars=100000

    # Process arguments
    # ~~~~~~~~~~~~~~~~~
    class="${1:-}"
    message_text="${2:-}"
    [[ ! ${3:-} =~ $regex ]] && msg E "Programming error: invalid ${FUNCNAME[0]} third argument '${3:-}' (does not match regex $regex)"
    [[ ${4:-} != no_timestamp ]] && timestamp_flag=$true || timestamp_flag=$false

    # Class-dependent set-up
    # ~~~~~~~~~~~~~~~~~~~~~~
    logger_flag=$false
    case "$class" in  
        D ) 
            [[ ! $debugging_flag ]] && return
            prefix='DEBUG: '
            [[ ${3:-} = logger ]] && logger_flag=$true
            ;;  
        E ) 
            error_flag=$true
            prefix='ERROR: '
            [[ ${3:-} != no_logger ]] && logger_flag=$true
            ;;  
        I ) 
            prefix=
            [[ ${3:-} = logger ]] && logger_flag=$true
            ;;  
        W ) 
            warning_flag=$true
            prefix='WARN: '
            [[ ${3:-} != no_logger ]] && logger_flag=$true
            ;;  
        * ) 
            msg E "msg: invalid class '$class': '$*'"
    esac

    # Write to syslog
    # ~~~~~~~~~~~~~~~
    if [[ $logger_flag ]]; then
        preamble=$script_name+$conf_name[$$]
        logger_msg=("$prefix$message_text")
        if ((${#logger_msg}>max_logger_chars)); then
            unset logger_msg
            logger_msg+=("${prefix}Message too big (>$max_logger_chars characters)")
            logger_msg+=('The message is split into pieces:')
            buf=$message_text
            while ((${#buf}>0))
            do
                logger_msg+=("${buf:0:$max_logger_chars}")
                buf=${buf:$max_logger_chars}
            done
        fi  
        for ((i=0;i<${#logger_msg[*]};i++))
        do  
            buf=$(logger -t "$preamble" -- "${logger_msg[i]}" 2>&1)
            [[ $buf != '' ]] && msg W "${FUNCNAME[0]}: problem writing to syslog: $buf"
        done
    fi

    # Write to stdout or stderr
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    # Which is to log if such redirection is set up, as is usual
    [[ $subsidiary_mode_flag ]] && prefix="$script_name: $prefix"
    [[ $timestamp_flag ]] && prefix="$(date "$log_date_format") $prefix"
    message_text="$prefix$message_text"
    if [[ $class = I ]]; then
        echo "$message_text"
    else
        echo "$message_text" >&2
        if [[ $class = E ]]; then
            [[ ! $finalising_flag ]] && finalise 1 
        fi
    fi  

    return 0
}  #  end of function msg
# vim: filetype=bash:
