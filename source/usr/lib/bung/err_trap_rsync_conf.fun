# Copyright (C) 2019 Charles Atkinson
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
# Name: err_trap_rsync_conf
# Purpose:
#   Error traps the rsync_bu-specific configuration
# Arguments: none
# Global variable usage: adds any error message to emsg, prefixed by $msg_lf
# Output: none
# Return value: 1 when an error is detected, 0 otherwise
#--------------------------
function err_trap_rsync_conf {
    fct "${FUNCNAME[0]}" 'started'
    local buf i msg_part my_rc=0 old_emsg
    local -r remote_host_timeout_regex='^\+?[[:digit:]]*\.?[[:digit:]]+(|d|h|m|s)$'

    # Nothing to do?
    # ~~~~~~~~~~~~~~
    if [[ ${src_dir:-} = '' ]]; then
        emsg+=$msg_lf"No backup configured (no rsync keyword)"
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi

    # Initialise
    # ~~~~~~~~~~
    old_emsg=$emsg
    emsg=
    my_rc=0

    # Error traps
    # ~~~~~~~~~~~
    buf=$dest_dir_usage_warning
    err_trap_uint "$buf" "Invalid dest_dir_usage_warning" \
        && ((buf>100)) && emsg+=$msg_lf"Invalid dest_dir_usage_warning % $buf (maximum 100)"

    if [[ $src_dir_remote_flag \
        && $dest_dir_remote_flag ]]; then
        emsg+=$msg_lf"Invalid: '$src_dir' and '$dest_dir"
        emsg+='(rsync does not support source and destination both remote)'
    fi

    if [[ $rsync_options = '' ]]; then
        buf=$backup_retention
        if [[ $buf != '' ]]; then
            err_trap_uint "$buf" "Invalid retention value"
        fi

        buf=$remote_host_timeout
        if [[ ! $buf =~ $remote_host_timeout_regex ]]; then
            msg_part=$msg_lf"Invalid remote_host_timeout value '$buf' (does"
            emsg+=$msg_part" not match $remote_host_timeout_regex)"
        fi

        buf=$rsync_timeout
        if [[ $buf != '' ]]; then
            err_trap_uint "$buf" "Invalid timeout value"
        fi

        buf=$rsync_verbose_level
        err_trap_uint "$buf" "Invalid verbose level value"
        if (($?==0)); then
            (($buf>3)) && emsg+=$msg_lf"Invalid verbose level '$buf' (must be 3 or less)"
        fi
    else
        [[ ${rsync_backup_dir:-} != '' ]] \
            && emsg+=$msg_lf'--backup-dir cannot be specified when options= is configured'
        [[ ${backup_retention:-} != '' ]] \
            && emsg+=$msg_lf'Retention cannot be specified when options= is configured'
        [[ ${rsync_rsh:-} != '' ]] \
            && emsg+=$msg_lf'rsh cannot be specified when options= is configured'
        [[ ${rsync_timeout:-} != '' ]] \
            && emsg+=$msg_lf'Timeout cannot be specified when options= is configured'
        [[ ${rsync_verbose_level:-} != '' ]] \
            && emsg+=$msg_lf'Verbose cannot be specified when options= is configured'
    fi

    [[ $emsg != '' ]] && my_rc=1
    emsg=$old_emsg$emsg
    fct "${FUNCNAME[0]}" "returning, rc $my_rc"
    return $my_rc
}  # end of function err_trap_rsync_conf
# vim: filetype=bash:
