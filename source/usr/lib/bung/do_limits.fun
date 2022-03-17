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
# Name: do_limits
# Purpose: log limits (memory, open files) or set if configured
# Arguments: none
# Global variable usage:
#   Read:
#       $true
#   Set: none
# Output: none except via msg function
# Other effects: syncs the local file systems
# Return code: always 0; does not return on error
#--------------------------
function do_limits {
    fct "${FUNCNAME[0]}" started
    local buf cmd msg rc

    # Max memory size
    # ~~~~~~~~~~~~~~~
    if [[ ${max_memory_size:-} = '' ]]; then
        msg I "Max memory size limits: soft: $(ulimit -m -S), hard: $(ulimit -m -H)"
    else
        msg D "Max memory size limits: soft: $(ulimit -m -S), hard: $(ulimit -m -H)"
        msg I "Setting max memory sizes to $max_memory_size"
        cmd=(ulimit -m $max_memory_size)
        "${cmd[@]}" 2>&1
        rc=$?
        if ((rc==0)); then
            msg D "Max memory size limits: soft: $(ulimit -m -S), hard: $(ulimit -m -H)"
        else
            msg="Unexpected output from ${cmd[*]}"
            msg+=$'\n'"Return code: $rc"
            msg+=$'\n'"Output: should be logged above"
            msg W "$msg"
        fi
    fi

    # Number of open files
    # ~~~~~~~~~~~~~~~~~~~~
    if [[ ${n_open_files:-} = '' ]]; then
        msg I "Number of open files limits: soft: $(ulimit -n -S), hard: $(ulimit -n -H)"
    else
        msg D "Number of open files limits: soft: $(ulimit -n -S), hard: $(ulimit -n -H)"
        msg I "Setting number of open files to $n_open_files"
        cmd=(ulimit -n $n_open_files)
        "${cmd[@]}" 2>&1
        rc=$?
        if ((rc==0)); then
            msg D "Number of open files limits: soft: $(ulimit -n -S), hard: $(ulimit -n -H)"
        else
            msg="Unexpected output from ${cmd[*]}"
            msg+=$'\n'"Return code: $rc"
            msg+=$'\n'"Output: should be logged above"
            msg W "$msg"
        fi
    fi

    fct "${FUNCNAME[0]}" returning
    return
}  # end of function do_limits
# vim: filetype=bash:
