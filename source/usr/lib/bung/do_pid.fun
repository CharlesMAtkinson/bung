# Copyright (C) 2013 Charles Atkinson
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
# Name: do_pid
# Purpose:
#   * If can take an exclusive lock on a PID file
#         Writes a record to it identifying the current process
#     Else
#         Exits via writing an error message via msg
# Arguments:
#    $1 - the script's argument list
# Outputs: none except via msg()
# Global variables
#    Read:
#        conf_name: read
#        pid_dir: read
#        script_name: read
#    Set:
#        pid_file_locked_flag: set
#        pid_fn: set
# Returns: 
#   0 on success
#   Does not return otherwise
# Usage notes:
#   * Caller should ensure the PID directory exists and has rwx permissions
#--------------------------
function do_pid {
    fct "${FUNCNAME[0]}" 'started'
    local pid_contents
    
    pid_fn=$pid_dir/$script_name+$conf_name.pid

    [[ -r $pid_fn ]] && pid_contents=$(< "$pid_fn")
    exec 9>>"$pid_fn"
    if flock --exclusive --timeout 1 9; then
        pid_file_locked_flag=$true
        msg D "Taken lock on PID file $pid_fn"
        echo "$(date '+%b %e %X') $script_name [$$]: arguments: $1" >> "$pid_fn"
        msg I "Created PID file $pid_fn containing:$msg_lf$(< "$pid_fn")"
    else
        msg E "Another instance is running.  Contents of $pid_fn: $pid_contents"
    fi  
        
    fct "${FUNCNAME[0]}" 'returning'
}  #  end of function do_pid
# vim: filetype=bash:
