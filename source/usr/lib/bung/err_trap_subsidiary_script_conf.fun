# Copyright (C) 2014 Charles Atkinson
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
# Name: err_trap_subsidiary_script_conf
# Purpose: 
#   Error traps the "Subsidiary script" configuration
# Arguments: none
# Global variable usage: adds any error message to emsg, prefixed by $msg_lf
# Output: none
# Return value: 1 when an error is detected, 0 otherwise
#--------------------------
function err_trap_subsidiary_script_conf {
    fct "${FUNCNAME[0]}" 'started'
    local i ionice my_rc=0 nice old_emsg
    local -r nice_regex='-?[[:digit:]]{1,2}'
    local -r ionice_regex='^(([[:space:]]+-c[[:space:]]*[0-3])|([[:space:]]+-n[[:space:]]*[0-7])){1,2}$'

    # Initialise
    # ~~~~~~~~~~
    old_emsg=$emsg
    emsg=
    my_rc=0
 
    # Nothing to do?
    # ~~~~~~~~~~~~~~
    if ((subsidiaryscript_idx<0)); then
        emsg+=$msg_lf'No subsidiary scripts configured (no "Subsidiary script" keyword)'
        fct "${FUNCNAME[0]}" "returning, rc 1"
        return 1
    fi

    # Error trap each subsidiary script
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    for ((i=0;i<=subsidiaryscript_idx;i++))
    do
        buf=$(ck_file "$BUNG_BIN_DIR/${subsidiaryscript_name[i]}" f:rx 2>&1)
        [[ $buf != '' ]] && emsg+=$msg_lf"Invalid subsidiary script name '$buf'"

        nice=${subsidiaryscript_nice[i]}
        if [[ $nice != '' && ! $nice =~ $nice_regex ]]; then 
            pc_emsg+=$msg_lf"Invalid nice value '$nice'"
        fi   

        ionice=${subsidiaryscript_ionice[i]}
        if [[ $ionice != '' && ! $ionice =~ $ionice_regex ]]; then 
            pc_emsg+=$msg_lf"Invalid ionice value '$nice'"
        fi   
    done

    [[ $emsg != '' ]] && my_rc=1
    emsg=$old_emsg$emsg
    fct "${FUNCNAME[0]}" "returning, rc $my_rc"
    return $my_rc
}  # end of function err_trap_subsidiary_script_conf
# vim: filetype=bash:
