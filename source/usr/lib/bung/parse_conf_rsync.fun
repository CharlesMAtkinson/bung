# Copyright (C) 2022 Charles Atkinson
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
# Name: parse_conf_rsync
# Purpose:
#   Parses an rsync line from the configuration file
#   Note: does not error trap sub-values, only traps syntactical errors
# Arguments:
#   $1 - the keyword as read from the configuration file (not normalised)
#   $2 - the value from the configuration file
# Global variable usage:
#   Read:
#       line_n
#       true and false
#   Set:
#       dest_dir
#       dest_dir_usage_warning
#       dest_dir_windows_flag
#       pc_emsg appended with any error message
#       remote_host_log_dir
#       remote_host_pid_dir
#       remote_host_timeout
#       retry_max
#       rsync_bwlimit
#       rsync_exclude_fn
#       rsync_options
#       rsync_rsh
#       src_dir
# Output: none except via function fct
# Return value:
#   0 when no error detected
#   1 when an error is detected
#--------------------------
function parse_conf_rsync {
    fct "${FUNCNAME[0]}" "started with keyword: ${1:-}, value: ${2:-}, line_n: ${3:-}"
    local buf msg my_rc unparsed_str

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    if (($#!=3)); then
        msg="Programmming error: ${FUNCNAME[0]} called with $# arguments instead of 3"
        msg E "$msg (args: $*)"
    fi
    local -r keyword=$1
    local -r value=$2
    local -r line_n=$3

    # Initialise
    # ~~~~~~~~~~
    local -r initial_pc_emsg=$pc_emsg
    unparsed_str=$value

    # Parse any subkeywords
    # ~~~~~~~~~~~~~~~~~~~~~
    # Syntax:
    #   rsync = source_dir dest_dir [backup_dir=dir] [--bwlimit=limit]
    #           [dest_dir_usage_warning=%] [dest_dir_windows]
    #           [--exclude-from=FILE] [nocompression] [no-numeric-ids]
    #           [remote_host_timeout=minutes,minutes] [retention=days[,nowarn]]
    #           [retry=count] [--timeout=seconds] [verbose=level]
    #   rsync = source_dir dest_dir options=options [dest_dir_usage_warning=%]

    parse_conf_word $line_n
    if (($?!=0)); then
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    src_dir=$parsed_word

    parse_conf_word $line_n
    if (($?!=0)); then
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    dest_dir=$parsed_word

    if [[ $dest_dir != '' ]]; then

        # Set sub-keyword default values
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        # Sub-keywords which have non-empty default values and which cannot be
        # used with "options" are defaulted in postprocess_rsync_conf to
        # facilitate trapping mutually exclusive config items
        dest_dir_usage_warning=80
        dest_dir_windows_flag=$false
        retry_max=2
        rsync_bwlimit=
        rsync_exclude_fn=
        rsync_options=
        remote_host_log_dir=
        remote_host_pid_dir=
        remote_host_timeout=10m
        rsync_rsh=

        # Get any sub-keyword values
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~
        local -A subkey_validation
        subkey_validation[name]='
            backup_dir
            --bwlimit
            dest_dir_usage_warning
            dest_dir_windows
            --exclude-from
            nocompression
            no-numeric-ids
            options
            remote_host_log_dir
            remote_host_pid_dir
            remote_host_timeout
            retention
            retry
            --timeout
            verbose
        '
        subkey_validation[value_required]='
            backup_dir
            --bwlimit
            dest_dir_usage_warning
            --exclude-from
            options
            remote_host_log_dir
            remote_host_pid_dir
            remote_host_timeout
            retention
            retry
            --timeout
            verbose
        '
        subkey_validation[value_invalid]='
            dest_dir_windows
            nocompression
            no-numeric-ids
        '
        local +r subkey_validation
        while [[ $unparsed_str != '' ]]
        do
           parse_conf_subkey_value "${FUNCNAME[0]}" $line_n
        done
        unset unparsed_str
    else
        [[ $src_dir = '' ]] && msg=SRC || msg=DEST
        pc_emsg+=$msg_lf"$msg missing (line $line_n)"
    fi

    [[ $pc_emsg = $initial_pc_emsg ]] && my_rc=0 || my_rc=1
    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function parse_conf_rsync
# vim: filetype=bash:
