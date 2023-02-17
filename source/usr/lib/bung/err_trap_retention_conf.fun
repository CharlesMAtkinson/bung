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
# Name: err_trap_retention_conf
# Purpose:
#   Error traps sub-keyword retention's value
# Arguments: 
#   retention: sub-keyword retention's value
# Global variable usage: adds any error message to emsg, prefixed by $msg_lf
# Output: none
# Return value: 1 when an error is detected, 0 otherwise
#--------------------------
function err_trap_retention_conf {
    fct "${FUNCNAME[0]}" 'started'
    local min_old_backups mob_num msg my_rc=0 num old_emsg=$emsg retention=${1:-}
    local -r retention_days_re='[[:digit:]](days)?$'
    local -r retention_old_backups_re='[[:digit:]]old_backups$'
    local -r retention_percent_usage_re='percent_usage(,[[:digit:]]+min_old_backups)?$'

    num=
    if [[ $retention =~ $retention_days_re ]]; then
        num=${retention%days}
    elif [[ $retention =~ $retention_old_backups_re ]]; then
        num=${retention%old_backups}
    elif [[ $retention =~ $retention_percent_usage_re ]]; then
        min_old_backups=${retention#*,}
        if [[ $retention != $min_old_backups ]]; then
            mob_num=${min_old_backups%min_old_backups}
            err_trap_uint "$mob_num" "Invalid min_old_backups number in $retention"
            num=${retention%percent_usage,*}
        else
            num=${retention%percent_usage}
        fi
    else
        emsg+=$msg_lf"Invalid retention $retention" 
    fi
        
    if [[ $num != '' ]]; then
        err_trap_uint "$num" "Invalid retention number in $retention"
    fi

    [[ $emsg != '' ]] && my_rc=1
    emsg=$old_emsg$emsg
    fct "${FUNCNAME[0]}" "returning, rc $my_rc"
    return $my_rc
}  # end of function err_trap_retention_conf
# vim: filetype=bash:
