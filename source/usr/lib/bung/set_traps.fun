# Copyright (C) 2021 Charles Atkinson
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
# Name: set_traps
# Purpose: sets signal traps
# Arguments:
#    $1 must be "finalise" or "signal_num_received"
# Global variable usage:
#    sig_names: read
# Output: logging only
# Return code: always 0; does not return on error
#--------------------------
function set_traps {
    fct "${FUNCNAME[0]}" 'started'
    local buf cmd i log_line job_name msg_class msg_part exit_code exit_code_bitfield
    local time_now time_regex

    if [[ $1 = finalise ]]; then
        msg D 'Setting traps to call finalise'
        for ((i=1;i<${#sig_names[*]};i++))
        do  
            ((i==9)) && continue     # SIGKILL
            ((i==17)) && continue    # SIGCHLD
            trap "finalise $((128+i))" ${sig_names[i]#SIG}
        done
    elif [[ $1 = signal_num_received ]]; then
        msg D 'Setting traps to set signal_num_received'
        for ((i=1;i<${#sig_names[*]};i++))
        do  
            ((i==9)) && continue     # SIGKILL
            ((i==17)) && continue    # SIGCHLD
            trap "signal_num_received=$i" ${sig_names[i]#SIG}
        done
    else
        msg E "Programming error: ${FUNCNAME[0]} called with invalid argument '$1'"
    fi

    fct "${FUNCNAME[0]}" 'returning'
    return
}  # end of function set_traps
# vim: filetype=bash:
